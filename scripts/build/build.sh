#!/usr/bin/env bash
# ==========================================================
# FILE: scripts/build/build.sh
# PROJECT: moondog (Lua Code-Smell Detector & Anti-Pattern Indicator)
# PURPOSE: Unified H2 / L-DOD Build Pipeline.
# USAGE: ./build.sh --target=<love|cli> [options]
# OPTIONS:
#   --target=<love|cli>      (Required) Target platform.
#   --manifest=<path>        (Optional) Override default manifest.
#   --output=<path>          (Optional) Override default output path.
#   --embed-rules            (Optional) Inject default ruleset directly into the build.
# ==========================================================
set -e

TARGET=""
MANIFEST=""
OUTPUT=""
EMBED_RULES=false
RULES_FILE="src/01_root/03_assets/default_rules.lua"

# --- Argument Parsing ---
for arg in "$@"; do
    case $arg in
        --target=*) TARGET="${arg#*=}" ;;
        --manifest=*) MANIFEST="${arg#*=}" ;;
        --output=*) OUTPUT="${arg#*=}" ;;
        --embed-rules) EMBED_RULES=true ;;
        *) echo "[WARN] Unknown argument: $arg" ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "Usage: $0 --target=<love|cli> [--manifest=<path>] [--output=<path>] [--embed-rules]"
    exit 1
fi

