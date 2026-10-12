#!/usr/bin/env bash
# Runs the local (single-machine) spike tests. Latency is simulated in-process.
# Usage: bash run_tests.sh [all|move|vis|auth|smoke]
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DUR="${DUR:-20}"
mkdir -p logs results

g() { "$GODOT" --headless --path . -- "$@"; }

run_move() { # tag tick lat jitter loss clients
	local tag=$1 tick=$2 lat=$3 jit=$4 loss=$5 n=$6
	echo "== move $tag (tick=$tick lat=$lat jitter=$jit loss=$loss clients=$n)"
	g --role=server --mode=move --tick="$tick" --lat="$lat" --jitter="$jit" --loss="$loss" \
		--duration="$DUR" --expected="$n" --tag="$tag" > "logs/$tag-server.log" 2>&1 &
	local spid=$!
	sleep 1
	for i in $(seq 1 "$n"); do
		g --role=client --mode=move --lat="$lat" --jitter="$jit" --loss="$loss" \
			--duration="$DUR" --seed="$i" --tag="$tag-c$i" > "logs/$tag-c$i.log" 2>&1 &
	done
	wait "$spid"
	wait
	grep -h "^RESULT" "logs/$tag-server.log" > /dev/null || echo "!! no RESULT for $tag (see logs/$tag-server.log)"
}

run_vis() {
	echo "== vis"
	g --role=server --mode=vis --duration=30 --tag=vis > logs/vis-server.log 2>&1 &
	local spid=$!
	sleep 1
	g --role=client --mode=vis --duration=20 --tag=vis-A > logs/vis-A.log 2>&1 &
	sleep 0.5
	g --role=client --mode=vis --duration=20 --tag=vis-B > logs/vis-B.log 2>&1 &
	wait "$spid"
	wait
}

run_auth() {
	echo "== auth"
	g --role=server --mode=auth --duration=16 --tag=auth > logs/auth-server.log 2>&1 &
	local spid=$!
	sleep 1
	for i in 1 2 3 4 5 6; do
		extra=""
		[ "$i" = 3 ] && extra="--leave_after=5"
		g --role=client --mode=auth --duration=13 --token="t$i" $extra --tag="auth-t$i" > "logs/auth-t$i.log" 2>&1 &
		sleep 0.2
	done
	sleep 2
	g --role=client --mode=auth --duration=4 --token=t7 --tag=auth-t7-full > logs/auth-t7.log 2>&1 &
	g --role=client --mode=auth --duration=4 --token=tbad --version=spike-0 --tag=auth-badver > logs/auth-badver.log 2>&1 &
	sleep 5
	g --role=client --mode=auth --duration=5 --token=t3 --tag=auth-t3-rejoin > logs/auth-t3-rejoin.log 2>&1 &
	wait "$spid"
	wait
}

what="${1:-all}"
case "$what" in
	smoke) DUR=4 run_move smoke 60 25 5 0 2 ;;
	move|all)
		run_move t60-rtt0    60 0  0  0    6
		run_move t60-rtt50   60 25 5  0    6
		run_move t60-rtt100  60 50 10 0    6
		run_move t60-rtt150  60 75 15 0    6
		run_move t60-rtt150-bad 60 75 30 0.02 6
		run_move t30-rtt100  30 50 10 0    6
		run_move t30-rtt150  30 75 15 0    6
		;;&
	vis|all) [ "$what" = move ] || run_vis ;;&
	auth|all) [ "$what" = move ] || [ "$what" = vis ] || run_auth ;;
esac
echo "done"
