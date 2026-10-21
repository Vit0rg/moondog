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
    --target=*)     TARGET="${arg#*=}" ;;
    --manifest=*)   MANIFEST="${arg#*=}" ;;
    --output=*)     OUTPUT="${arg#*=}" ;;
    --embed-rules)  EMBED_RULES=true ;;
    *)              echo "[WARN] Unknown argument: $arg" ;;
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
        echo "        Build outputs must go to 'build/cli/' to prevent source corruption."
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

# FIX 1: '|| [ -n "$line" ]' preserves a final manifest line that lacks a
# trailing newline. Without it, the last entry (src/main.lua) was silently dropped.
while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$line" ] || [[ "$line" == \#* ]]; then continue; fi

  # [SAFETY NET: MANIFEST FILTERING]
  # FIX 3: CLI builds must strip BOTH the renderer and the LOVE entrypoint,
  # otherwise love.* callbacks leak into the headless payload.
  if [ "$TARGET" == "cli" ]; then
    # Strip LOVE-specific UI / Renderer
    if [[ "$line" == *"love_ui"* || "$line" == *"renderer.lua"* ]]; then
      echo "[STRIP] Excluding LOVE UI/Renderer from CLI payload: $line"
      continue
    fi
    # Strip the LOVE entrypoint (any main.lua that is not the CLI entrypoint)
    if [[ "$line" == *"main.lua" && "$line" != *"cli_main.lua" ]]; then
      echo "[STRIP] Excluding LOVE entrypoint from CLI payload: $line"
      continue
    fi
  fi

  # If this is a LOVE build, strip CLI-specific entry points or pure CLI tools.
  if [ "$TARGET" == "love" ] && [[ "$line" == *"cli_main.lua"* || "$line" == *"cli_runner.lua"* ]]; then
    echo "[STRIP] Excluding CLI entry point from LOVE payload: $line"
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
  echo "" >> "$OUTPUT"
  CONCAT_COUNT=$((CONCAT_COUNT + 1))
done < "$MANIFEST"

if [ "$CONCAT_COUNT" -eq 0 ]; then
  echo "[FATAL] No files were concatenated. Check your manifest: $MANIFEST"
  exit 1
fi

# --- Post-Concatenation Environment Initialization ---
if [ "$TARGET" == "love" ]; then
  echo "" >> "$OUTPUT"
  echo "-- [BUILD-TIME OVERRIDE] LOVE Environment Initialization" >> "$OUTPUT"
  echo "_G.ctx = _G.ctx or {}" >> "$OUTPUT"
  echo "ctx.is_love = true" >> "$OUTPUT"
fi

# --- Post-Build Validation (Fail Loudly) ---
# A successful concatenation is not the same as a functional artifact.
# Assert that the required entrypoint actually landed in the output.
if [ "$TARGET" == "love" ]; then
  if ! grep -q "function love.draw" "$OUTPUT"; then
    echo "[FATAL] Validation failed: 'function love.draw' not found in $OUTPUT."
    echo "        The LOVE entrypoint was dropped or does not define love.draw."
    echo "        Ensure $MANIFEST lists src/main.lua."
    exit 1
  fi
fi

if [ "$TARGET" == "cli" ]; then
  if ! grep -q "function ctx.cli_run" "$OUTPUT"; then
    echo "[FATAL] Validation failed: 'function ctx.cli_run' not found in $OUTPUT."
    echo "        The CLI entrypoint was dropped or cli_runner.lua is missing."
    echo "        Ensure $MANIFEST lists src/cli_runner.lua."
    exit 1
  fi
fi

# --- CLI Bootstrap Injection ---
# Single entry point: delegate to ctx.cli_run and propagate exit code.
# No legacy scan-at-load. No moondog facade calls. One report per invocation.
if [ "$TARGET" == "cli" ]; then
  echo "" >> "$OUTPUT"
  echo "-- [BUILD-TIME OVERRIDE] CLI Environment Initialization" >> "$OUTPUT"
  echo "_G.ctx = _G.ctx or {}" >> "$OUTPUT"
  echo "ctx.is_cli = true" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
  echo "-- CLI entry: delegate to ctx.cli_run (src/cli_runner.lua)." >> "$OUTPUT"
  echo "-- Exit codes: 0 clean | 1 critical/fatal smells | 2 usage/IO error." >> "$OUTPUT"
  echo "local cli_exit_code = 2" >> "$OUTPUT"
  echo "if ctx and ctx.cli_run then" >> "$OUTPUT"
  echo "    cli_exit_code = ctx.cli_run(arg or {})" >> "$OUTPUT"
  echo "else" >> "$OUTPUT"
  echo "    io.stderr:write('moondog: fatal: ctx.cli_run missing (cli_runner.lua not in manifest)\\n')" >> "$OUTPUT"
  echo "end" >> "$OUTPUT"
  echo "os.exit(cli_exit_code)" >> "$OUTPUT"
fi

echo "======================================================"
echo " SUCCESS: $TARGET build generated at $OUTPUT ($CONCAT_COUNT files)"
echo "======================================================"