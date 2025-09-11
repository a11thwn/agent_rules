#!/usr/bin/env bash
set -e
echo "[CLEAN] 清理缓存与依赖..."
rm -rf node_modules dist .venv build
