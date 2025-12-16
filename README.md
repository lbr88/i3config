# i3 Config

My personal i3 window manager configuration.

## Installation

To install this configuration on a new machine, run the following one-liner. This will back up any existing i3 configuration before installing:

```bash
[ -d ~/.config/i3 ] && mv ~/.config/i3 ~/.config/i3.backup.$(date +%s); git clone https://github.com/lbr88/i3config.git ~/.config/i3 && chmod +x ~/.config/i3/install.sh && ~/.config/i3/install.sh
```

This will:
1. Clone the repository to `~/.config/i3`.
2. Install necessary system dependencies (Arch/Manjaro or Debian/Ubuntu).
3. Set up Python dependencies.
4. Configure custom scripts.
