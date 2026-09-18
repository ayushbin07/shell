
# Linux Ricing Journal

> Personal documentation of my Linux customization journey, experiments, configurations, fixes, and lessons learned.

---

## System Overview

| Component | Details |
|---|---|
| Operating System | Fedora Workstation 44 |
| Window Manager | Hyprland |
| Desktop Environment | GNOME previously used |
| Shell / Bar | Caelestia |
| Shell Framework | Quickshell |
| Launcher | Vicinae |
| Terminal | Kitty |
| Browser | Brave |
| Primary Configuration Path | `~/.config` |
| Caelestia Configuration | `~/.config/quickshell/caelestia` |

---

## Main Configuration Paths

```text
~/.config/
├── hypr/
│   ├── hyprland.conf
│   └── hyprland/
│       ├── execs.lua
│       ├── general.lua
│       └── keybinds.lua
│
├── quickshell/
│   └── caelestia/
│       ├── shell.qml
│       ├── shell.json
│       ├── modules/
│       ├── scripts/
│       └── plugin/
│
└── systemd/
    └── user/
        ├── caelestia.service
        └── vicinae.service
```

---

## Current Desktop Setup

### Window Manager

- Hyprland is used as the primary window manager.
- Configuration is written using Lua-based Hyprland configuration helpers.
- Window behavior, workspace switching, application launching, and media controls are managed through keybindings.
- Blur, opacity, floating windows, and workspace navigation are part of the customization process.

### Shell

- Caelestia is used as the desktop shell.
- Caelestia is powered by Quickshell.
- The shell configuration is located at:

```bash
~/.config/quickshell/caelestia
```

### Launcher

- Vicinae is used as the application launcher and command interface.
- Vicinae is configured as a user-level systemd service.

---

## Keybindings

| Shortcut | Action |
|---|---|
| `Super + Q` | Close the active window |
| `Super + Enter` | Open terminal |
| `Super + E` | Open file manager |
| `Super + W` | Open browser |
| `Super + F` | Toggle fullscreen |
| `Super + D` | Toggle maximized fullscreen |
| `Super + Alt + Space` | Toggle floating and tiled mode |
| `Super + V` | Clipboard-related shortcut, currently under review |
| `Super + Arrow Keys` | Workspace navigation, depending on current configuration |
| `Super + Shift + Arrow Keys` | Move applications between workspaces, depending on current configuration |
| `XF86Favorites` | Play / pause media using `playerctl` |

### Media Key Configuration

```lua
hl.bind(
    "XF86Favorites",
    hl.dsp.exec("playerctl play-pause"),
    {
        description = "Media: Play/Pause"
    }
)
```

---

## Caelestia and Quickshell

### Configuration Location

```bash
cd ~/.config/quickshell/caelestia
```

### Important Files

| File / Directory | Purpose |
|---|---|
| `shell.qml` | Main shell entry point |
| `shell.json` | User-facing shell configuration |
| `modules/` | UI modules and shell components |
| `modules/utilities/` | Utility widgets and toggles |
| `modules/utilities/cards/` | Utility card components |
| `scripts/` | Supporting scripts |
| `plugin/` | Plugin-related source code |

### Example Utility Module

```text
modules/
└── utilities/
    └── cards/
        └── Toggles.qml
```

This file contains toggle-related UI components and is one of the main locations for experimenting with custom utility buttons.

---

## Caelestia Startup

### Systemd Service

Service file:

```bash
~/.config/systemd/user/caelestia.service
```

Example structure:

```ini
[Unit]
Description=Caelestia Shell
After=graphical-session.target

[Service]
ExecStart=%h/.local/bin/caelestia-shell
Restart=on-failure
Environment=QT_QPA_PLATFORM=wayland

[Install]
WantedBy=graphical-session.target
```

### Useful Commands

```bash
systemctl --user daemon-reload
```

```bash
systemctl --user enable --now caelestia.service
```

```bash
systemctl --user status caelestia.service
```

```bash
systemctl --user restart caelestia.service
```

```bash
journalctl --user -u caelestia.service -f
```

### Important Startup Lesson

Caelestia should not be launched simultaneously through both:

1. Hyprland startup configuration
2. A systemd user service

Launching it from both places can create duplicate shell instances.

Potential Hyprland startup entry:

```text
~/.config/hypr/hyprland/execs.lua
```

