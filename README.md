# flick

A tiny macOS menu bar app + CLI for toggling services (VPN, Tailscale, anything with a connect/disconnect command) from a global hotkey or a single click.

The menu bar shows one colored dot for aggregate status. Press your hotkey, the service flips. That's it.

## Features

- **Menu bar dot** reflecting aggregate status:
  - ○ empty = all disconnected
  - ● green = all connected
  - ● yellow = some connected
  - dimmed = a toggle is in progress
- **Click** the dot to open a service menu; **Alt+click** to quit
- **Global hotkeys** — one to open the menu, one per service to toggle directly
- **CLI** (`flick`) for scripts and the terminal
- **Generic** — drives any service via shell commands you define
- **No Accessibility permission** — hotkeys use Carbon's `RegisterEventHotKey`, which needs no permission and consumes the keystroke (no leak to the focused app)
- **Zero dependencies** beyond the macOS SDK

## Requirements

- macOS 14.0+ (Swift toolchain ships with the Xcode Command Line Tools: `xcode-select --install`)
- Whatever the services you configure need (e.g. `brew install openvpn`)
- For commands that use `sudo` without a prompt, a sudoers entry, e.g.:
  ```
  <your-username> ALL=(ALL) NOPASSWD: /opt/homebrew/sbin/openvpn, /usr/bin/killall openvpn
  ```

## Build & Install

```bash
make build      # Compile the app and CLI into .build/
make run        # Build and launch the menu bar app
make cli        # Build just the CLI and print its path
make install    # Copy the app to /Applications and `flick` to /usr/local/bin
make clean      # Remove build artifacts
```

To launch the app at login: System Settings → General → Login Items → add `Flick.app`.

## Configuration

On first run, flick creates `~/.config/flick.json` with a starter OpenVPN
service. Edit it to point at your real config and add more services. See
[`flick.json.example`](flick.json.example) for a two-service example.

```json
{
  "menu_hotkey_key": "space",
  "menu_hotkey_modifiers": ["cmd", "opt"],
  "services": [
    {
      "id": "openvpn",
      "name": "OpenVPN",
      "status_command": "pgrep -x openvpn",
      "connect_command": "sudo /opt/homebrew/sbin/openvpn --config /path/to/your/config.ovpn --daemon",
      "disconnect_command": "sudo killall openvpn",
      "hotkey_key": "v",
      "hotkey_modifiers": ["cmd", "opt"]
    }
  ]
}
```

| Field | Meaning |
|-------|---------|
| `menu_hotkey_key` / `menu_hotkey_modifiers` | Global hotkey that opens the service menu |
| `services[].id` | Identifier used by the CLI |
| `services[].name` | Display name in the menu |
| `services[].status_command` | Run to check status — **exit code 0 means connected** |
| `services[].connect_command` | Run to connect |
| `services[].disconnect_command` | Run to disconnect |
| `services[].hotkey_key` / `hotkey_modifiers` | Global hotkey that toggles this service |

**Keys:** `a`–`z`, `0`–`9`, `space`, `return`, `tab`, `escape`
**Modifiers:** `cmd`, `opt`, `shift`, `ctrl`

## CLI

```bash
flick                       # list services and their status
flick <id>                  # toggle a service
flick <id> status           # print "connected" / "disconnected"
flick <id> connect          # force connect
flick <id> disconnect       # force disconnect
```

Run it without installing straight from the build dir: `.build/flick <id>`.

## How it works

The app and CLI share the same config. `status_command` is run and its exit
code decides connected vs disconnected; the app polls it once a second to keep
the dot current. Toggling just runs `connect_command` or `disconnect_command`.
Because everything is a shell command you define, flick isn't tied to OpenVPN —
point it at Tailscale, WireGuard, a Docker container, an `ssh -D` tunnel, etc.

## Project layout

| File | Role |
|------|------|
| `Flick.swift` | App entry point, menu bar UI, status menu |
| `ServicesModel.swift` | Observable state: polls status, runs toggles |
| `HotkeyManager.swift` | Carbon global hotkey registration |
| `Config.swift` | Config model + loader (app) |
| `flick-cli.swift` | The `flick` command-line tool (self-contained) |
| `Logger.swift` | Tiny file logger at `~/.config/flick.log` |

## License

MIT — see [LICENSE](LICENSE).