# --- Target Defaults & Configuration ---
case $TARGET in
    love)
        MANIFEST=${MANIFEST:-"scripts/manifests/love_manifest.txt"}
        OUTPUT=${OUTPUT:-"build/love/main.lua"}
        ;;
    cli)
        MANIFEST=${MANIFEST:-"scripts/manifests/cli_manifest.txt"}
        OUTPUT=${OUTPUT:-"build/cli/moondog.lua"}
        # Safety Check: Prevent overwriting source CLI files
        case "$OUTPUT" in
            cli/*|./cli/*)
                echo "[FATAL] Output path '$OUTPUT' is inside the source 'cli/' directory."
                echo "       Build outputs must go to 'build/cli/' to prevent source corruption."
                exit 1
                ;;
        esac
        ;;
    *)
        echo "[FATAL] Unknown target: $TARGET. Must be love or cli."
        exit 1
        ;;
esac

if [ ! -f "$MANIFEST" ]; then
    echo "[FATAL] Manifest not found: $MANIFEST"
    exit 1
fi

# --- Initialization & Headers ---
mkdir -p "$(dirname "$OUTPUT")"
> "$OUTPUT"

echo "-- ==========================================================" >> "$OUTPUT"
echo "-- moondog: Lua Code-Smell Detector & Anti-Pattern Indicator" >> "$OUTPUT"
echo "-- Paradigm: Hack and Harden (H2) / Lexical Data-Oriented Design (L-DOD)" >> "$OUTPUT"
echo "-- Target: $TARGET" >> "$OUTPUT"
echo "-- Built: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT"
echo "-- Manifest: $MANIFEST" >> "$OUTPUT"
echo "-- ==========================================================" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# CLI ANSI Preamble Injection
if [ "$TARGET" == "cli" ]; then
    cat << 'EOF' >> "$OUTPUT"
-- ==========================================================
-- AUTO-GENERATED CLI RUNTIME
-- Standardized ANSI Color Constants injected by Builder
-- ==========================================================
local ANSI_GREEN  = "\27[38;5;46m"
local ANSI_RED    = "\27[38;5;196m"
local ANSI_CYAN   = "\27[38;5;51m"
local ANSI_YELLOW = "\27[38;5;226m"
local ANSI_RESET  = "\27[0m"
local ANSI_DIM    = "\27[2m"
local ANSI_BOLD   = "\27[1m"

EOF
fi

# --- Pre-Concatenation Asset Injection (Embed Rules) ---
if [ "$EMBED_RULES" = true ]; then
    if [ ! -f "$RULES_FILE" ]; then 
        echo "[FATAL] Rules file not found: $RULES_FILE"
        exit 1
    fi
    echo "[INFO] Embedding default ruleset..."
    # Escape closing brackets to prevent premature string termination in Lua long strings
    ESCAPED_RULES=$(sed 's/]]/]] .. "]]" .. [[/g' "$RULES_FILE")
    echo "-- AUTO-GENERATED RULESET INJECTION (--embed-rules)" >> "$OUTPUT"
    if [ "$TARGET" == "cli" ]; then
        echo "local default_ruleset = [[${ESCAPED_RULES}]]" >> "$OUTPUT"
    else
        echo "constants.assets.default_ruleset = [[${ESCAPED_RULES}]]" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"
fi

# --- Manifest Concatenation & Filtering ---
CONCAT_COUNT=0
while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then continue; fi

    # [SAFETY NET: MANIFEST FILTERING]
    # If this is a CLI build, physically refuse to concatenate LÖVE-specific UI/Renderer files.
    if [ "$TARGET" == "cli" ] && [[ "$line" == *"love_ui"* || "$line" == *"renderer.lua"* ]]; then
        echo "[STRIP] Excluding LÖVE-specific UI/Renderer from CLI payload: $line"
        continue
    fi

    # If this is a LÖVE build, strip CLI-specific entry points or pure CLI tools.
    if [ "$TARGET" == "love" ] && [[ "$line" == *"cli_main.lua"* || "$line" == *"cli_runner.lua"* ]]; then
        echo "[STRIP] Excluding CLI entry point from LÖVE payload: $line"
        continue
    fi

    if [ ! -f "$line" ]; then
        echo "[WARN] File not found, skipping: $line"
        continue
    fi

    echo "-- ==========================================" >> "$OUTPUT"
    echo "-- FILE: $line" >> "$OUTPUT"
    echo "-- ==========================================" >> "$OUTPUT"
    cat "$line" >> "$OUTPUT"
    echo -e "\n" >> "$OUTPUT"
    CONCAT_COUNT=$((CONCAT_COUNT + 1))
done < "$MANIFEST"

if [ "$CONCAT_COUNT" -eq 0 ]; then
    echo "[FATAL] No files were concatenated. Check your manifest: $MANIFEST"
    exit 1
fi

# --- Post-Concatenation Overrides ---
# Defensive initialization ensures Phase 1 (Hack) code doesn't crash 
# if the root `ctx` table hasn't been explicitly defined yet.

if [ "$TARGET" == "love" ]; then
    echo "" >> "$OUTPUT"
    echo "-- [BUILD-TIME OVERRIDE] LÖVE Environment Initialization" >> "$OUTPUT"
    echo "_G.ctx = _G.ctx or {}" >> "$OUTPUT"
    echo "ctx.is_love = true" >> "$OUTPUT"
fi

if [ "$TARGET" == "cli" ]; then
    echo "" >> "$OUTPUT"
    echo "-- [BUILD-TIME OVERRIDE] CLI Environment Initialization" >> "$OUTPUT"
    echo "_G.ctx = _G.ctx or {}" >> "$OUTPUT"
    echo "ctx.is_cli = true" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "-- Auto-execute if a file path is provided" >> "$OUTPUT"
    echo "if arg and arg[1] then" >> "$OUTPUT"
    echo "    if moondog and moondog.scan_file then" >> "$OUTPUT"
    echo "        moondog.scan_file(arg[1])" >> "$OUTPUT"
    echo "        if moondog.print_results then moondog.print_results() end" >> "$OUTPUT"
    echo "    else" >> "$OUTPUT"
    echo "        print('Error: moondog module or scan_file function not found.')" >> "$OUTPUT"
    echo "    end" >> "$OUTPUT"
    echo "else" >> "$OUTPUT"
    echo "    print(ANSI_YELLOW .. 'Usage: lua moondog.lua <file.lua>' .. ANSI_RESET)" >> "$OUTPUT"
    echo "end" >> "$OUTPUT"
fi

echo "======================================================"
echo " SUCCESS: $TARGET build generated at $OUTPUT ($CONCAT_COUNT files)"
echo "======================================================"