# Slideit

Slideit is a keyboard-first photo slideshow for local folders. It combines a
Go backend with a Qt 6/QML interface and follows the active Omarchy theme when
available.

> Dedicated to the memory of my father, Trygve.

## Features

- Single-image, grid, and non-overlapping montage layouts
- Aspect-aware montages with wider arrangements on wide screens
- Configurable deck size from 1 to 12 photos
- Filename, creation-time, modification-time, and shuffled ordering
- Automatic playback with next-deck preloading
- None, fade, slide, zoom, and tilt transitions
- Optional white, aged-yellow, or black Polaroid frames
- Thin, medium, and thick frame options
- Fit and crop display modes
- Full keyboard and mouse control
- Auto-hiding controls docked to the top and bottom edges
- Omarchy theme integration with a built-in fallback palette
- Persistent folder, layout, ordering, frame, transition, and timing settings

## Requirements

- Go 1.27 or newer
- Qt 6.8 or newer
- Qt Core, Gui, Qml, Quick, Quick Controls, Dialogs, Layouts, and Window modules
- A C++ compiler
- `pkg-config`
- [Task](https://taskfile.dev/) for the recommended local workflow

MIQT uses cgo, so a Go compiler alone is not enough. Qt development headers,
libraries, and a compatible C++ toolchain must be available through
`pkg-config`.

## Build and run

Build the application:

```bash
task build
```

Run it using the last selected folder:

```bash
task run
```

Open a folder directly:

```bash
./build/slideit ~/Pictures
```

Only the first positional argument is used. It must be a folder path and takes
precedence over the folder saved in settings. Additional arguments are ignored.
There are currently no command-line flags.

## Supported images

Slideit scans the selected folder itself; subdirectories are not scanned.
Recognized extensions are:

```text
AVIF  BMP  GIF  HEIC  HEIF  JPEG  JPG  PNG  TIFF  TIF  WebP
```

Actual decoding support depends on the Qt image plugins installed on the
system.

Creation-time ordering uses the filesystem creation or birth timestamp exposed
by Linux, macOS, or Windows. If it is unavailable, Slideit falls back to the
modification time. Filesystem creation time is not the camera's EXIF capture
date.

## Controls

### Keyboard

| Key | Action |
|---|---|
| `Space` | Play or pause |
| `Right`, `L`, `Page Down` | Next deck |
| `Left`, `H`, `Page Up` | Previous deck |
| `Home` / `End` | First or last deck |
| `M` | Cycle single, grid, and montage layouts |
| `S` | Cycle name, creation, modification, and random ordering |
| `Shift+S` | Reverse the current ordered mode |
| `R` | Toggle between random and filename ordering |
| `[` / `]` | Decrease or increase photos per deck |
| `-` / `+` | Decrease or increase the playback interval |
| `C` | Toggle fit and crop |
| `B` | Cycle frames off, white, aged, and black |
| `T` | Cycle transition mode |
| `F`, `F11` | Toggle fullscreen |
| `O` | Choose a folder |
| `F5` | Rescan the current folder |
| `?` | Show shortcut help |
| `A` | Show About and dedication |
| `Escape` | Close a menu, exit fullscreen, or quit |
| `Q` | Quit |

Photo count ranges from 1 to 12. The selector offers common presets, while
`[` and `]` adjust the value one photo at a time.

Playback intervals range from 2 to 60 seconds. The selector offers 3, 5, 8,
12, and 20-second presets; `-` and `+` adjust the interval one second at a time.

### Mouse

- Move the pointer to reveal controls.
- Click the left quarter of the window for the previous deck.
- Click the right quarter for the next deck.
- Click the center to play or pause.
- Scroll to move between decks.
- Right-click to close an open selector.

Controls disappear after three seconds of inactivity. They remain visible while
hovered or while a selector is open. Image content stays between the top and
bottom control lanes and is not rendered beneath the bubbles.

## Defaults and settings

Default values:

| Setting | Default |
|---|---|
| Layout | Single |
| Ordering | Filename, ascending |
| Photos per grid/montage deck | 5 |
| Playback interval | 8 seconds |
| Display mode | Fit |
| Frame | White, medium |
| Transition | Fade |

Slideit stores settings under the platform's standard user configuration
directory:

```text
<user-config-directory>/slideit/settings.json
```

On Linux this normally resolves to:

```text
$XDG_CONFIG_HOME/slideit/settings.json
```

Play/pause state is not persisted.

## Omarchy integration

On Omarchy, Slideit reads the active palette from:

```text
~/.local/state/omarchy/current/theme/colors.toml
~/.local/state/omarchy/current/theme/shell.toml
~/.config/omarchy/shell.toml
```

Theme changes are detected while the application is running. Slideit uses a
built-in palette when these files are unavailable, allowing it to run on other
Linux desktops, macOS, and Windows. The generic `monospace` family is resolved
by the host platform.

## Development

| Command | Purpose |
|---|---|
| `task deps` | Download Go modules |
| `task fmt` | Format Go sources |
| `task fmt:check` | Check formatting without changing files |
| `task lint` | Run `go vet` |
| `task test` | Run unit tests |
| `task build` | Build `build/slideit` |
| `task run` | Build and run Slideit |
| `task check` | Format, vet, test, and build |
| `task ci` | Run non-mutating CI checks and build |
| `task clean` | Remove build output |

`task check` modifies unformatted Go files. Use `task ci` when a non-mutating
validation command is required.

The QML source is embedded in the Go executable. CMake is not currently needed.
If native adapters or Qt deployment targets are introduced later, Task remains
the public entry point and may delegate those steps to CMake.

## Continuous integration

GitHub Actions builds a native matrix for:

- Linux x86-64
- Windows x86-64 with MSYS2 UCRT64/MinGW
- macOS Apple Silicon
- macOS Intel

CI runs on pushes to `main`, pull requests, version tags, and manual dispatch.
Build artifacts are retained for 14 days.

Release packaging differs by platform:

- Linux remains a binary-only tarball and requires compatible Qt libraries and
  QML modules on the target system.
- Windows is a self-contained portable directory ZIP produced by `windeployqt`.
- macOS is a self-contained, ad-hoc-signed `Slideit.app` ZIP produced by
  `macdeployqt`. It is not notarized, so Gatekeeper may require users to confirm
  that they want to open it.

### Platform notes

- Linux uses the complete Qt 6.8.3 desktop package so Qt's matching ICU runtime
  is available.
- macOS uses Homebrew Qt and `pkg-config`. MIQT-generated C++ is compiled in
  C++17 mode. The macOS CI jobs pin Xcode 16.1 (Apple clang 16.0.0) because the
  runner's default Xcode 16.4 (clang 17.0.0) crashes the compiler frontend while
  building MIQT's generated `gen_qiconengine.cpp`; do not remove that pin without
  confirming the newer toolchain no longer crashes.
- Windows builds inside MSYS2 UCRT64 and runs Go commands directly in that
  environment.
- Go module and cgo build caches are isolated by platform and toolchain. Increase
  `CGO_CACHE_EPOCH` in the workflow after changing the Qt ABI or compiler family.

## Releases

Push a version tag to run the complete matrix and publish a GitHub release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Stable tags are marked as the latest release. Tags containing a hyphen are
published as prereleases:

```text
v0.2.0-beta.1
```

Expected release assets:

```text
slideit-linux-x86_64.tar.gz
slideit-windows-x86_64.zip
slideit-macos-arm64.zip
slideit-macos-x86_64.zip
```