Example:

```lua
hl.exec_cmd("/home/ayu/.local/bin/caelestia-shell")
```

If systemd manages Caelestia, avoid launching it again from Hyprland.

---

## Duplicate Caelestia Instance Fix

### Problem

Two Caelestia processes were running simultaneously.

### Inspection Command

```bash
pgrep -af "caelestia|quickshell"
```

### Possible Cause

Caelestia was started from both:

- `execs.lua`
- `caelestia.service`

### Cleanup

Stop duplicate processes if necessary:

```bash
pkill -f caelestia-shell
```

Or inspect Quickshell processes:

```bash
pgrep -af quickshell
```

Then restart Caelestia using only one startup method.

---

## Editing Workflow

### Open the Configuration in VS Code

```bash
code ~/.config/quickshell/caelestia
```

### Recommended Workflow

1. Inspect the existing implementation.
2. Identify the smallest file that needs modification.
3. Create a backup before changing it.
4. Make one change at a time.
5. Restart or reload the shell.
6. Test the result.
7. Revert immediately if the shell breaks.
8. Commit working changes to Git.

### Backup Example

```bash
cp \
~/.config/quickshell/caelestia/modules/utilities/cards/Toggles.qml \
~/.config/quickshell/caelestia/modules/utilities/cards/Toggles.qml.backup
```

### Restore Example

```bash
cp \
~/.config/quickshell/caelestia/modules/utilities/cards/Toggles.qml.backup \
~/.config/quickshell/caelestia/modules/utilities/cards/Toggles.qml
```

---

## Git Tracking

The Caelestia configuration can be tracked with Git to preserve changes and make experimentation safer.

### Initialize Git

```bash
cd ~/.config/quickshell/caelestia
```

```bash
git init
```

### Create Initial Commit

```bash
git add .
```

```bash
git commit -m "Initial Caelestia configuration backup"
```

### Check Changes

```bash
git status
```

```bash
git diff
```

### View Commit History

```bash
git log --oneline
```

### Important Git Safety Notes

- Review files before pushing them to GitHub.
- Do not commit API keys, tokens, passwords, or private credentials.
- Prefer a private repository for personal configuration files.
- Avoid using `sudo` when editing files inside the home directory.
- Keep backups before major changes.

---

## Linux Troubleshooting Journal

### Bluetooth Audio Shuttering

#### Symptoms

- Bluetooth TWS audio was occasionally stuttering.
- Audio interruptions appeared to correlate with system behavior and kernel changes.
- PipeWire and WirePlumber were investigated.

#### Investigation Areas

```bash
systemctl --user status pipewire
```

```bash
systemctl --user status wireplumber
```

```bash
journalctl --user -u pipewire
```

```bash
journalctl --user -u wireplumber
```

```bash
uname -r
```

#### Finding

The issue appeared to be related to a Linux kernel regression.

#### Resolution

Downgrading to a previous kernel resolved the Bluetooth shuttering problem.

#### Lesson

When hardware problems begin after a kernel update:

1. Check the current kernel version.
2. Compare behavior with an older installed kernel.
3. Inspect PipeWire and WirePlumber logs.
4. Avoid changing multiple unrelated settings simultaneously.
5. Keep a known-working kernel available.

---

## Brave Browser Cleanup

### Goal

Remove Brave web applications while keeping the Brave browser installed.

### Brave Package Check

```bash
rpm -qa | grep -i brave
```

### Flatpak Check

```bash
flatpak list | grep -i brave
```

### Web App Desktop Files

Brave web app launchers may be stored here:

```bash
~/.local/share/applications/
```

Search for Brave web app entries:

```bash
find "$HOME/.local/share/applications" \
-maxdepth 1 \
-type f \
-name 'brave-*.desktop' \
-print
```

### Cleanup Principle

- Remove unwanted Brave web app `.desktop` files.
- Do not remove the main Brave browser package.
- Verify each desktop file before deleting it.
- Keep a backup if uncertain.

---

## Vicinae Setup

### Service File

```bash
~/.config/systemd/user/vicinae.service
```

### Enable the Service

```bash
systemctl --user daemon-reload
```

```bash
systemctl --user enable --now vicinae.service
```

### Check Status

```bash
systemctl --user status vicinae.service
```

### General Lesson

