# WSL Cheatsheet - Tmux + Alacritty + Opencode

Reference guide for working with WSL2, Alacritty, Tmux, and Opencode.

## Inside Opencode (Running)

| Action | Shortcut |
|--------|----------|
| **Copy** | `Ctrl + Shift + C` |
| **Paste** | `Ctrl + Shift + V` |
| **Select text** | Hold `Shift` + Click & Drag |

## General Alacritty (Outside Opencode)

| Action | Shortcut |
|--------|----------|
| **Copy** | `Ctrl + Shift + C` |
| **Paste** | `Ctrl + Shift + V` |
| **Select text** | Click & Drag (no Shift needed) |

## Tmux Copy Mode

Enter copy mode first: `Ctrl + A` then `[`

| Action | Shortcut |
|--------|----------|
| **Enter copy mode** | `Ctrl + A` + `[` |
| **Start selection** | `v` (vi mode) |
| **Copy selection** | `y` or `Enter` |
| **Exit copy mode** | `q` or `Escape` |
| **Scroll up/down** | `↑` `↓` or `k` `j` |
| **Search** | `/` (forward) `?` (backward) |

## Tmux Window Management

| Action | Shortcut |
|--------|----------|
| **New window** | `Ctrl + A` + `c` |
| **Next window** | `Ctrl + A` + `n` |
| **Previous window** | `Ctrl + A` + `p` |
| **Split horizontal** | `Ctrl + A` + `"` |
| **Split vertical** | `Ctrl + A` + `%` |
| **Switch pane** | `Ctrl + A` + Arrow keys |
| **Detach session** | `Ctrl + A` + `d` |

## Windows Clipboard (System Level)

| Action | Shortcut |
|--------|----------|
| **Copy** | `Ctrl + C` |
| **Paste** | `Ctrl + V` |
| **Cut** | `Ctrl + X` |

## Tips

1. **When opencode is running:** Always hold `Shift` when selecting to bypass tmux
2. **Mouse selection in tmux:** `Shift` + drag selects terminal text directly
3. **Copy from opencode output:** Use `Shift` + mouse select, then `Ctrl + Shift + C`
4. **Paste into opencode:** `Ctrl + Shift + V` or right-click → Paste
5. **Tmux scrollback:** `Ctrl + A` + `[` then scroll with mouse or arrow keys

## WSL Utilities (wslu)

Bridge tools between WSL and Windows

| Command | Description | Example |
|---------|-------------|---------|
| **wslview** | Open URLs/files in Windows apps | `wslview https://github.com` or `wslview file.pdf` |
| **wslvar** | Get Windows environment variables | `wslvar USERPROFILE` |
| **wslsys** | Show WSL/Windows system info | `wslsys` |
| **wslfetch** | Pretty system info display | `wslfetch` (like neofetch) |
| **wslusc** | Create Windows desktop shortcuts | `wslusc alacritty` |
| **wslact** | Quick WSL actions | `wslact --help` |

### Common wslu Usage

```bash
# Open GitHub in Windows browser
wslview https://github.com

# Open PDF with Windows default app
wslview document.pdf

# Get Windows home directory path
wslvar USERPROFILE

# Create desktop shortcut for Linux app
wslusc firefox

# Create shortcut for GUI app
wslusc -g alacritty
```

### Troubleshooting wslusc

**Error: "wsl.ico not found. Failed to copy."**

If you have a space or special characters in your Windows username, wslusc may fail to copy icon files. Fix:

```bash
# Find wslu icons
find /nix/store -name "wsl*.ico" 2>/dev/null

# Copy icons manually (replace 'Your Name' with your username)
cp /nix/store/*/share/wslu/*.ico "/mnt/c/Users/Your Name/wslu/"
cp /nix/store/*/share/wslu/*.vbs "/mnt/c/Users/Your Name/wslu/" 2>/dev/null

# Then run wslusc again
wslusc -g alacritty
```

## Quick Reference: Copy-Paste Scenarios

### Copy from opencode output → Paste elsewhere
1. Hold `Shift`
2. Click and drag to select
3. `Ctrl + Shift + C`
4. Go to destination
5. `Ctrl + V` (Windows) or `Ctrl + Shift + V` (terminal)

### Copy from tmux scrollback → Paste into opencode
1. `Ctrl + A` + `[` (enter copy mode)
2. Use `↑` or `k` to scroll up
3. `v` to start selection
4. Arrow keys to select
5. `y` or `Enter` to copy (uses `clip.exe` on WSL)
6. `q` to exit copy mode
7. `Ctrl + Shift + V` in opencode

### Copy from another application → Paste into opencode
1. Select and copy in source app (`Ctrl + C`)
2. `Ctrl + Shift + V` in opencode

---

*Environment: WSL2 + Alacritty + Tmux + Opencode*
