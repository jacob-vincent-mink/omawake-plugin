# Omawake

A compact Omarchy bar widget for the [Omawake](https://github.com/jacob-vincent-mink/omawake)
wake-word daemon: see whether detection is live, pause and resume it from the
bar, and browse the wake words you have trained.

The icon reports the daemon state from `omawake status --json` together with
the load state of the `omawake` user service, and both are re-checked on a
background timer. Stopping the service or removing `omawake-bin` therefore
changes the bar icon on its own, without the panel being opened. Detection that
is paused reads distinctly from detection that is stopped, and the wake-word
list marks the word the daemon reports as active.

## Requirements

- Omarchy Quattro with shell plugin support
- The `omawake-bin` package on `PATH`, because the widget drives the `omawake` command line
- A systemd user session, because the daemon runs as the `omawake` user service

## Install

```bash
sudo pacman -S omawake-bin   # the app the widget drives
omawake setup                # choose a runtime and model, once
omarchy plugin add https://github.com/jacob-vincent-mink/omawake-plugin.git --enable
omarchy bar move jacob.omawake --section right --index 0
```

Click the icon to open the panel. Press **Set up the service** once, so the
**Start**, **Stop**, **Pause**, and **Resume** buttons have a service to
control: it opens a terminal running `omawake setup systemd`, which installs and
enables the user service. **Train a wake word** opens a terminal running
`omawake word onboard`. When the binary is missing the panel reports
**Not installed** and prints the install command instead of failing.

## Remove

```bash
omarchy plugin disable jacob.omawake
omarchy plugin remove jacob.omawake
```

Removing the widget changes nothing else. It keeps no files of its own and
writes no configuration: the wake words it lists and removes are Omawake's own,
and a removal of the widget deletes none of them.

To drop the app as well, run `sudo pacman -R omawake-bin`. Its package removal
hook stops and cleans up the `omawake` user service, and it always keeps your
Omawake configuration and the models and trained words under
`~/.local/share/omawake`, which you can delete yourself when you want the space
back.

## What the widget runs

Every command runs as your own user and none of them needs root. The panel only
prints the package install command; it never runs it.

| Command | Used for |
| --- | --- |
| `sh -c "command -v omawake"` | installed or not |
| `omawake status --json` | daemon, model, and backend state, live or paused |
| `omawake wake-word list --json` | the trained wake words |
| `omawake wake-word remove <id>` | removing one listed wake word |
| `omawake pause`, `omawake resume` | the **Pause** and **Resume** buttons |
| `systemctl --user show omawake --property=LoadState --value` | whether the service is present |
| `systemctl --user start omawake`, `systemctl --user stop omawake` | the **Start** and **Stop** buttons |
| `omarchy launch terminal omawake setup` | the first-time setup button |
| `omarchy launch terminal omawake setup systemd` | the service setup button |
| `omarchy launch terminal omawake word onboard` | the wake-word training button |

Removing a wake word is permanent, so the widget asks for the click on that row
alone and offers no bulk action.

## External dependencies

Quickshell and QML from the Omarchy shell, the `omawake` command line from
`omawake-bin`, and `systemctl` for the user service. The widget downloads
nothing and opens no network connection. `omawake-bin` is the packaged release
of Omawake, whose own `licenses/` directory and `THIRD_PARTY_NOTICES.md`
describe the components it bundles; model downloads and microphone capture
belong to Omawake itself and are not performed by this widget.

## Checks

```bash
node --test tests/
```

Covers the status and wake-word parsing, the live and paused states, the
service-present check, and the backend and model display. Node is needed only
for these development checks, not for the widget.

## License

MIT, see [LICENSE](LICENSE).
