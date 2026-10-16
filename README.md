# Raster

A keyboard- and drag-driven window manager for macOS. Raster lives in the menu bar and snaps windows into
halves, quarters, thirds and two-thirds of the screen, moves them between displays, and lets you define your
own layouts on a 24 × 12 grid (12 × 24 on portrait displays).

## Features

- **Keyboard shortcuts** for every command (defaults below), registered system-wide.
- **Drag to snap**: drag a window to an edge or corner and release to snap it, with a live preview.
  While dragging is enabled, Raster turns off macOS's own edge tiling and restores it when you quit.
- **Custom commands**: pick any target area on the grid, give it a name, a shortcut and one or more
  activation areas for dragging.
- **Separate Horizontal and Vertical lists**: landscape displays use one list, portrait displays the other.
- **Green button menu**: hover the green button of a window to get Raster's commands; hold ⌃ (or ⌘,
  configurable) for the standard macOS menu.
- **Spacing**: optional gaps around and between snapped windows.
- **Ignore apps** straight from the menu bar menu, **Stay On Top** (experimental) and **launch at login**.

### Default shortcuts

| Command | Shortcut |
|---|---|
| Left / Right / Top / Bottom half | ⌃⌥ ← / → / ↑ / ↓ |
| Top left / Top right / Bottom left / Bottom right | ⌃⌥ U / I / J / K |
| Left / Center / Right third | ⌃⌥ D / F / G |
| Left / Center / Right two thirds | ⌃⌥ E / R / T |
| Maximize | ⌃⌥ ↩ |
| Center | ⌃⌥ C |
| Restore | ⌃⌥ ⌫ |
| Next / Previous display | ⌃⌥⌘ → / ← |
| Stay On Top | ⌃⌥⌘ ↑ |

All shortcuts can be changed or removed under **Settings… › Commands**.

## Requirements

- macOS 27 or later
- Swift 6 toolchain (Xcode 27 or the matching command line tools) to build
- Accessibility permission (System Settings › Privacy & Security › Accessibility), which Raster asks for on
  first launch

## Build and install

```sh
scripts/install.sh        # builds, installs to ~/Applications/Raster.app and launches it
scripts/build-app.sh      # only builds build/Raster.app
swift test                # runs the test suite
```

By default the app is signed ad hoc. macOS ties the Accessibility permission to the signature, so with ad hoc
signing you have to grant it again after every build. To keep it, sign with your own certificate:

```sh
RASTER_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" scripts/install.sh
```

Install to `~/Applications` (or `/Applications`) rather than running from `build/`: macOS only associates a
menu bar item with its bundle identifier for apps in those folders, and menu bar managers may otherwise hide
the icon.

## Where settings are stored

- Preferences: the `nl.jimlindenburg.raster` defaults domain.
- Commands: `~/Library/Application Support/Raster/commands.json`. If the file cannot be read or was written
  by a newer version, Raster opens it read-only and shows a notice instead of overwriting it; damaged files
  are backed up next to the original before defaults are restored.

## Project layout

| Folder | Contents |
|---|---|
| `Sources/RasterCore` | Pure Swift, no AppKit: grid, commands, the Horizontal/Vertical lists, `commands.json` and migration, geometry |
| `Sources/RasterSystem` | Accessibility (AX), hotkeys, event taps for dragging and the green button, displays, Stay On Top |
| `Sources/RasterUI` | The app: menu bar menu, green button menus, settings window, strings, colors and icons |
| `Sources/Raster` | The entry point only |
| `Sources/RasterRender` | `raster-render`, a debug tool that renders the interface offscreen to PNG files |
| `Tests/` | `RasterCoreTests`, `RasterSystemTests`, `RasterUITests` |
| `scripts/` | Build, install and icon scripts |

The app is linked with SDK version 15.2 (`legacyAppearance` in `Package.swift`) so AppKit uses the compact
classic control style the layout is designed for.

## Notes

- Don't run another window manager that uses the same shortcuts or edge snapping at the same time; Raster
  warns at launch if it detects one it knows about.
- If Raster quits unexpectedly while dragging is enabled, macOS edge tiling stays off until Raster starts and
  quits again, or until you turn it back on in System Settings › Desktop & Dock.

## License

MIT — see [LICENSE](LICENSE).
