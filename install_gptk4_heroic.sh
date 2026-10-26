#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEROIC_TOOLS="$HOME/Library/Application Support/Heroic/tools/game-porting-toolkit"
TARGET_RUNNER="$HEROIC_TOOLS/GPTK-4.0-Beta"
RUNNER_WINE_LIB="$TARGET_RUNNER/Contents/Resources/wine/lib"
RUNNER_WINDOWS_DLLS="$RUNNER_WINE_LIB/wine/x86_64-windows"
PATCHED_DLL_DIR="$SCRIPT_DIR/patched_dlls"
DEFAULT_GPTK_VOLUME="/Volumes/Evaluation environment for Windows games 4.0 beta 3"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}   GPTK 4.0 Beta 3 -> Heroic Wine Runner Installer    ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[!] Error: python3 is not installed or not in PATH.${NC}"
    exit 1
fi

# 2. Check for mounted GPTK volume
echo -e "\n${BLUE}[1/5] Checking for mounted GPTK 4.0 Beta 3 volume...${NC}"
DMG_PATH="$DEFAULT_GPTK_VOLUME"
if [ ! -d "$DMG_PATH" ]; then
    DMG_PATH=$(find /Volumes -maxdepth 1 \( -name "Evaluation environment for Windows games*" -o -name "Game Porting Toolkit*" \) -print -quit 2>/dev/null)
fi

if [ -z "$DMG_PATH" ]; then
    echo -e "${RED}[!] Error: No mounted GPTK volume found in /Volumes.${NC}"
    echo -e "${YELLOW}Mount 'Evaluation environment for Windows games 4.0 beta 3', then re-run this script.${NC}"
    exit 1
fi

WINDOWS_DLLS_SRC="$DMG_PATH/redist/lib/wine/x86_64-windows"
EXTERNAL_LIBS_SRC="$DMG_PATH/redist/lib/external"

if [ ! -f "$WINDOWS_DLLS_SRC/d3d10.dll" ] || [ ! -d "$EXTERNAL_LIBS_SRC/D3DMetal.framework" ] || [ ! -f "$EXTERNAL_LIBS_SRC/libd3dshared.dylib" ]; then
    echo -e "${RED}[!] Error: Unexpected GPTK volume layout at:${NC} $DMG_PATH"
    echo -e "${YELLOW}Expected redist/lib/wine/x86_64-windows and redist/lib/external.${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] Found mounted GPTK volume at:${NC} $DMG_PATH"

# 3. Locate existing Apple GPTK Wine base (prioritizing GPTK-3.0-3)
echo -e "\n${BLUE}[2/5] Locating base Apple GPTK Wine runner in Heroic...${NC}"
BASE_RUNNER=""

# Check for GPTK-3.0-3 first
if [ -d "$HEROIC_TOOLS/GPTK-3.0-3" ]; then
    BASE_RUNNER="$HEROIC_TOOLS/GPTK-3.0-3"
