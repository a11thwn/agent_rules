#!/usr/bin/env bash
set -euo pipefail

# 说明：生成 all-in-one 脚本 init_agent_rules.sh。
# 目的：把仓库需要的文本文件内嵌到单文件脚本中，便于 wget/curl 一键初始化。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OUT_FILE="$REPO_ROOT/init_agent_rules.sh"

# 输出 INFO 日志
log_info() { echo "[INFO] $*"; }
# 输出 WARN 日志
log_warn() { echo "[WARN] $*" >&2; }
# 输出 ERROR 日志
log_error() { echo "[ERROR] $*" >&2; }

# 打印错误并退出
fail() {
  log_error "$*"
  exit 1
}

# 计算字符串的 sha256（用于生成 heredoc 分隔符）
sha256_str() {
  local s="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf "%s" "$s" | shasum -a 256 | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    printf "%s" "$s" | sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    printf "%s" "$s" | openssl dgst -sha256 | awk '{print $2}'
    return 0
  fi
  fail "缺少 sha256 工具（shasum/sha256sum/openssl 任一即可）"
}

# 生成不冲突的 heredoc 分隔符
make_delim() {
  local rel="$1"
  local abs="$2"
  local base
  base="$(sha256_str "$rel" | cut -c1-12)"
  local delim="__AR_EOF_${base}__"
  while grep -F "$delim" "$abs" >/dev/null 2>&1; do
    delim="${delim}X"
  done
  echo "$delim"
}

# 收集需要内嵌的文件列表（相对 REPO_ROOT）
collect_files() {
  local -a files=()

  # 顶层文件（文本）
  files+=("AGENTS.md")
  files+=("Debugging-Rules.md")
  files+=("CHANGELOG.md")
  files+=("README.md")
  files+=("PACKING.md")
  files+=(".editorconfig")
  files+=(".gitignore")
  files+=(".prettierrc")
  files+=(".prettierignore")

  # VS Code 配置（文本）
  if [ -d "$REPO_ROOT/.vscode" ]; then
    while IFS= read -r -d '' f; do
      files+=("${f#"$REPO_ROOT/"}")
    done < <(find "$REPO_ROOT/.vscode" -maxdepth 1 -type f -name "*.json" -print0)
  fi

  # 工作区上下文（文本）
  if [ -d "$REPO_ROOT/.context" ]; then
    while IFS= read -r -d '' f; do
      files+=("${f#"$REPO_ROOT/"}")
    done < <(find "$REPO_ROOT/.context" -maxdepth 1 -type f -name "*.md" -print0)
  fi

  # 工作流模板（文本）
  if [ -d "$REPO_ROOT/.agent/workflows" ]; then
    while IFS= read -r -d '' f; do
      files+=("${f#"$REPO_ROOT/"}")
    done < <(find "$REPO_ROOT/.agent/workflows" -maxdepth 1 -type f -name "*.md" -print0)
  fi

  # 脚本模板（文本）
  if [ -d "$REPO_ROOT/scripts/templates" ]; then
    while IFS= read -r -d '' f; do
      files+=("${f#"$REPO_ROOT/"}")
    done < <(find "$REPO_ROOT/scripts/templates" -maxdepth 1 -type f -name "*.sh" -print0)
  fi

  # 生成器自身也纳入复原（可选，但利于复现）
  if [ -d "$REPO_ROOT/tools" ]; then
    while IFS= read -r -d '' f; do
      case "${f#"$REPO_ROOT/"}" in
        "tools/build_init.sh") files+=("tools/build_init.sh") ;;
      esac
    done < <(find "$REPO_ROOT/tools" -maxdepth 1 -type f -name "*.sh" -print0)
  fi

  # setup 脚本内容会被内嵌（但 init 默认不写出该文件）
  files+=("setup_agent_rules.sh")

  printf "%s\n" "${files[@]}" | LC_ALL=C sort -u
}

