#!/usr/bin/env bash
# Host side of the two-network tests (README "Two-network tests"). No simulated latency.
# Usage: bash run_remote.sh pack           # build dist/spike-client.zip for the client PC
#        bash run_remote.sh move|drift     # start the server, then run client.bat on the client PC
# Env: N clients (6), TICK (60), UPNP=0 to skip the router port-mapping attempt.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
N="${N:-6}"
TICK="${TICK:-60}"
UPNP="${UPNP:-1}"
mkdir -p logs results

case "${1:-}" in
	pack)
		rm -rf dist/spike-client && mkdir -p dist/spike-client
		cp main.gd main.tscn project.godot client.bat "$GODOT" "${GODOT%_console.exe}.exe" dist/spike-client/
		rm -f dist/spike-client.zip
		# Windows tar: -a picks zip from the name. Git Bash's tar writes a tar regardless.
		(cd dist && /c/Windows/System32/tar.exe -a -cf spike-client.zip spike-client)
		ls -l dist/spike-client.zip
		;;
	move|drift)
		dur=60
		[ "$1" = drift ] && dur=540
		tag="wan-$1-t$TICK"
		echo "== $tag: waiting up to 10 min for $N clients (client.bat <host-ip> $1 $N)"
		"$GODOT" --headless --path . -- --role=server --mode=move --tick="$TICK" --duration="$dur" \
			--expected="$N" --upnp="$UPNP" --wait=600 --tag="$tag" 2>&1 | tee "logs/$tag-server.log"
		[ -f "results/$tag.json" ] && echo "result: results/$tag.json" || echo "!! no result (see logs/$tag-server.log)"
		;;
	*) echo "usage: bash run_remote.sh pack|move|drift"; exit 1 ;;
esac
