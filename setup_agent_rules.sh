#!/usr/bin/env bash
set -e

echo "=== [SETUP] 开始配置 Agent Rules 环境 ==="

# 1. 确保项目根目录存在
mkdir -p scripts/templats
mkdir -p .vscode

# 2. 拷贝 ../agent_rules 下的规则文件
if [ -d "../agent_rules" ]; then
  echo "[COPY] 从 ../agent_rules 拷贝规则文件到项目根目录"
  cp ../agent_rules/*.md ./ || true
  cp ../agent_rules/.prettierrc ./ || true
  cp ../agent_rules/.prettierignore ./ || true
  cp ../agent_rules/.vscode/*.json ./.vscode/ || true
  cp ../agent_rules/scripts/*.sh ./scripts/templates/ || true
else
  echo "⚠️ 未找到 ../agent_rules 目录，请确认路径"
fi

# 3. 生成 .editorconfig
cat > .editorconfig <<'EOF'
# EditorConfig is awesome: https://editorconfig.org
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 2
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
max_line_length = 120

# Vue 文件配置
[*.vue]
indent_style = space
indent_size = 2

# TypeScript/JavaScript 文件配置
[*.{ts,js,tsx,jsx}]
indent_style = space
indent_size = 2

# JSON 文件配置
[*.json]
indent_style = space
indent_size = 2

# CSS/SCSS 文件配置
[*.{css,scss,sass}]
indent_style = space
indent_size = 2

# Markdown 文件配置
[*.md]
trim_trailing_whitespace = false
indent_style = space
indent_size = 2

# YAML 文件配置
[*.{yml,yaml}]
indent_style = space
indent_size = 2

# Shell 脚本配置
[*.sh]
indent_style = space
indent_size = 2
EOF
echo "[GEN] .editorconfig 已生成"

# 4. 生成 pre-commit 钩子
HOOK_DIR=".git/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_FILE" <<'EOF'
#!/usr/bin/env bash
echo "[PRE-COMMIT] 开始检查..."

# 1. 运行 ESLint（如果存在）
if command -v eslint >/dev/null 2>&1; then
  npx eslint . || exit 1
fi

# 2. 运行 Prettier 格式化检查
if command -v prettier >/dev/null 2>&1; then
  npx prettier --check . || exit 1
fi

# 3. 运行 Python Black 格式检查
if command -v black >/dev/null 2>&1; then
  black --check . || exit 1
fi

# 4. 检查是否包含 console.log 或 print
if git diff --cached --name-only | grep -E '\.js$|\.ts$|\.py$' >/dev/null; then
  if git diff --cached | grep -E "console\.log|print\("; then
    echo "❌ 提交中包含 console.log 或 print 调试语句"
    exit 1
  fi
fi

echo "[PRE-COMMIT] 检查通过 ✅"
EOF

chmod +x "$HOOK_FILE"
echo "[GEN] pre-commit 钩子已生成并赋予执行权限"

echo "=== [SETUP] 完成 ✅ ==="
