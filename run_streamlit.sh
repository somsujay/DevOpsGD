#!/bin/bash
# run_streamlit.sh — Start/stop/restart Streamlit in background

APP="streamlit_metrics_report.py"
CSV="metrics_out.csv"
PORT=8600
LOG="streamlit.log"
PID_FILE="streamlit.pid"

start() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "⚠️  Already running (PID $(cat $PID_FILE))"
    return
  fi
  echo "🚀 Starting Streamlit on http://localhost:$PORT"
  nohup streamlit run "$APP" \
    --server.port "$PORT" \
    --server.headless true \
    -- "$CSV" \
    > "$LOG" 2>&1 &
  echo $! > "$PID_FILE"
  echo "✅ Started (PID $!). Logs → $LOG"
}

stop() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "⚠️  Not running (no PID file found)"
    return
  fi
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    echo "🛑 Stopped (PID $PID)"
  else
    echo "⚠️  Process $PID not found, cleaning up"
    rm -f "$PID_FILE"
  fi
}

status() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "✅ Running (PID $(cat $PID_FILE)) → http://localhost:$PORT"
  else
    echo "🛑 Not running"
  fi
}

case "$1" in
  start)   start   ;;
  stop)    stop    ;;
  restart) stop; sleep 1; start ;;
  status)  status  ;;
  logs)    tail -f "$LOG" ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