# 写入 init 脚本头部
write_header() {
  cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

## init_agent_rules.sh
## 说明：Antigravity（优先）/ Cursor（兼容）规则一键初始化脚本（all-in-one）。
## 用法：
##   wget -O init_agent_rules.sh <raw-url> && bash init_agent_rules.sh
##   curl -fsSL <raw-url> | bash -s -- --verify

ROOT_DIR="$(pwd)"
FORCE="0"
DRY_RUN="0"
SYNC_CURSOR="1"
VERIFY="0"
MANIFEST="0"
NO_SKILLS="0"

# 输出 INFO 日志
log_info() { echo "[INFO] $*"; }
# 输出 WARN 日志
log_warn() { echo "[WARN] $*" >&2; }
# 输出 ERROR 日志
log_error() { echo "[ERROR] $*" >&2; }

# 打印帮助信息
usage() {
  cat <<'USAGE'
用法：
  bash init_agent_rules.sh [--dir <path>] [--force] [--no-cursor] [--no-skills] [--dry-run] [--verify] [--manifest] [--help]

参数：
  --dir <path>     指定输出/安装目录（默认：当前目录）
  --force          允许覆盖已存在文件（不备份）
  --no-cursor      不同步到 .cursor/rules/
  --no-skills      不安装 Awesome Skills
  --dry-run        只打印将创建/覆盖/跳过的清单，不实际写入
  --verify         执行后做一次自检并输出结果
  --manifest       生成 MANIFEST.txt 与 MANIFEST.sha256（可选）
  --help           显示帮助
USAGE
}

# 打印错误并退出
fail() {
  log_error "$*"
  exit 1
}

# 取目录绝对路径（解析符号链接）
abs_dir() {
  (cd "$1" >/dev/null 2>&1 && pwd -P)
}

# 取路径“尽力而为”的绝对路径（用于日志与安全前缀校验）
abs_path() {
  local path="$1"
  if [ -d "$path" ]; then
    abs_dir "$path"
    return 0
  fi
  local parent
  parent="$(dirname "$path")"
  local base
  base="$(basename "$path")"
  local abs_parent=""
  abs_parent="$(abs_dir "$parent" || true)"
  if [ -n "$abs_parent" ]; then
    echo "$abs_parent/$base"
    return 0
  fi
  echo "$path"
}

# 生成时间戳（用于备份目录）
timestamp() {
  date "+%Y%m%d-%H%M%S"
}

# 计算文件 sha256（用于 MANIFEST.sha256）
sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $2}'
    return 0
  fi
  return 1
}

