# flick

[![CI](https://github.com/ekinertac/flick/actions/workflows/ci.yml/badge.svg)](https://github.com/ekinertac/flick/actions/workflows/ci.yml)

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

## What you can do with it

flick toggles anything you can express as "check / start / stop" shell commands.
A few recipes for `services[]` entries:

**VPNs & tunnels**
```jsonc
// OpenVPN
{ "id": "vpn", "name": "OpenVPN",
  "status_command": "pgrep -x openvpn",
  "connect_command": "sudo /opt/homebrew/sbin/openvpn --config /path/to/config.ovpn --daemon",
  "disconnect_command": "sudo killall openvpn" }

// WireGuard
{ "id": "wg", "name": "WireGuard",
  "status_command": "sudo wg show wg0 >/dev/null 2>&1",
  "connect_command": "sudo wg-quick up wg0",
  "disconnect_command": "sudo wg-quick down wg0" }

// Tailscale
{ "id": "ts", "name": "Tailscale",
  "status_command": "tailscale status >/dev/null 2>&1",
  "connect_command": "tailscale up",
  "disconnect_command": "tailscale down" }

// SOCKS proxy over SSH
{ "id": "socks", "name": "SSH Proxy",
  "status_command": "pgrep -f 'ssh -D 1080'",
  "connect_command": "ssh -fND 1080 myserver",
  "disconnect_command": "pkill -f 'ssh -D 1080'" }
```

**Local dev & infra**
```jsonc
// A docker-compose stack
{ "id": "stack", "name": "Dev Stack",
  "status_command": "docker compose -f ~/app/compose.yml ps -q | grep -q .",
  "connect_command": "docker compose -f ~/app/compose.yml up -d",
  "disconnect_command": "docker compose -f ~/app/compose.yml down" }

// Local database
{ "id": "pg", "name": "Postgres",
  "status_command": "pg_isready -q",
  "connect_command": "brew services start postgresql@16",
  "disconnect_command": "brew services stop postgresql@16" }
```

**System toggles**
```jsonc
// Caffeinate (keep the Mac awake)
{ "id": "wake", "name": "Stay Awake",
  "status_command": "pgrep -x caffeinate",
  "connect_command": "caffeinate -dimsu &",
  "disconnect_command": "pkill -x caffeinate" }
```

Each service gets its own dot in the menu and an optional global hotkey, and the
menu bar dot turns green only when everything you've configured is up. If a
recipe needs `sudo` without a password prompt, add the matching sudoers entry
(see below).

## Requirements

- macOS 14.0+ (Swift toolchain ships with the Xcode Command Line Tools: `xcode-select --install`)
- Whatever the services you configure need (e.g. `brew install openvpn`)
- For commands that use `sudo` without a prompt, a sudoers entry, e.g.:
  ```
  <your-username> ALL=(ALL) NOPASSWD: /opt/homebrew/sbin/openvpn, /usr/bin/killall openvpn
  ```

## Install

### Homebrew (recommended)

```bash
brew install ekinertac/tap/flick
```

This builds from source on your machine, so there's no Gatekeeper /
notarization prompt. It installs the `flick` CLI and a `Flick.app` bundle; to
use the menu bar app, copy it to `/Applications` (Homebrew prints the exact
path in its caveat):

```bash
cp -r "$(brew --prefix flick)/Flick.app" /Applications/
```

Then add it under System Settings → General → Login Items.

### From source

```bash
make build      # Compile the app and CLI into .build/
make run        # Build and launch the menu bar app
make cli        # Build just the CLI and print its path
make install    # Copy the app to /Applications and `flick` to /usr/local/bin
make clean      # Remove build artifacts
```

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
