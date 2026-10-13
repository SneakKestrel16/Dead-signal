#!/usr/bin/env bash
# Runs the headless ADR verification checks.
# Usage: bash run.sh [adr filter, e.g. 0001]
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p logs
# Class-name fixtures need the global class cache.
"$GODOT" --headless --path . --import > logs/import.log 2>&1
timeout 600 "$GODOT" --headless --path . -s res://run.gd -- "${1:-}" > logs/run.log 2>&1
grep -E "^(ENGINE|RESULT|SUMMARY)" logs/run.log
grep -E "SCRIPT ERROR|Parse Error|ERROR:" logs/run.log | grep -v "expected-error" | head -20
# ADR-0006 (4): the knob digest must match across runs.
if [ -z "${1:-}" ] || [ "${1:-}" = 0006 ]; then
	d1=$(grep -o "DIGEST=[0-9a-f]*" logs/run.log)
	timeout 120 "$GODOT" --headless --path . -s res://run.gd -- 0006 > logs/run-digest.log 2>&1
	d2=$(grep -o "DIGEST=[0-9a-f]*" logs/run-digest.log)
	if [ -n "$d1" ] && [ "$d1" = "$d2" ]; then echo "RESULT 0006-4b PASS digest identical across two runs ($d1)"; else echo "RESULT 0006-4b FAIL digest differs across runs: $d1 vs $d2"; fi
fi