# 写文件（从 stdin 读取），支持 dry-run/force，并保证不写出 ROOT_DIR 之外
write_file() {
  local rel="$1"
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"

  case "$rel" in
    /*) fail "安全保护：仅允许相对路径：$rel" ;;
    *".."*) fail "安全保护：路径包含 ..，拒绝写入：$rel" ;;
  esac

  local dest="$abs_root/$rel"
  local abs_dest
  abs_dest="$(abs_path "$dest")"
  case "$abs_dest" in
    "$abs_root"/*) ;;
    *) fail "安全保护：目标不在输出目录内，拒绝写入：$rel" ;;
  esac

  if [ -e "$dest" ] && [ "$FORCE" != "1" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      log_warn "[DRY-RUN] 将跳过（已存在）：${rel}"
    else
      log_warn "已存在且默认不覆盖：${rel}（可用 --force 覆盖）"
    fi
    cat >/dev/null
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    if [ -e "$dest" ]; then
      log_info "[DRY-RUN] 将覆盖：${rel}"
    else
      log_info "[DRY-RUN] 将创建：${rel}"
    fi
    cat >/dev/null
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cat >"$dest"
  log_info "已写入：${rel}"
}

# 解析命令行参数
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)
        shift
        [ $# -gt 0 ] || fail "--dir 需要一个路径"
        ROOT_DIR="$1"
        ;;
      --force)
        FORCE="1"
        ;;
      --no-cursor)
        SYNC_CURSOR="0"
        ;;
      --no-skills)
        NO_SKILLS="1"
        ;;
      --dry-run)
        DRY_RUN="1"
        ;;
      --verify)
        VERIFY="1"
        ;;
      --manifest)
        MANIFEST="1"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        fail "未知参数：$1（使用 --help 查看用法）"
        ;;
    esac
    shift
  done
}

# 写出仓库文件（内嵌内容）
emit_repo_files() {
EOF
}

# 写入 init 脚本尾部（安装/同步/校验）
write_footer() {
  cat <<'EOF'
}

# 设置脚本可执行权限（scripts/templates 与 tools 下的 .sh）
chmod_execs() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将设置可执行权限：scripts/templates/*.sh tools/*.sh（如存在）"
    return 0
  fi
  if [ -d "$abs_root/scripts/templates" ]; then
    find "$abs_root/scripts/templates" -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  fi
  if [ -d "$abs_root/tools" ]; then
    find "$abs_root/tools" -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  fi
}

# 生成 pre-commit 钩子内容（不强依赖全局 eslint/black；优先项目自带脚本与 uv）
gen_pre_commit_hook() {
  cat <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail

# 输出 INFO 日志
log_info() { echo "[INFO] $*"; }
# 输出 WARN 日志
log_warn() { echo "[WARN] $*" >&2; }
# 输出 ERROR 日志
log_error() { echo "[ERROR] $*" >&2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  log_warn "未检测到 Git 仓库根目录，跳过 pre-commit。"
  exit 0
fi
cd "$ROOT"

log_info "pre-commit 检查开始"

if git diff --cached --name-only | grep -E '\.(js|jsx|ts|tsx|py)$' >/dev/null 2>&1; then
  if git diff --cached -U0 --no-color \
    | grep -E '^\+' \
    | grep -Ev '^\+\+\+' \
    | grep -E 'console\.log\(|\bdebugger\b|print\(|pdb\.set_trace\(' >/dev/null 2>&1; then
    log_error "提交包含调试语句（console.log / debugger / print / pdb.set_trace）。"
    log_error "建议：删除或使用正式日志替代。"
    exit 1
  fi
fi

# 检测包管理器（优先匹配 lock 文件）
detect_pm() {
  if [ -f "pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1; then echo "pnpm"; return 0; fi
  if [ -f "yarn.lock" ] && command -v yarn >/dev/null 2>&1; then echo "yarn"; return 0; fi
  if command -v npm >/dev/null 2>&1; then echo "npm"; return 0; fi
  return 1
}

# 判断 package.json 是否存在指定脚本
has_pkg_script() {
  local name="$1"
  command -v node >/dev/null 2>&1 || return 1
  [ -f package.json ] || return 1
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));process.exit(p.scripts&&p.scripts['$name']?0:1)"
}

# 运行项目自带的前端检查脚本（不强依赖全局 eslint）
run_node_checks() {
  [ -f package.json ] || return 0
  local pm
  pm="$(detect_pm || true)"
  if [ -z "$pm" ]; then
    log_warn "检测到 package.json 但缺少包管理器（npm/pnpm/yarn），跳过前端检查。"
    return 0
  fi

  if has_pkg_script "lint"; then
    log_info "运行：$pm run lint"
    "$pm" run -s lint
  else
    log_info "未配置 lint 脚本，跳过。"
  fi

  if has_pkg_script "typecheck"; then
    log_info "运行：$pm run typecheck"
    "$pm" run -s typecheck
  fi

  if has_pkg_script "format:check"; then
    log_info "运行：$pm run format:check"
    "$pm" run -s format:check
  fi
}

# 运行 Python 检查：优先 uv run，其次系统命令
run_python_checks() {
  [ -f pyproject.toml ] || return 0

  local has_ruff="0"
  local has_black="0"
  if grep -E '^\[tool\.ruff\]' -n pyproject.toml >/dev/null 2>&1; then has_ruff="1"; fi
  if grep -E '^\[tool\.black\]' -n pyproject.toml >/dev/null 2>&1; then has_black="1"; fi

  if [ "$has_ruff" = "0" ] && [ "$has_black" = "0" ]; then
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    if [ "$has_ruff" = "1" ]; then
      log_info "运行：uv run ruff check ."
      uv run ruff check .
    fi
    if [ "$has_black" = "1" ]; then
      log_info "运行：uv run black --check ."
      uv run black --check .
    fi
    return 0
  fi

  log_warn "未检测到 uv，尝试使用系统命令（如已安装）。"
  if [ "$has_ruff" = "1" ] && command -v ruff >/dev/null 2>&1; then
    log_info "运行：ruff check ."
    ruff check .
  fi
  if [ "$has_black" = "1" ] && command -v black >/dev/null 2>&1; then
    log_info "运行：black --check ."
    black --check .
  fi
}

run_node_checks
run_python_checks

log_info "pre-commit 检查通过"
HOOK
}

# 安装到 .agent/rules/*.mdc，并可选同步到 .cursor/rules/*.mdc
install_rules() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"

  local agent_dir="$abs_root/.agent/rules"
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将确保目录存在：.agent/rules/"
  else
    mkdir -p "$agent_dir"
  fi

  if [ -f "$abs_root/AGENTS.md" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      log_info "[DRY-RUN] 将安装规则：.agent/rules/AGENTS.mdc"
    else
      write_file ".agent/rules/AGENTS.mdc" < "$abs_root/AGENTS.md"
    fi
  fi

  if [ -f "$abs_root/Debugging-Rules.md" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      log_info "[DRY-RUN] 将安装规则：.agent/rules/Debugging-Rules.mdc"
    else
      write_file ".agent/rules/Debugging-Rules.mdc" < "$abs_root/Debugging-Rules.md"
    fi
  fi

  if [ "$SYNC_CURSOR" = "1" ]; then
    local cursor_dir="$abs_root/.cursor/rules"
    if [ "$DRY_RUN" = "1" ]; then
      log_info "[DRY-RUN] 将同步到：.cursor/rules/"
    else
      mkdir -p "$cursor_dir"
      local f
      for f in "$agent_dir"/*.mdc; do
        [ -f "$f" ] || continue
        write_file ".cursor/rules/$(basename "$f")" < "$f"
      done
    fi
  else
    log_info "已关闭 Cursor 同步（--no-cursor）。"
  fi
}

# 安装 Awesome Skills（可选）
install_agent_skills() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"

  if [ "$NO_SKILLS" = "1" ]; then
    log_info "已关闭技能安装（--no-skills）。"
    return 0
  fi

  local target="$abs_root/.agent/skills"
  local temp_dir="$abs_root/.agent/skills-temp"
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将克隆 Awesome Skills 并扁平化到：$target"
    return 0
  fi

  if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    log_warn "skills 目录非空，跳过安装：$target"
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_warn "缺少 git，跳过 skills 克隆。"
    return 0
  fi

  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi

  mkdir -p "$temp_dir"
  if ! git clone --depth 1 https://github.com/sickn33/antigravity-awesome-skills "$temp_dir"; then
    log_warn "skills 克隆失败，已跳过。"
    rm -rf "$temp_dir"
    return 0
  fi

  mkdir -p "$target"
  if [ -d "$temp_dir/skills" ] && compgen -G "$temp_dir/skills/*" >/dev/null 2>&1; then
    mv "$temp_dir/skills/"* "$target/"
  fi

  if [ -d "$temp_dir/scripts" ]; then
    mv "$temp_dir/scripts" "$target/"
  fi

  if [ -f "$temp_dir/skills_index.json" ]; then
    mv "$temp_dir/skills_index.json" "$target/"
  fi

  if [ -f "$temp_dir/README.md" ]; then
    mv "$temp_dir/README.md" "$target/"
  fi

  rm -rf "$temp_dir"
  log_info "已安装 Awesome Skills（扁平化）：$target"
}

# 安装 pre-commit 钩子（仅当存在 .git/）
install_pre_commit() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"
  if [ ! -d "$abs_root/.git" ]; then
    log_warn "未检测到 .git/，跳过 pre-commit 钩子生成。"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将生成：.git/hooks/pre-commit"
    return 0
  fi

  mkdir -p "$abs_root/.git/hooks"
  gen_pre_commit_hook | write_file ".git/hooks/pre-commit"
  chmod +x "$abs_root/.git/hooks/pre-commit"
  log_info "pre-commit 钩子已生成并可执行：.git/hooks/pre-commit"
}

# 生成 MANIFEST（可选）
write_manifest() {
  if [ "$MANIFEST" != "1" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将生成：MANIFEST.txt / MANIFEST.sha256"
    return 0
  fi

  printf "%s\n" "${EMBEDDED_FILES[@]}" > "$ROOT_DIR/MANIFEST.txt"
  if command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || command -v openssl >/dev/null 2>&1; then
    : > "$ROOT_DIR/MANIFEST.sha256"
    local rel
    while IFS= read -r rel; do
      local abs="$ROOT_DIR/$rel"
      if [ -f "$abs" ]; then
        local sum=""
        sum="$(sha256_file "$abs" || true)"
        if [ -n "$sum" ]; then
          printf "%s  %s\n" "$sum" "$rel" >> "$ROOT_DIR/MANIFEST.sha256"
        fi
      fi
    done < "$ROOT_DIR/MANIFEST.txt"
  else
    log_warn "缺少 sha256 工具，跳过 MANIFEST.sha256。"
  fi
  log_info "已生成：MANIFEST.txt / MANIFEST.sha256"
}

# 自检（可选）
verify_install() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"

  local ok="1"
  local -a must_exist=(
    "AGENTS.md"
    "Debugging-Rules.md"
    ".agent/rules/AGENTS.mdc"
    ".agent/rules/Debugging-Rules.mdc"
    ".context/system_prompt.md"
    ".context/coding_style.md"
    ".agent/workflows/openspec-apply.md"
    ".editorconfig"
    "scripts/templates/dev.sh"
  )

  local p
  for p in "${must_exist[@]}"; do
    if [ -e "$abs_root/$p" ]; then
      log_info "存在：$p"
    else
      ok="0"
      log_error "缺失：$p"
    fi
  done

  if [ "$SYNC_CURSOR" = "1" ]; then
    if [ -e "$abs_root/.cursor/rules/AGENTS.mdc" ]; then
      log_info "存在：.cursor/rules/AGENTS.mdc"
    else
      log_warn "缺失：.cursor/rules/AGENTS.mdc（可能因默认不覆盖或未生成）"
    fi
  fi

  if [ "$NO_SKILLS" != "1" ]; then
    if [ -d "$abs_root/.agent/skills" ]; then
      log_info "存在：.agent/skills/"
    else
      log_warn "缺失：.agent/skills/（可能跳过克隆）"
    fi
  fi

  if [ "$ok" = "1" ]; then
    log_info "自检通过"
  else
    fail "自检失败（可用 --force 覆盖后重试）"
  fi
}

# 默认摘要（非严格校验）
print_summary() {
  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"

  log_info "关键路径摘要："
  local -a paths=(
    "AGENTS.md"
    "Debugging-Rules.md"
    ".agent/rules/"
    ".context/"
    ".agent/workflows/"
    ".cursor/rules/"
    "scripts/templates/"
    ".editorconfig"
    ".vscode/settings.json"
  )

  local p
  for p in "${paths[@]}"; do
    if [ -e "$abs_root/$p" ]; then
      log_info "  - 存在：$p"
    else
      log_warn "  - 缺失：$p"
    fi
  done

  if [ "$NO_SKILLS" = "1" ]; then
    log_info "  - 已跳过：.agent/skills/"
  else
    if [ -d "$abs_root/.agent/skills" ]; then
      log_info "  - 存在：.agent/skills/"
    else
      log_warn "  - 缺失：.agent/skills/"
    fi
  fi

  if [ -d "$abs_root/.git" ]; then
    if [ -f "$abs_root/.git/hooks/pre-commit" ]; then
      log_info "  - 存在：.git/hooks/pre-commit"
    else
      log_warn "  - 缺失：.git/hooks/pre-commit"
    fi
  fi
}

main() {
  parse_args "$@"

  if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$ROOT_DIR"
  fi
  ROOT_DIR="$(abs_dir "$ROOT_DIR")"

  log_info "输出目录：$ROOT_DIR"

  # 可选：落盘日志（不影响 stdout）
  if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$ROOT_DIR/logs" 2>/dev/null || true
  fi

  emit_repo_files
  chmod_execs
  install_rules
  install_agent_skills
  install_pre_commit
  write_manifest

  log_info "初始化完成"
  print_summary

  if [ "$VERIFY" = "1" ]; then
    verify_install
  else
    log_info "可用 --verify 执行自检"
  fi
}

main "$@"
EOF
}

# 生成 init_agent_rules.sh
generate() {
  local -a files=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    files+=("$f")
  done < <(collect_files)

  # 校验文件存在
  local rel
  for rel in "${files[@]}"; do
    [ -f "$REPO_ROOT/$rel" ] || fail "缺少文件：$rel"
  done

  log_info "将内嵌文件数量：${#files[@]}"
  log_info "输出：$OUT_FILE"

  {
    write_header
  } > "$OUT_FILE"

  {
    echo "  EMBEDDED_FILES=("
    for rel in "${files[@]}"; do
      # setup 脚本不写出到磁盘，但仍内嵌其内容
      if [ "$rel" = "setup_agent_rules.sh" ]; then
        continue
      fi
      printf "    %q\n" "$rel"
    done
    echo "  )"
    echo
  } >> "$OUT_FILE"

  # 写出文件内容
  for rel in "${files[@]}"; do
    local abs="$REPO_ROOT/$rel"
    local delim
    delim="$(make_delim "$rel" "$abs")"

    if [ "$rel" = "setup_agent_rules.sh" ]; then
      {
        echo "  # 内嵌 setup_agent_rules.sh（仅用于参考/审计；init 默认不写出该文件）"
        echo "  embedded_setup_agent_rules_sh() {"
        echo "    cat <<'$delim'"
        cat "$abs"
        echo "$delim"
        echo "  }"
        echo
      } >> "$OUT_FILE"
      continue
    fi

    {
      echo "  write_file \"$rel\" <<'$delim'"
      cat "$abs"
      echo "$delim"
      echo
    } >> "$OUT_FILE"
  done

  {
    write_footer
  } >> "$OUT_FILE"

  chmod +x "$OUT_FILE"
  log_info "生成完成：$OUT_FILE"
}

generate