User-level services are useful for launching desktop utilities without requiring root privileges or system-wide configuration.

---

## Experiments and Ideas

### Completed or Tested

- [x] Installed and configured Hyprland.
- [x] Experimented with Caelestia and Quickshell.
- [x] Installed Vicinae.
- [x] Configured media play/pause keybinding.
- [x] Investigated duplicate Caelestia instances.
- [x] Investigated Bluetooth audio shuttering.
- [x] Downgraded the kernel to resolve Bluetooth issues.
- [x] Opened Caelestia configuration in VS Code.
- [x] Started planning Git-based configuration tracking.
- [x] Cleaned up Brave web app entries.
- [ ] Finalize workspace navigation keybindings.
- [ ] Finalize clipboard manager integration.
- [ ] Add carefully tested custom utility toggles.
- [ ] Create a polished personal Caelestia theme.
- [ ] Push configuration to a private GitHub repository.
- [ ] Document all working keybindings.
- [ ] Create a recovery procedure for broken shell configurations.

---

## Current Issues

| Issue | Status | Notes |
|---|---|---|
| Workspace navigation | In progress | Keybinding syntax is still being refined |
| Clipboard shortcut | Under review | Existing shortcut opened screenshot snipper |
| Caelestia startup duplication | Investigated | Avoid running Hyprland and systemd startup simultaneously |
| Custom utility toggles | Experimental | Must verify APIs before implementation |
| Git tracking | Planned / started | Review sensitive files before pushing |
| Bluetooth audio | Resolved for now | Kernel downgrade appeared to fix shuttering |

---

## Useful Commands

### Hyprland

```bash
hyprctl monitors
```

```bash
hyprctl clients
```

```bash
hyprctl reload
```

```bash
hyprctl dispatch
```

### Processes

```bash
pgrep -af caelestia
```

```bash
pgrep -af quickshell
```

```bash
ps aux | grep -i caelestia
```

### System Information

```bash
uname -r
```

```bash
systemctl --failed
```

```bash
journalctl -b -p warning
```

### File Ownership

```bash
ls -ld ~/.config/quickshell/caelestia
```

If ownership is incorrect:

```bash
sudo chown -R "$USER:$USER" ~/.config/quickshell/caelestia
```

### VS Code

```bash
code ~/.config/quickshell/caelestia
```

---

## Change Log

### 2026-09-18

- Opened the Caelestia configuration directory in VS Code.
- Began treating the shell configuration as a codebase rather than randomly editing files like a caffeinated raccoon.
- Planned to use Git for version tracking.
- Documented the Caelestia startup duplication issue.
- Continued organizing the Linux ricing workflow.

### 2026-09-17

- Investigated duplicate Caelestia processes.
- Found that Caelestia was being launched through both Hyprland and systemd.
- Tested process cleanup and service-based startup.
- Continued experimenting with Hyprland keybindings.
- Confirmed media play/pause binding using `playerctl`.

### 2026-09-16

- Investigated Bluetooth TWS audio shuttering.
- Connected the issue to a kernel regression.
- Downgraded the kernel and observed improved audio stability.
- Reviewed PipeWire and WirePlumber processes and logs.

### 2026-09-15

- Configured Vicinae as a user-level systemd service.
- Continued refining the Hyprland and Caelestia environment.
- Backed up Hyprland-related configuration files.

---

## Lessons Learned

- Make backups before editing shell code.
- Change one configuration file at a time.
- Never assume an API exists just because a name sounds plausible.
- Avoid running the same service from multiple startup systems.
- Use Git to make experimentation reversible.
- Read logs before randomly reinstalling packages.
- Keep a working kernel available when testing newer kernels.
- Avoid `sudo` for personal configuration editing.
- Small, tested changes are better than rewriting an entire configuration.
- Linux customization is 30% design, 30% debugging, and 40% wondering why a three-line change broke the entire desktop.

---

## Future Goals

- Build a clean and consistent visual identity for the desktop.
- Create a reliable, documented Hyprland configuration.
- Customize Caelestia without breaking upstream updates.
- Build useful custom Quickshell widgets.
- Integrate a proper clipboard manager.
- Improve workspace navigation.
- Maintain dotfiles through Git.
- Create automated backup and restore scripts.
- Keep the system fast, stable, and visually coherent.
- Publish selected configuration components as open source.