#!/usr/bin/env bash
# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
# Headless round test: host (shapeshifter) runs scenario.gd against two idle bot clients.
# Usage: bash run_test.sh
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p logs
"$GODOT" --headless --path . --import > logs/import.log 2>&1
"$GODOT" --headless --path . -- --host --name=Host --monster=1 --autostart=3 --scenario=full > logs/host.log 2>&1 &
HOST=$!
sleep 2
for n in A B; do
	"$GODOT" --headless --path . -- --join=127.0.0.1 --name=Bot$n --bot=idle > "logs/bot$n.log" 2>&1 &
	sleep 0.5
done
( sleep 150; kill $HOST 2>/dev/null ) &
wait $HOST
code=$?
grep -h "CHECK\|SCENARIO\|ROUND_END\|SCRIPT ERROR\|ERROR" logs/host.log | head -60
for n in A B; do grep -h "SCRIPT ERROR\|ERROR" "logs/bot$n.log" | head -5; done
exit $code
