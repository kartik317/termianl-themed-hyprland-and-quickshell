# Terminal Desktop Configuration

A custom Hyprland and Quickshell setup for a polished Linux desktop experience. This configuration includes:

- `hypr/`: Hyprland config files, automation scripts, and helper modules
- `quickshell/`: QML-based shell UI components and widgets

## Overview

This repository is organized into two primary sections:

1. `hypr/`
   - Core Hyprland configuration files
   - Window rules and monitor setup modules
   - Autostart scripts and performance tweaks
   - Voice assistant integration and automation scripts

2. `quickshell/`
   - QML files for the main shell UI
   - Custom status bar widgets and controls
   - Lock screen, power menu, wallpaper controls, and voice assistant panels

## hypr/

### Main config files

- `hyprland.lua` - Primary Hyprland configuration
- `hypridle.conf` - Screen idle and locking settings
- `hyprlock.conf` - Lock screen configuration
- `hyprpaper.conf` - Wallpaper manager settings
- `hyprland-border.lua` - Custom border styles for Hyprland
- `performance_mode.lua` - Performance tuning script/config

### Modules

- `modules/animations.lua` - Window animation settings
- `modules/autostart.lua` - Autostart applications and services
- `modules/keybinds.lua` - Custom keybindings
- `modules/layerrules.lua` - Layer and workspace behavior rules
- `modules/monitor.lua` - Monitor layout and output management
- `modules/windowrules.lua` - Window placement and behavior rules

### Scripts

- `scripts/live-wallpaper-yazi.sh` - Launch live wallpaper
- `scripts/restore-wallpaper.sh` - Restore wallpaper
- `scripts/toggle-cava-bg.sh` - Toggle Cava background visualization
- `scripts/toggle-glava.sh` - Toggle Glava visualization
- `scripts/toggle-quickshell.sh` - Show or hide Quickshell UI
- `scripts/toggle-waybar.sh` - Toggle Waybar visibility
- `scripts/wallpaper-yazi.sh` - Wallpaper setup helper

### Assistant

A voice-assistant and automation system for Hyprland.

- `assistant/action.json` - Action definitions
- `assistant/apps.json` - Application metadata for assistant commands
- `assistant/generate_json.py` - Helper script to generate JSON data
- `assistant/speak.py` - Text-to-speech logic
- `assistant/start.sh` / `assistant/stop.sh` - Start/stop assistant services
- `assistant/start_talking.sh` / `assistant/stop_talking.sh` - Voice activity control
- `assistant/take_action.py` - Execute assistant actions
- `assistant/transcribe_talk.py` - Speech transcription flow
- `assistant/transcription.py` - Transcription utilities
- `assistant/task.txt` - Pending assistant tasks
- `assistant/prompts/` - Prompt templates for assistant interactions
  - `into_prompt.txt`
  - `system_prompt.txt`
  - `talk_prompt.txt`

## quickshell/

Quickshell is the UI layer for the desktop.

### Core shell

- `shell.qml` - Main shell entrypoint for Quickshell

### App launcher

- `quickshell/app_launcher/AppLauncher.qml`
- `quickshell/app_launcher/AppLauncherState.qml`

### Bar widgets

- `quickshell/bar/Bar.qml` - Main bar implementation
- `quickshell/bar/Clock.qml` - Clock widget
- `quickshell/bar/Battery.qml` - Battery status
- `quickshell/bar/Network.qml` - Network widget
- `quickshell/bar/Tray.qml` - System tray support
- `quickshell/bar/Workspaces.qml` - Workspace indicator
- `quickshell/bar/MediaControls.qml` and `quickshell/bar/media_controls/` - Media widget
- `quickshell/bar/Volume.qml` - Volume widget
- `quickshell/bar/SysInfo.qml` - System information widget
- `quickshell/bar/BorderedPill.qml` / `Separator.qml` - Visual layout components

### Controls and widgets

- `quickshell/brightness_controls/` - Brightness control UI
- `quickshell/lock_screen/` - Lock screen UI components
- `quickshell/power_menu/` - Power menu controls
- `quickshell/live_wallpaper_switcher/` - Live wallpaper selector
- `quickshell/wallpaper_switcher/` - Wallpaper switching UI
- `quickshell/wallpaper_clock/` - Draggable clock overlay
- `quickshell/widgets/` - Shared widget components

### Voice assistant UI

- `quickshell/voice_assistant/NovaPanel.qml`
- `quickshell/voice_assistant/NovaState.qml`
- `quickshell/voice_assistant/NovaWave.qml`
- `quickshell/voice_assistant/cava-nova.conf`

### Theme

- `quickshell/theme/Colors.qml` - Theme colors for Quickshell

## Usage

1. Copy the `hypr/` and `quickshell/` folders into your Hyprland configuration directory.
2. Ensure Hyprland is installed and the required QML runtime is available.
3. Update paths in the configuration files if needed.
4. Start Hyprland and launch Quickshell with the provided `shell.qml`.

## Notes

- This setup combines Hyprland window management with Quickshell shell UI.
- The `assistant/` folder contains AI/voice automation tools for hands-free control.
- The scripts under `hypr/scripts` are utilities for wallpaper, visualization, and shell toggling.