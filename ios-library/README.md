# NXNative Library — iPad-first milestone 1

This is a **separate, experimental iPad app** inside an nxnative fork. It does not modify the existing game-specific `dm/ios` host or any per-game build scripts.

## What works in milestone 1

- Native SwiftUI iPad landscape interface with a local game library.
- Import `.nsp`, `.xci`, `.nsz`, and `.xcz` using the iPad Files picker.
- Security-scoped file access, background copying to the app's Documents/ROMs directory, file size display, and removal of imported copies.
- Files app access to the app's Documents area.
- Unsigned IPA produced through a macOS GitHub Actions runner, without owning a Mac.

## What does **not** work yet

- **No play button or ROM execution.** A ROM importer is not an nxnative runtime.
- No NSP/XCI decryption, game metadata reading, shaders or runtime loading.
- No A16 texture compatibility implementation. Upstream nxnative currently specifies M1+ iPads.

The current nxnative build pipeline rewrites and links each game's code, builds Metal shader libraries, and packages a separate iOS app for each game. Loading arbitrary games at runtime in one signed iOS app requires significant engine and code-signing work and may not be feasible as envisioned under iPadOS platform restrictions.

## Build

In GitHub, run the workflow **iPad Library — unsigned IPA (M1)** on `feat/ipad-rom-library-m1`. Its artifact is `NXNative-Library-unsigned-IPA`.

An unsigned IPA needs a compatible signing/sideloading tool before it can be installed on an iPad. Never upload personal Switch keys or game files to a public repository.

Local equivalent on a Mac with Xcode and XcodeGen:

```bash
cd ios-library
xcodegen generate
xcodebuild -project NXNativeLibrary.xcodeproj -scheme NXNativeLibrary -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```
