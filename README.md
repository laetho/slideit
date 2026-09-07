# Slideit

A keyboard-first local photo slideshow for Omarchy, built with Go, Qt 6, QML, and [MIQT](https://github.com/mappu/miqt).

## Features

- Single, grid, and deterministic montage layouts
- Aspect-aware montage composition that favors more columns on wide screens
- Filename, filesystem creation-time, modification-time, and shuffled ordering
- Configurable 1–12 photos per deck
- Asynchronous, display-sized image decoding
- Fullscreen playback with keyboard and mouse navigation
- Temporary control bubbles docked to the top and bottom edges
- Toggleable Polaroid-style white, aged yellow, or black frames with three thicknesses
- Selectable none, fade, slide, zoom, and tilt deck transitions
- Matched outgoing and incoming phases for every transition
- Next-deck image preloading during timed playback
- Active Omarchy colors and Fontconfig `monospace` font
- Persistent settings in `$XDG_CONFIG_HOME/slideit/settings.json`

Creation time is filesystem birth time where Linux and the filesystem expose it. Slideit falls back to modification time when unavailable; it is not camera EXIF capture time.

## Requirements

- Go 1.27+
- Qt 6.8+ development packages (`Core`, `Gui`, `Qml`, `Quick`, and `QuickControls2`)
- A C++ compiler and `pkg-config`
- [Task](https://taskfile.dev/) for the recommended workflow

On Omarchy/Arch, install missing development dependencies with the normal package workflow rather than editing packaged Omarchy files.

## Build and run

```bash
task build
task run
```

Open a folder directly:

```bash
task build
./build/slideit ~/Pictures
```

The command-line folder takes precedence over the last folder saved in the settings.

Run all checks:

```bash
task check
```

CI uses a native GitHub Actions matrix for Linux x86-64, Windows x86-64,
macOS Apple Silicon, and macOS Intel. The same non-mutating checks can be run
locally with:

```bash
task ci
```

CI artifacts contain the application executable only. They are build artifacts,
not yet self-contained Qt runtime bundles.

The macOS jobs install Homebrew Qt because MIQT requires Qt `.pc` files through
`pkg-config`; the official macOS Qt framework archives do not expose that build
interface.

The Linux job installs the complete Qt desktop package rather than filtering Qt
archives. Qt's prebuilt Linux libraries require the matching bundled ICU runtime,
which can otherwise be omitted by a minimal archive selection.

The QML file is embedded in the Go binary. CMake is not currently needed; if native adapters or Qt deployment targets are added later, Task remains the entry point and will delegate those steps to CMake.

## Controls

| Key | Action |
|---|---|
| `Space` | Play/pause |
| `Left` / `Right`, `H` / `L` | Previous/next deck |
| `M` | Cycle layout |
| `S` / `Shift+S` | Cycle/reverse ordering |
| `R` | Toggle shuffled/name ordering |
| `[` / `]` | Change photos per deck |
| `-` / `+` | Change interval |
| `C` | Fit/crop |
| `B` | Cycle frame off/white/black |
| `T` | Cycle transition |
| `F` or `F11` | Fullscreen |
| `O` | Open folder |
| `F5` | Rescan |
| `?` | Help |
| `Q` | Quit |

Move the pointer or press a key to reveal the edge controls. They fade after three seconds and remain visible while hovered or while a selector is open.

In grid or montage mode, click the **N photos** bubble to choose the number of pictures shown on each deck. The `[` and `]` shortcuts adjust the same setting one image at a time.

Use the **R** bubble in the bottom controls, or press `R`, to toggle random ordering. The bubble uses the active accent color while random mode is enabled.
