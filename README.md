# mod-system-utils

System configuration utilities for running mod-host and mod-ui on Ubuntu 25.10 with PipeWire.

This repository contains systemd service files, configuration files, and installation scripts for setting up a complete MOD Audio system on Ubuntu with PipeWire audio.

## Overview

This repository provides the "glue" that makes mod-host and mod-ui work together as a complete audio processing system on modern Ubuntu with PipeWire:

- **Systemd services**: Automatic startup and management of mod-host and mod-ui
- **PipeWire-JACK configuration**: Proper integration with PipeWire audio system
- **Hardware descriptor**: Configuration for audio I/O and device capabilities
- **Web interface**: JACK configuration through mod-ui settings page

## Prerequisites

Before using this repository, you must install:

1. **mod-host**: [Installation guide](https://github.com/pilali/mod-host/blob/ubuntu-pipewire-build/INSTALL-UBUNTU-PIPEWIRE.md)
2. **mod-ui**: [Installation guide](https://github.com/pilali/mod-ui/blob/ubuntu-pipewire-install/INSTALL-UBUNTU-PIPEWIRE.md)

## Quick Start

```bash
# Clone this repository
git clone https://github.com/pilali/mod-system-utils.git
cd mod-system-utils

# Run installation script
sudo ./install.sh

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable mod-host.service mod-ui.service
sudo systemctl start mod-host.service mod-ui.service

# Check status
sudo systemctl status mod-host.service
sudo systemctl status mod-ui.service
```

## Repository Structure

```
mod-system-utils/
├── systemd/
│   ├── mod-host.service    # Systemd service for mod-host
│   └── mod-ui.service      # Systemd service for mod-ui
├── config/
│   └── mod-hardware-descriptor.json  # Hardware configuration
├── html/
│   └── settings.html       # Modified settings page with JACK config
├── scripts/
│   └── (future scripts)
├── install.sh              # Installation script
└── README.md
```

## What's Inside

### Systemd Services

#### mod-host.service

Runs mod-host with PipeWire-JACK support:
- Uses `pw-jack` wrapper for JACK connectivity
- Listens on ports 5555 (commands) and 5556 (feedback)
- Runs as your user account
- Automatically restarts on failure

#### mod-ui.service

Runs mod-ui web interface with JACK support:
- Uses `pw-jack` wrapper (essential for port management)
- Binds to port 80 (requires CAP_NET_BIND_SERVICE capability)
- Depends on mod-host.service
- Provides web UI at http://localhost/

### Configuration Files

#### mod-hardware-descriptor.json

Defines the audio hardware capabilities:
```json
{
    "name": "MOD Audio Generic PC",
    "platform": "x86_64",
    "audio_channels": 2,
    "has_noisegate": true,
    "has_tuner_input": true,
    ...
}
```

This file tells mod-ui:
- How many audio channels are available
- What features to enable (tuner, noisegate, etc.)
- Which JACK ports to look for

### Web Interface

#### settings.html

Modified version of mod-ui's settings page that includes:
- JACK/PipeWire configuration interface
- Audio interface selection
- Sample rate and buffer size configuration
- Integration with `/jack/interfaces`, `/jack/config`, and `/jack/restart` endpoints

## Installation Details

The `install.sh` script performs the following:

1. Copies systemd service files to `/etc/systemd/system/`
2. Copies hardware descriptor to `/etc/mod-hardware-descriptor.json`
3. Copies modified settings.html to `/usr/local/share/mod/html/`
4. Sets appropriate permissions
5. Creates `/var/modep` data directory if needed

## Key Configuration Points

### Why pw-jack is Required

Both services use the `pw-jack` wrapper:

```ini
ExecStart=/usr/bin/pw-jack /usr/local/bin/mod-host -v -n -p 5555 -f 5556
```

This is **essential** because:
- PipeWire provides JACK compatibility through a wrapper
- Without `pw-jack`, applications cannot connect to JACK ports
- mod-ui needs JACK to manage audio connections and display ports

### Port 80 Access

mod-ui binds to port 80 without running as root using:

```ini
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

This gives the process permission to bind privileged ports while running as your user.

### Environment Variables

Important variables set in the service files:

| Variable | Purpose |
|----------|---------|
| `XDG_RUNTIME_DIR` | PipeWire runtime directory |
| `MOD_DATA_DIR` | mod-ui data storage |
| `MOD_HTML_DIR` | Web interface files |
| `MOD_DEV_HOST` | Enable development features |
| `LV2_PATH` | LV2 plugin search paths |
| `PYTHONPATH` | Python module search path |

## Usage

### Starting the System

```bash
# Start both services
sudo systemctl start mod-host.service mod-ui.service

# Check they're running
sudo systemctl status mod-host
sudo systemctl status mod-ui
```

### Accessing the Web Interface

1. Open browser to `http://localhost/`
2. You should see the mod-ui pedalboard interface
3. Audio inputs and outputs should be visible
4. CPU activity should show percentage (not 0%)

### Configuring JACK/PipeWire

1. Go to `http://localhost/settings.html`
2. Select your audio interface from the dropdown
3. Configure sample rate and buffer size
4. Click "Restart JACK" to apply changes

### Viewing Logs

```bash
# mod-host logs
sudo journalctl -u mod-host.service -f

# mod-ui logs
sudo journalctl -u mod-ui.service -f

# Both together
sudo journalctl -u mod-host.service -u mod-ui.service -f
```

## Troubleshooting

### Services won't start

Check the logs:
```bash
sudo journalctl -u mod-host.service -n 50
sudo journalctl -u mod-ui.service -n 50
```

Common issues:
- mod-host or mod-ui not installed
- PipeWire not running
- Port 5555 or 80 already in use

### No audio ports visible in web UI

This usually means mod-ui is not connected to JACK:

1. Check mod-ui is using pw-jack:
```bash
ps aux | grep mod-ui
# Should show: /usr/bin/pw-jack /usr/local/bin/mod-ui
```

2. Restart mod-ui service:
```bash
sudo systemctl restart mod-ui.service
```

### CPU shows 0%

This means mod-ui cannot communicate with mod-host:

1. Check mod-host is running:
```bash
sudo systemctl status mod-host
```

2. Check ports are listening:
```bash
ss -tlnp | grep -E "5555|5556"
```

3. Check mod-ui can connect to JACK:
```bash
pw-jack jack_lsp
# Should show mod-host:in1, mod-host:in2, mod-host:out1, mod-host:out2
```

## Architecture Notes

### Audio Flow

```
Hardware Audio Interface
        ↕ (ALSA)
    PipeWire
        ↕ (JACK bridge via pw-jack)
    mod-host (LV2 plugin host)
        ↕ (TCP socket 5555/5556)
    mod-ui (Web interface)
        ↕ (HTTP)
    Web Browser
```

### Why This Setup Works

1. **PipeWire** provides modern audio routing with JACK compatibility
2. **pw-jack** wrapper allows JACK applications to work with PipeWire
3. **mod-host** processes audio through LV2 plugins
4. **mod-ui** provides web-based control and visualization
5. **Systemd** manages services and dependencies automatically

## Customization

### Changing the Web Port

Edit `systemd/mod-ui.service`:

```ini
Environment="MOD_DEVICE_WEBSERVER_PORT=8080"
```

Then reinstall and restart:
```bash
sudo ./install.sh
sudo systemctl daemon-reload
sudo systemctl restart mod-ui
```

### Using a Different Audio Interface

1. Go to http://localhost/settings.html
2. Select your interface from the dropdown
3. Click "Restart JACK"

Or edit PipeWire configuration directly (advanced).

### Adding More LV2 Plugins

Add plugin directories to the `LV2_PATH` in both service files:

```ini
Environment="LV2_PATH=/var/modep/lv2:/usr/local/lib/lv2:/usr/lib/lv2:/your/custom/path"
```

## Contributing

Contributions welcome! This repository is specifically for Ubuntu 25.10 + PipeWire setup, but could be adapted for other distributions.

## Related Projects

- [mod-host](https://github.com/pilali/mod-host) - LV2 plugin host
- [mod-ui](https://github.com/pilali/mod-ui) - Web interface for mod-host
- [MOD Audio](https://mod.audio/) - Original MOD Audio project

## License

These configuration files and scripts are provided under GPL-3.0 license to match mod-host and mod-ui licensing.

## Credits

Based on the excellent work by:
- [MOD Audio team](https://github.com/moddevices)
- [sejerpz](https://github.com/sejerpz) for Python 3.x compatibility work on mod-ui

System integration by pilali with assistance from Claude Code.
