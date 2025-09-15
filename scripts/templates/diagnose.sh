#!/usr/bin/env bash
set -e
echo "[DIAGNOSE] 系统诊断信息"
echo "Node: $(node -v 2>/dev/null || echo 'n/a')"
echo "Python: $(python3 --version 2>/dev/null || echo 'n/a')"
echo "Flutter: $(flutter --version 2>/dev/null | head -n1 || echo 'n/a')"
echo "Ports in use:"
lsof -i -P -n | grep LISTEN
df -h | head -n 5