elif [ -d "$HEROIC_TOOLS" ]; then
    for candidate in "$HEROIC_TOOLS"/*GPTK* "$HEROIC_TOOLS"/*gptk* "$HEROIC_TOOLS"/*Game-Porting-Toolkit*; do
        if [ -d "$candidate" ] && [ "$candidate" != "$TARGET_RUNNER" ]; then
            BASE_RUNNER="$candidate"
            break
        fi
    done
fi

# Check Homebrew default location if not in Heroic tools
if [ -z "$BASE_RUNNER" ] && [ -d "/usr/local/opt/game-porting-toolkit" ]; then
    BASE_RUNNER="/usr/local/opt/game-porting-toolkit"
fi

# Fallback: prompt user if not automatically found
if [ -z "$BASE_RUNNER" ]; then
    echo -e "${YELLOW}[?] Could not automatically find an Apple GPTK Wine runner (e.g. GPTK-3.0-3).${NC}"
    echo -e "Enter the path to your Apple GPTK base runner folder:"
    read -r user_base
    if [ -d "$user_base" ]; then
        BASE_RUNNER="$user_base"
    else
        echo -e "${RED}[!] Error: Specified path does not exist.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}[✓] Base runner detected:${NC} $BASE_RUNNER"

# 4. Create GPTK-4.0-Beta runner
echo -e "\n${BLUE}[3/5] Creating dedicated runner 'GPTK-4.0-Beta'...${NC}"
mkdir -p "$HEROIC_TOOLS"

if [ -d "$TARGET_RUNNER" ]; then
    echo -e "${YELLOW}[!] Warning: $TARGET_RUNNER already exists.${NC}"
    read -p "Overwrite existing GPTK-4.0-Beta runner? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TARGET_RUNNER"
        cp -R "$BASE_RUNNER" "$TARGET_RUNNER"
    else
        echo -e "[*] Keeping existing base files, proceeding to update components..."
    fi
else
    cp -R "$BASE_RUNNER" "$TARGET_RUNNER"
fi
echo -e "${GREEN}[✓] Runner structure ready at:${NC} $TARGET_RUNNER"

# 5. Patch GPTK 4.0 Windows DLLs
echo -e "\n${BLUE}[4/5] Patching GPTK 4.0 Windows DLLs for ABI compatibility...${NC}"
python3 "$SCRIPT_DIR/patch_gptk.py" --dmg "$DMG_PATH" --out "$PATCHED_DLL_DIR"

# 6. Copy native frameworks & patched DLLs into the runner
echo -e "\n${BLUE}[5/5] Injecting GPTK 4.0 libraries into runner...${NC}"

# Mirror Apple's redist layout: external/ (D3DMetal, libd3dshared), unix stubs, Windows DLLs
echo "[*] Copying GPTK redist libraries into runner wine/lib..."
rm -rf "$RUNNER_WINE_LIB/external/D3DMetal.framework"
ditto "$DMG_PATH/redist/lib" "$RUNNER_WINE_LIB"

# Overlay patched Windows DLLs
echo "[*] Copying patched PE DLLs to runner windows library directory..."
cp "$PATCHED_DLL_DIR"/*.dll "$RUNNER_WINDOWS_DLLS/"
cp "$PATCHED_DLL_DIR/nvngx-on-metalfx.dll" "$RUNNER_WINDOWS_DLLS/nvngx.dll"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}  ✓ GPTK 4.0 Beta 3 has been successfully installed!  ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "\n${BLUE}How to use in Heroic Games Launcher:${NC}"
echo -e "1. Restart Heroic (Quit with Cmd+Q and relaunch)."
echo -e "2. Go to your game's ${YELLOW}Settings (gear icon) > Wine${NC}."
echo -e "3. Under ${YELLOW}Wine Version${NC}, select: ${GREEN}GPTK-4.0-Beta${NC}"
echo -e "4. In ${YELLOW}Environment Variables${NC}, add the following:"
echo -e "     ${YELLOW}ROSETTA_ADVERTISE_AVX${NC} = 1"
echo -e "     ${YELLOW}D3DM_ENABLE_METALFX${NC}   = 1"
echo -e "     ${YELLOW}D3DM_SUPPORT_DXR${NC}      = 1"
echo -e "     ${YELLOW}D3DM_MTL4${NC}             = 1"
echo -e "     ${YELLOW}WINEDLLOVERRIDES${NC}      = d3dcompiler_47=n,b"
echo -e ""
echo -e "${BLUE}For Unreal Engine 5 titles (Fix Slate Shader Crash):${NC}"
echo -e "Run winetricks on your prefix to install native d3dcompiler_47:"
echo -e "     ${YELLOW}WINEPREFIX=\"<path_to_game_prefix>\" winetricks d3dcompiler_47${NC}"
echo -e "======================================================\n"
