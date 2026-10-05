#!/usr/bin/env bash
# Start / stop / list the team's long-running processes, detached from any Claude Code session.
#   tools/daemons.sh start [name...]   tools/daemons.sh stop [name...]   tools/daemons.sh status
# Logs in logs/<name>.log, pids in run/<name>.pid. Names: status collector duelmon recorder broker
# (Showcase copy: the team ran ~19 daemons this way; only the ones whose code ships here are listed.)
R="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$R/logs" "$R/run"
cmd_for() {
  case "$1" in
    status)    echo "python3 -u $R/tools/status.py --every 300 --push" ;;
    collector) echo "python3 -u $R/tools/collector.py" ;;
    duelmon)   echo "python3 -u $R/tools/duel_monitor.py --every 15" ;;  # read-only: duel alerts + per-wave review
    recorder)  echo "cd $R && python3 -u -m broker.record_bench --loop" ;;  # read-only: records every Market Test
    broker)    echo "cd $R && python3 -u -m broker.broker --strategy ${BROKER_STRATEGY:-auto_clone}" ;;  # needs BROKER_KEY: only once our own venue is open
    *) return 1 ;;
  esac
}
ALL="status collector duelmon recorder"  # broker: started by hand, once our venue is open
alive() { [ -f "$R/run/$1.pid" ] && kill -0 "$(cat "$R/run/$1.pid")" 2>/dev/null; }
action="$1"; shift
case "$action" in start|stop|status) ;;
  restart) [ $# -gt 0 ] || { echo "restart needs explicit names"; exit 1; }
    "$0" stop "$@"; exec "$0" start "$@" ;;   # env (CASH_FLOOR, MIN_GAIN_SELL, ...) passes through to start
  *) echo "usage: $0 start|stop|restart|status [names]"; exit 1 ;;
esac
if [ "$action" = start ] && [ $# -eq 0 ]; then echo "start needs explicit names: status collector duelmon recorder broker"; exit 1; fi
names="${*:-$ALL}"
for n in $names; do
  case "$action" in
    start)
      if alive "$n"; then echo "$n: already running ($(cat "$R/run/$n.pid"))"; continue; fi
      c="$(cmd_for "$n")" || { echo "$n: unknown"; continue; }
      # supervised: if the process dies (server restart, network), it comes back after 10 s
      (set -a; . "$R/.env"; set +a; nohup bash -c "while true; do $c; echo \"\$(date +%H:%M:%S) exited, restarting\"; sleep 10; done" >> "$R/logs/$n.log" 2>&1 & echo $! > "$R/run/$n.pid")
      echo "$n: started ($(cat "$R/run/$n.pid"))" ;;
    stop)
      if alive "$n"; then pkill -P "$(cat "$R/run/$n.pid")" 2>/dev/null; kill "$(cat "$R/run/$n.pid")" 2>/dev/null; echo "$n: stopped"; else echo "$n: not running"; fi
      rm -f "$R/run/$n.pid" ;;
    status)
      if alive "$n"; then echo "$n: running ($(cat "$R/run/$n.pid")) · last log: $(tail -1 "$R/logs/$n.log" 2>/dev/null | cut -c1-120)"; else echo "$n: DOWN"; fi ;;
  esac
done
