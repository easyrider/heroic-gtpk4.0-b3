# Game Porting Toolkit (GPTK) 4.0 Beta 3 for Heroic Games Launcher

This is a fork of: https://github.com/Maxyme/heroic-gtpk4.0-b2
I have update the script to handle beta 3

This repository automates the installation and integration of **Apple Game Porting Toolkit 4.0 Beta 3** into **Heroic Games Launcher** using an existing GPTK base (such as `Game-Porting-Toolkit-3.0-3`).

---

## Step 0: Prerequisites & Downloads

* **Apple Silicon Mac** running macOS Sonoma, Sequoia, or later.
* **Heroic Games Launcher**: Installed from [heroicgameslauncher.com](https://heroicgameslauncher.com).
* **Base GPTK Runner in Heroic**:
  * In Heroic, open **Wine Manager** (Wine icon on left).
  * Download the latest GPTK version available (e.g., **`Game-Porting-Toolkit-3.0-3`**).
* **GPTK 4.0 Beta 3 DMG**:
  * Download **Evaluation environment for Windows games 4.0 beta 3** from [Apple Developer Downloads](https://developer.apple.com/download/all/).
  * Double-click the DMG to mount it (mounts at `/Volumes/Evaluation environment for Windows games 4.0 beta 3`).
* **Winetricks**:
  * Install via Homebrew: `brew install winetricks`  
  *(Or use the Winetricks tool built directly into Heroic's UI)*.

---

## Quick Start (Automated Script)

From this folder, simply run the automated installer:

```bash
cd ~/Code/heroic-gtpk4.0-b2
chmod +x install_gptk4_heroic.sh patch_gptk.py
./install_gptk4_heroic.sh
```

The script automatically:
1. Detects your mounted GPTK 4.0 Beta 3 volume.
2. Finds your existing GPTK runner in Heroic and clones it to `GPTK-4.0-Beta`.
3. Patches the 6 GPTK 4.0 Windows DLLs for ABI compatibility.
4. Mirrors the volume's `redist/lib` (`external/D3DMetal.framework`, `external/libd3dshared.dylib`, unix stubs, DLLs) into the runner's `wine/lib`, then overlays the patched DLLs.

---

## Manual Step-by-Step Instructions

### 1. Clone your Base GPTK Runner
```bash
cd "$HOME/Library/Application Support/Heroic/tools/game-porting-toolkit"
cp -R "Game-Porting-Toolkit-3.0-3" GPTK-4.0-Beta
```
*(Always clone an existing GPTK runner rather than creating an empty folder so Wine binaries and Apple's Rosetta `%gs` context handlers are preserved)*.

### 2. Binary-Patch the GPTK 4.0 DLLs
*(Fixes `STATUS_DLL_INIT_FAILED` / `c0000142` Wine 7.7 ABI incompatibility)*

Run the included patcher:
```bash
cd ~/Code/heroic-gtpk4.0-b2
python3 patch_gptk.py --dmg "/Volumes/Evaluation environment for Windows games 4.0 beta 3" --out "./patched_dlls"
```

### 3. Inject GPTK 4.0 Files into the Runner
```bash
VOLUME="/Volumes/Evaluation environment for Windows games 4.0 beta 3"
RUNNER="$HOME/Library/Application Support/Heroic/tools/game-porting-toolkit/GPTK-4.0-Beta"
WINE_LIB="$RUNNER/Contents/Resources/wine/lib"

# Mirror Apple's redist layout (external/D3DMetal.framework, libd3dshared.dylib, unix stubs, DLLs)
rm -rf "$WINE_LIB/external/D3DMetal.framework"
ditto "$VOLUME/redist/lib" "$WINE_LIB"

# Overlay patched Windows DLLs
cp ./patched_dlls/*.dll "$WINE_LIB/wine/x86_64-windows/"
cp ./patched_dlls/nvngx-on-metalfx.dll "$WINE_LIB/wine/x86_64-windows/nvngx.dll"
```

---

## Heroic Game Configuration

1. **Quit Heroic completely** (`Cmd + Q`) and reopen it.
2. Go to your game's **Settings (gear icon) > Wine**.
3. Under **Wine Version**, select:
   ```text
   GPTK-4.0-Beta
   ```
4. Scroll down to **Environment Variables** and add:
   | Variable | Value | Description |
   | :--- | :--- | :--- |
   | `ROSETTA_ADVERTISE_AVX` | `1` | Enables AVX translation in Rosetta 2 |
   | `D3DM_ENABLE_METALFX` | `1` | Enables DLSS -> MetalFX translation |
   | `D3DM_SUPPORT_DXR` | `1` | Enables DirectX Raytracing (DXR) |
   | `D3DM_MTL4` | `1` | Activates Metal 4 pipeline optimizations |
   | `WINEDLLOVERRIDES` | `d3dcompiler_47=n,b` | Forces native Microsoft shader compiler |

---

## Unreal Engine 5 Fix (Slate Shader Crash)

Unreal Engine 5 games crash on startup if using Wine's built-in `d3dcompiler_47.dll`. To fix:
* In Heroic, click on your game $\rightarrow$ **Winetricks** $\rightarrow$ install **`d3dcompiler_47`**.  
* *(Or via CLI)*:
  ```bash
  WINEPREFIX="/path/to/game/prefix" winetricks d3dcompiler_47
  ```
