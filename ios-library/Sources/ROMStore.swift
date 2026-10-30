import Foundation
import SwiftUI

struct ROMFile: Hashable, Identifiable {
    let url: URL
    let byteCount: Int64

    var id: URL { url }

    var filename: String {
        url.lastPathComponent
    }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var details: String {
        let size = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
        return "\(url.pathExtension.uppercased()) · \(size)"
    }
}

@MainActor
final class ROMStore: ObservableObject {
    @Published private(set) var games: [ROMFile] = []
    @Published private(set) var isImporting = false
    @Published var showingAlert = false
    @Published private(set) var notice = ""

    private let supported: Set<String> = ["nsp", "xci", "nsz", "xcz"]

    private var romDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ROMs", isDirectory: true)
    }

    init() {
        refresh()
    }

    func report(_ message: String) {
        notice = message
        showingAlert = true
    }

    func refresh() {
        do {
            try FileManager.default.createDirectory(
                at: romDirectory,
                withIntermediateDirectories: true
            )
            let urls = try FileManager.default.contentsOfDirectory(
                at: romDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            games = urls.compactMap { url in
                guard supported.contains(url.pathExtension.lowercased()),
                      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                else { return nil }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return ROMFile(url: url, byteCount: Int64(size))
            }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        } catch {
            games = []
            report("Could not read the local ROM library: \(error.localizedDescription)")
        }
    }

    func importURLs(_ urls: [URL]) {
        guard !isImporting else { return }
        isImporting = true
        let directory = romDirectory
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                copyROMs(urls, into: directory)
            }.value
            refresh()
            isImporting = false
            report(result)
        }
    }

    func remove(_ game: ROMFile) {
        // Never delete outside the app's own ROMs directory.
        guard game.url.deletingLastPathComponent().standardizedFileURL ==
              romDirectory.standardizedFileURL else {
            report("Refusing to remove a file outside the library.")
            return
        }
        do {
            try FileManager.default.removeItem(at: game.url)
            refresh()
        } catch {
            report("Could not remove the imported file: \(error.localizedDescription)")
        }
    }
}

private func copyROMs(_ sources: [URL], into directory: URL) -> String {
    let fm = FileManager.default
    let valid: Set<String> = ["nsp", "xci", "nsz", "xcz"]
    var copied = 0
    var skipped = 0
    var failures: [String] = []

    do {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
        return "Could not create the ROM folder: \(error.localizedDescription)"
    }

    for source in sources {
        guard valid.contains(source.pathExtension.lowercased()) else {
            skipped += 1
            continue
        }

        let accessed = source.startAccessingSecurityScopedResource()
        defer {
            if accessed { source.stopAccessingSecurityScopedResource() }
        }

        let originalName = source.lastPathComponent
        let stem = source.deletingPathExtension().lastPathComponent
        let suffix = source.pathExtension
        var target = directory.appendingPathComponent(originalName)
        var index = 2

        while fm.fileExists(atPath: target.path) {
            target = directory.appendingPathComponent("\(stem) (\(index)).\(suffix)")
            index += 1
        }

        do {
            try fm.copyItem(at: source, to: target)
            copied += 1
        } catch {
            failures.append("\(originalName): \(error.localizedDescription)")
            // Some providers can leave partially copied files behind.
            if fm.fileExists(atPath: target.path) {
                try? fm.removeItem(at: target)
            }
        }
    }

    var summary = "Imported \(copied) ROM file(s)."
    if skipped > 0 { summary += " Skipped \(skipped) unsupported file(s)." }
    if !failures.isEmpty {
        summary += " Failed: " + failures.prefix(3).joined(separator: "; ")
    }
    return summary
}
