import SwiftUI
import UniformTypeIdentifiers

@main
struct NXNativeLibraryApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
    }
}

private struct LibraryView: View {
    @StateObject private var store = ROMStore()
    @State private var selected: ROMFile?
    @State private var showingImporter = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section("My games") {
                    ForEach(store.games) { game in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.displayName)
                                    .lineLimit(2)
                                Text(game.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundStyle(.secondary)
                        }
                        .tag(game)
                    }
                }
            }
            .navigationTitle("NXNative")
            .navigationSplitViewColumnWidth(min: 270, ideal: 330, max: 420)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import ROMs", systemImage: "plus")
                    }
                    .disabled(store.isImporting)
                }
            }
            .overlay {
                if store.games.isEmpty {
                    ContentUnavailableView {
                        Label("No ROMs yet", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Import your own .nsp, .xci, .nsz or .xcz files.")
                    } actions: {
                        Button("Import ROMs") {
                            showingImporter = true
                        }
                    }
                }
            }
        } detail: {
            if let selected {
                gameDetail(selected)
            } else {
                ContentUnavailableView(
                    "Choose a game",
                    systemImage: "gamecontroller",
                    description: Text("Your imported games appear in the sidebar.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                store.importURLs(urls)
            case .failure(let error):
                store.report("Import cancelled or unavailable: \(error.localizedDescription)")
            }
        }
        .alert("NXNative Library", isPresented: $store.showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.notice)
        }
        .confirmationDialog(
            "Remove this ROM from the library?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete imported file", role: .destructive) {
                if let selected {
                    store.remove(selected)
                    self.selected = nil
                }
            }
        } message: {
            Text("This deletes the copy stored inside NXNative Library. Your original imported file is not changed.")
        }
        .overlay(alignment: .bottom) {
            if store.isImporting {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Copying ROMs into the library…")
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
    }

    private func gameDetail(_ game: ROMFile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.secondary)

                Text(game.displayName)
                    .font(.largeTitle.bold())
                    .textSelection(.enabled)

                Text(game.filename)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(game.details, systemImage: "doc")
                    Label("Stored locally", systemImage: "internaldrive")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                Label("Runtime integration pending", systemImage: "wrench.and.screwdriver")
                    .font(.headline)

                Text("This first milestone imports and organizes ROMs. nxnative currently needs per-game code rewriting, shader compilation and signing before a game can run. Importing a file here does not make it playable.")
                    .foregroundStyle(.secondary)

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Remove imported ROM", systemImage: "trash")
                }
                .foregroundStyle(.red)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(game.displayName)
    }
}
