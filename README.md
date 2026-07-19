# LMS Model Status

A minimal KDE Plasma 6 panel widget that shows whether [LM Studio](https://lmstudio.ai/) currently has a model loaded, at a glance.

![LMS Model Status icon](./screenshot.png)

The icon is a small robot glyph:

- **Filled head** → a model is currently loaded
- **Outline head** → no model loaded
- Click the icon to expand a popup with the full `lms status` output and a manual "Check Now" button

## How it works

The widget polls `lms status` (the LM Studio CLI) every 5 seconds via Plasma's `Plasma5Support.DataSource` executable engine, parses the output for a loaded-model indicator, and updates the icon accordingly.

## Requirements

- KDE Plasma 6
- [LM Studio](https://lmstudio.ai/) with the `lms` CLI installed
- The `plasma5support` package (usually already installed as a Plasma dependency)

## Installation

```bash
kpackagetool6 -t Plasma/Applet -i /path/to/lms_monitor
```

To update after making changes:

```bash
kpackagetool6 -t Plasma/Applet -u /path/to/lms_monitor
kquitapp6 plasmashell
kstart plasmashell
```

Then add it to your panel via **Add Widgets → LMS Model Status**.

## Configuration

The path to the `lms` executable is currently hardcoded in `contents/ui/main.qml`:

```qml
readonly property string lmsExecutable: "~/.lmstudio/bin/lms"
```

Update this to match your own install path if it differs.
