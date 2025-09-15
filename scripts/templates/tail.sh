#!/usr/bin/env bash
set -e
N=${N:-200}
PATTERN=${PATTERN:-.}
LOGFILE=${1:-logs/app.log}
echo "[TAIL] 打印 ${LOGFILE} 最后 ${N} 行，过滤模式：${PATTERN}"
tail -n "$N" -f "$LOGFILE" | grep --line-buffered -E "$PATTERN"
