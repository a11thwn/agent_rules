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
  bash init_agent_rules.sh [--dir <path>] [--force] [--no-cursor] [--dry-run] [--verify] [--manifest] [--help]

参数：
  --dir <path>     指定输出/安装目录（默认：当前目录）
  --force          允许覆盖已存在文件（不备份）
  --no-cursor      不同步到 .cursor/rules/
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
  EMBEDDED_FILES=(
    .editorconfig
    .gitignore
    .prettierignore
    .prettierrc
    .vscode/settings.json
    AGENTS.md
    CHANGELOG.md
    Debugging-Rules.md
    PACKING.md
    README.md
    scripts/templates/build.sh
    scripts/templates/clean.sh
    scripts/templates/debug.sh
    scripts/templates/dev.sh
    scripts/templates/diagnose.sh
    scripts/templates/reset.sh
    scripts/templates/start.sh
    scripts/templates/tail.sh
    scripts/templates/test.sh
    tools/build_init.sh
  )

  write_file ".editorconfig" <<'__AR_EOF_0947e2727d6b__'
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
__AR_EOF_0947e2727d6b__

  write_file ".gitignore" <<'__AR_EOF_bc37d034bad5__'
.DS_Store
.backup/
logs/
.venv/
__pycache__/
*.pyc
node_modules/
dist/
build/
__AR_EOF_bc37d034bad5__

  write_file ".prettierignore" <<'__AR_EOF_b640b344ee7f__'
# Dependencies
node_modules/
.pnpm-store/

# Build outputs
dist/
.output/
.nuxt/
.nitro/

# Logs
logs/
*.log

# Database files
*.db
*.sqlite
*.sqlite3

# Environment files
.env
.env.*

# IDE files
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db

# Package files
*.tar.gz
*.zip

# Backup files
data/backups/
*.backup

# Generated files
coverage/
.nyc_output/

# Lock files
package-lock.json
yarn.lock
pnpm-lock.yaml
__AR_EOF_b640b344ee7f__

  write_file ".prettierrc" <<'__AR_EOF_663ade211b3a__'
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "tabWidth": 2,
  "useTabs": false,
  "printWidth": 120,
  "endOfLine": "lf",
  "bracketSpacing": true,
  "bracketSameLine": false,
  "arrowParens": "avoid",
  "vueIndentScriptAndStyle": false,
  "htmlWhitespaceSensitivity": "ignore"
}
__AR_EOF_663ade211b3a__

  write_file ".vscode/settings.json" <<'__AR_EOF_a5de3e5871ff__'
{
  // 自动保存设置
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 500,

  // 格式化设置
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.formatOnType": false,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.organizeImports": "explicit"
  },

  // 默认格式化器
  "editor.defaultFormatter": "esbenp.prettier-vscode",

  // 文件类型特定格式化器
  "[vue]": {
    "editor.defaultFormatter": "Vue.volar"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[css]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[scss]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[html]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[markdown]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },

  // Prettier 配置
  "prettier.semi": false,
  "prettier.singleQuote": true,
  "prettier.trailingComma": "es5",
  "prettier.tabWidth": 2,
  "prettier.useTabs": false,
  "prettier.printWidth": 120,
  "prettier.endOfLine": "lf",

  // Vue 特定设置
  "vetur.format.defaultFormatter.html": "prettier",
  "vetur.format.defaultFormatter.css": "prettier",
  "vetur.format.defaultFormatter.scss": "prettier",
  "vetur.format.defaultFormatter.js": "prettier",
  "vetur.format.defaultFormatter.ts": "prettier",

  // TypeScript 设置
  "typescript.preferences.importModuleSpecifier": "relative",
  "typescript.suggest.autoImports": true,
  "typescript.updateImportsOnFileMove.enabled": "always",

  // 编辑器设置
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": false,
  "editor.rulers": [120],
  "editor.wordWrap": "wordWrapColumn",
  "editor.wordWrapColumn": 120,

  // 文件设置
  "files.eol": "\n",
  "files.insertFinalNewline": true,
  "files.trimTrailingWhitespace": true,
  "files.trimFinalNewlines": true,

  // 搜索设置
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.nuxt": true,
    "**/.output": true,
    "**/coverage": true
  },

  // 文件监视设置
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/dist/**": true,
    "**/.nuxt/**": true,
    "**/.output/**": true
  },

  // Emmet 设置
  "emmet.includeLanguages": {
    "vue-html": "html",
    "vue": "html"
  },

  // 其他设置
  "editor.minimap.enabled": true,
  "editor.minimap.maxColumn": 120,
  "breadcrumbs.enabled": true,
  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false
}
__AR_EOF_a5de3e5871ff__

  write_file "AGENTS.md" <<'__AR_EOF_a54ff182c7e8__'
# AGENTS.md

## 总则
你是一个出色的高级程序员。你在 Antigravity 中工作时必须遵守本规范；同时保持对 Cursor/VS Code 的兼容。  

- 严格遵循规则，不得越权修改  
- 对外输出（回复/文档/注释/脚本日志）必须使用简体中文  
- 分析/检索/推理过程可使用英文，但最终交付必须中文  
- 调试与排查遵循 `Debugging-Rules.md`，并主动提供可复现的日志/命令  
- 每次修复/优化必须更新 `CHANGELOG.md`（使用当前日期，遵循模板）  
- 脚本模板统一放在 `scripts/templates/`  

---

## 规则加载约定（Antigravity 优先 + Cursor 兼容）
- Antigravity 项目规则目录：`.agent/rules/*.mdc`（自动加载）  
- Cursor/VS Code 兼容目录：`.cursor/rules/*.mdc`（如存在则同步）  

---

## 强护栏（权限边界与破坏性操作）
### 文件系统边界（硬性）
- 禁止在项目根目录之外写入/删除/迁移文件  
- 如必须跨目录操作：先说明影响范围并征求确认，再执行  

### 破坏性操作（必须先征求确认）
- 删除/迁移：`rm`、`mv`、`git clean`、批量替换/重构  
- Git 高风险：`git reset --hard`、`git push -f`、重写历史  
- CI/发布：修改 `.github/`、流水线、发布脚本  
- 依赖与版本：升级/降级依赖、改 lock、改包管理器  

### 终端执行策略（硬性）
- 先 dry-run：先列出匹配项/影响面，再执行实际修改  
- 先小后大：先对单文件/小范围验证，再扩大范围  
- 失败先定位：必须输出关键日志、命令与复现路径  

---

## Communication（对话规范）
- 对外输出必须中文；分析/检索可英文；最终交付中文  
- 解释复杂概念时：先给结论，再分点说明  
✅ 正确：「这是因为……（结论）→ 三个原因如下」  
❌ 错误：「原因有很多，我们先来一步一步分析」  

---

## Documentation（文档规范）
- 编写 `.md` 文档时必须使用中文  
- 正式文档写到 `docs/` 目录下  
- 讨论和评审文档写到 `discuss/` 目录下  
- 文档风格：一段 ≤ 3 句，句子 ≤ 20 字，优先用列表  

✅ 正确：`docs/架构设计.md`  
❌ 错误：`docs/architecture_design.md`  

✅ 正确：`discuss/技术方案评审.md`  
❌ 错误：`docs/技术方案评审.md`  

---

## Code Architecture（代码结构与坏味道）
### 硬性指标
- Python / JavaScript / TypeScript 文件 ≤ 260 行  
- Java / Go / Rust 文件 ≤ 260 行  
- 每层目录 ≤ 8 个文件（不含子目录），多了需拆子目录  

✅ 正确：`user_service.py` 260 行  
❌ 错误：`main.js` 450 行  

✅ 正确：`services/` 下 6 个文件  
❌ 错误：`utils/` 下 20 个文件堆一起  

### 坏味道（必须避免）
1. 僵化：改动困难，牵一发而动全身  
2. 冗余：重复逻辑多处出现  
3. 循环依赖：模块互相缠绕  
4. 脆弱性：改动一处导致其他地方报错  
5. 晦涩性：代码意图不明，难以理解  
6. 数据泥团：多个参数总是成对出现，应封装对象  
7. 不必要的复杂性：过度设计  

【非常重要】  
- 一旦识别坏味道：先提示用户是否需要优化，并给出可落地方案  

---

## 依赖与版本策略（以仓库锁为准）
- 前端：以 `package.json` + lock（`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` 等）为单一真相  
- 后端 Python：以 `pyproject.toml` + lock（例如 `uv.lock` 或项目既有锁）为单一真相  
- 未经用户明确要求：不得升级/降级依赖版本，不得更换包管理器  
- `requirements.txt`：如项目需要，只能由 lock 导出生成；禁止“随手更新”  

---

## HTML（分离关注点）
- 遵循“分离关注点”原则：样式（CSS）、行为（JS）、结构（HTML）必须分离  
- 单个 HTML 文件 ≤ 500 行，功能过多时拆分为组件  

✅ 正确：  
```html
<link rel="stylesheet" href="style.css">
<script src="app.js"></script>
<div class="user-card">张三</div>
```
❌ 错误：  
```html
<div style="color:red;" onclick="alert('hi')">张三</div>
```

---

## Python（uv 优先）
- 数据结构必须强类型；如必须用 `dict`/弱类型结构，需征求用户同意  
- 虚拟环境目录统一为 `.venv`；优先用 `uv venv` 创建并管理  
- 依赖管理必须使用 `uv`；禁止 `pip install`（也不直接使用 `python`/`python3` 执行项目命令）  
- 依赖与锁：以 `pyproject.toml` + lock 为准；`requirements.txt` 仅允许从 lock 导出  
- 根目录保持简洁；`main.py` 保持最小启动逻辑（业务逻辑下沉到模块）  

✅ 正确：  
```python
@dataclass
class User:
    id: int
    name: str
```
❌ 错误：  
```python
user = {"id": 1, "name": "张三"}  # 未定义结构
```

✅ 正确：`uv add requests`  
❌ 错误：`pip install requests`  

✅ 正确：  
```python
if __name__ == "__main__":
    run_app()
```
❌ 错误：在 `main.py` 里写 500 行业务逻辑  

---

## React / Next.js / TypeScript / JavaScript
- 版本以项目 `package.json` 与 lock 为准；未经用户明确要求不得升级/降级  
- 严禁使用 CommonJS（禁止 `require` / `module.exports`）  
- 尽量使用 TypeScript；如必须用 JS，需说明原因  
- 数据结构必须强类型；如必须用 `any` 或未定义结构的 JSON，需征求用户同意  

✅ 正确：`import fs from "fs"`  
❌ 错误：`const fs = require("fs")`  

✅ 正确：  
```ts
interface User {
  id: number
  name: string
}
```
❌ 错误：  
```ts
let user: any = {}
```

---

## Run & Debug（运行与调试）
- 运行/调试/构建脚本必须维护在 `scripts/` 目录下，并通过 `scripts/*.sh` 执行  
- `.sh` 脚本失败：先修复脚本，再继续使用脚本（不要绕开脚本手动跑命令）  
- 调试前配置 Logger：统一输出到 `logs/`；并在输出中包含关键上下文  
- 初始化类脚本（例如 `setup_agent_rules.sh`）用于一次性安装/初始化，不属于日常 Run/Debug 流程  

✅ 正确：`./scripts/run_server.sh`  
❌ 错误：`npm run dev` 或 `python main.py`  

---

## Flutter Widget 树括号封闭规则
在 Widget 树嵌套较深时，必须在封闭括号后添加注释，标明对应的 Widget 名称，便于识别层级。  

✅ 正确示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ), // ElevatedButton
      ],
    ), // Column
  ), // Center
); // Scaffold
```

❌ 错误示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ),
      ],
    ),
  ),
);
```

---

## 开发流程规范
- 分析代码问题可英文；回答与注释必须中文  
- 修复错误必须检查完整链路，并修复关联代码（仅限相关范围）  
- 非本问题范围的改动：必须先征求用户确认  
- 修改后必须输出代码改动对比（例如 `git diff` 关键片段或摘要）  
- 修改需基于上下文（如 @ 引用文件），避免脱离上下文的推断  
- 新增/修改文件、类、函数、方法声明前必须有中文注释  
- 不得私自修改界面样式或配置文件（除非为修复所必需，并说明原因）  
- 如项目需要 `requirements.txt`：必须由 lock 导出生成，禁止手工维护  
- Python 项目运行需确保 `.venv` 已就绪；优先通过 `uv run` 执行命令  

---

## 项目管理规范
- 使用 monocode 架构：功能模块按文件分开，文件开头提供说明，并保持更新  
- 如缺失 `.gitignore`：按需补齐（至少忽略 `.venv/`、`__pycache__/`、`logs/` 等）  
- 项目功能、使用方法、todo-list 必须写入 `README.md`  
- 每次修复问题要记录：原因、解决方案、更改内容  
- 必须在 `CHANGELOG.md` 中记录修复情况，遵循统一模板  

## Monocode 约束
- 源码统一置于 `src/`；按功能（feature）为第一维度拆分目录  
- 每个功能目录内包含：`models/`、`repo/`、`service/`、`api/`、`schemas/`（缺失项按需补全）  
- `service` 不得直接调用外部依赖（DB/HTTP/缓存）；此类依赖只允许在 `repo` 层  
- `shared` 仅存放基础设施与纯工具，禁止业务逻辑  
- 单文件 ≤ 260 行；HTML 单文件 ≤ 500 行；同层 ≤ 8 文件（不含子目录），超限必须拆分  
- 运行/调试/构建仅通过 `scripts/*.sh`  

### 文件/目录数量约束
- 每个目录下的直接文件 ≤ 8 个（不含子目录）  
- 目录层级 ≤ 3 层  
- 目录必须表达明确的功能边界，禁止使用 “misc/、common/、utils/” 作为垃圾桶  
__AR_EOF_a54ff182c7e8__

  write_file "CHANGELOG.md" <<'__AR_EOF_06572a96a58d__'
# CHANGELOG

此文件用于记录项目的所有修改历史，确保每次修复、优化或新增功能都有迹可循。  
请按照以下格式填写：

---

## [2025-12-25 15:21:08] - 前置优化
### 问题描述
- 现有规则与安装脚本偏 Cursor 语境，且安装路径与 Antigravity 最佳实践不一致  
- `setup_agent_rules.sh` 缺少幂等/备份/dry-run/可选 Cursor 同步等能力，难以作为稳定安装器  

### 分析原因
- 规则文本存在不可执行约束（例如“永远用中文思考”）与版本策略硬编码  
- 安装脚本以固定相对路径拷贝（`../agent_rules`），不适合复制到任意项目根目录直接运行  

### 解决方案
- 重写 `AGENTS.md`：以 Antigravity 为主，补齐规则加载约定、强护栏与“以仓库锁为准”的版本策略  
- 重构 `setup_agent_rules.sh`：做成项目内安装器，支持 `--src/--dir/--dry-run/--force/--no-backup/--no-cursor`，并默认安全不覆盖  

### 改动内容
- 修改 `AGENTS.md`：修复矛盾规则；增加 Antigravity 规则目录与 Cursor 同步约定；增加终端/破坏性操作护栏  
- 修改 `setup_agent_rules.sh`：安装到 `.agent/rules/*.mdc`；可选同步 `.cursor/rules/`；覆盖备份到 `.backup/<timestamp>/`；生成 `.editorconfig` 与 `pre-commit`（存在 `.git/` 时）  
- 修改 `Debugging-Rules.md`：标题与表述改为 Antigravity 优先、Cursor 兼容  
- 新增 `README.md`：补齐最简用法说明  
- 新增 `PACKING.md`：列出后续 all-in-one 打包建议范围  

### 影响范围
- 规则安装路径从“项目根目录”迁移为 `.agent/rules/`（并可选同步 `.cursor/rules/`）  
- 执行脚本的默认行为更安全：默认不覆盖，覆盖需 `--force`，且默认备份  

### 后续计划
- 为 `setup_agent_rules.sh` 增加更细的规则来源清单（便于 init 打包自动化）  
- 下一阶段再生成 `init_agent_rules.sh`（all-in-one）  

---

## [2025-12-25 17:17:56] - 生成 init_agent_rules.sh（all-in-one）
### 问题描述
- 需要单文件脚本支持 `wget/curl | bash`，无需 clone/zip 即可复原关键文件并完成规则安装  
- 需要保证幂等、安全、可验证，且兼容 macOS/Linux bash  

### 分析原因
- 仅靠 `setup_agent_rules.sh` 仍需要“先拿到仓库文件”，无法满足一键初始化场景  
- 缺少可复现的打包机制，后续维护容易漂移  

### 解决方案
- 新增 `tools/build_init.sh`：从仓库内容生成 `init_agent_rules.sh`，把需要的文本文件用 heredoc 内嵌  
- 新增 `init_agent_rules.sh`：写出目录结构与文件，并合并安装逻辑（`.agent/rules/*.mdc` + 可选 `.cursor/rules` + `.editorconfig` + `pre-commit`）  

### 改动内容
- 新增 `init_agent_rules.sh`：支持 `--dir/--force/--no-cursor/--dry-run/--verify/--manifest`  
- 新增 `tools/build_init.sh`：一键重新生成 init，保证可复现  
- 更新 `README.md`：补充 wget/curl 一键初始化用法  
- 新增 `.gitignore`：忽略 `.backup/`、`logs/`、`.DS_Store` 等  

### 影响范围
- 增加推荐入口：使用 `init_agent_rules.sh` 可在任意项目中“一次写入 + 安装”  
- 规则安装核心仍以 `.agent/rules/` 为准，并可选同步 Cursor  

### 后续计划
- 扩展 init 的内嵌范围与校验（如新增更多规则文件时自动纳入）  
- 视需要补充更严格的内容一致性校验（按 MANIFEST.sha256 对比）  

## [2025-09-08 15:05:00] - [版本号/提交哈希]
### 问题描述
- 简要说明发现的问题或缺陷  
- 如果有 Issue ID 或任务编号，请写上  

### 分析原因
- 用简洁语言说明问题产生的原因  

### 解决方案
- 描述采取了什么方法修复或优化  

### 改动内容
- 列出修改的文件和主要变更点  
- 建议使用项目内的 `git diff` 输出节选  

### 影响范围
- 说明这次改动可能影响的功能模块或用户行为  

### 后续计划
- 如果需要进一步优化或测试，在这里写上 TODO  

---

## 示例

### [2025-09-04] - v1.0.1
**问题描述**
- 用户登录时偶发 500 错误（Issue #123）  

**分析原因**
- Session 管理逻辑中，未处理空 Token 的异常情况  

**解决方案**
- 在 `auth/session.py` 中添加 Token 校验逻辑  

**改动内容**
- 修改 `auth/session.py`  
- 更新 `tests/test_session.py`  

**影响范围**
- 登录相关接口  
- Session 校验逻辑  

**后续计划**
- 增加更多单元测试覆盖异常情况  
__AR_EOF_06572a96a58d__

  write_file "Debugging-Rules.md" <<'__AR_EOF_cb59ef7d0bbd__'
# Antigravity（优先）/ Cursor（兼容）调试与排查最佳实践

## 一、硬性规则
1. **可复现优先**：所有问题写最小复现 (`scripts/repro.sh`)。
2. **环境锁定**：Node `.nvmrc` / Python `.python-version` / Flutter `tools/.flutter-version`。
3. **Run & Debug 收敛到 `scripts/`**：dev.sh / debug.sh / test.sh / lint.sh / build.sh / start.sh。
4. **日志统一**：等级、落盘、轮转，生产与本地一致。
5. **失败快照**：报错时采集日志/截图/重放脚本。
6. **CI 失败重跑**：归档日志与截图。
7. **一键清理与重置**：`scripts/clean.sh` / `scripts/reset.sh`。

## 二、Antigravity / Cursor 内工作方式
- 问题卡片化（现象→期望→复现→已尝试→下一步）。
- 从断点到根因的最短路径，优先条件断点。
- 日志即断点，统一结构化。
- 对照编译：dev vs prod。
- 小步验证 + 快速回滚。

## 三、排查清单
1. 环境能跑吗？
2. 复现稳定吗？
3. 日志看了吗？
4. 外部依赖稳吗？
5. 构建链路正常吗？
6. 并发与时序？
7. 配置与环境差异？
8. 网络层（DNS/代理/证书）？
9. 资源与性能？
10. 回滚验证。

## 四、各技术栈要点
- **Nuxt/Next**：source map 必开；CORS/代理模拟生产；环境变量统一。
- **Flutter**：Dart/平台侧日志齐全；权限写齐；Crash 上报。
- **Node/Python**：错误边界+trace-id；外部调用封装重试与幂等；docker compose 拉依赖。
- **Nginx/OpenResty**：抓包脚本；SNI/默认站点配置明确。

## 五、工具与模板
- `scripts/diagnose.sh`：系统信息/端口/版本/磁盘。
- `scripts/tail.sh`：可带关键字 tail -f。
- `.editorconfig`：统一缩进/行尾。
- `.githooks/`：提交前 lint/test，禁止 console.log/print 泄漏。

## 六、Agent 协作提示模板
```
你是调试助手。每次只做一件事：定位或验证一个“可观察到的信号”。
输入：现象、期望、复现、已尝试、候选假设。
输出：1) 下一步命令或代码改动（≤10 行），2) 预期观察，3) 若失败的备选路径。
所有命令走 scripts/。
```

## 七、常见坑位速查
- “能在我机上跑”：未锁版本/全局依赖。
- “本地好好的，线上挂”：构建差异/反代错配。
- Flutter 方块字：字体未包含。
- 偶发 5xx：无幂等/重试风暴。
- HTTPS 404：SNI/默认站点错误。

## 八、落地顺序
1. 建 `scripts/` 六件套 + `diagnose.sh`/`tail.sh`。
2. 配置 Cursor Run 面板只跑脚本。
3. 加 `.editorconfig`、`pre-commit`。
4. 写入本文件和 `AGENTS.md`。
5. CI 锁版本、重跑失败、归档日志。
__AR_EOF_cb59ef7d0bbd__

  write_file "PACKING.md" <<'__AR_EOF_197faf93c64f__'
# 打包准备清单（init_agent_rules.sh）

## 目标
后续生成 `init_agent_rules.sh`（all-in-one）。  
要求稳定、可复现、幂等、安全。  

## 建议内嵌范围（包含）
- `setup_agent_rules.sh`  
- `AGENTS.md`  
- `Debugging-Rules.md`  
- `scripts/templates/*.sh`  
- `.prettierrc`、`.prettierignore`（如需要统一格式化约束）  

## 建议排除范围（不包含）
- `.git/`、`.DS_Store`  
- `.backup/`、`logs/`、临时测试目录  
- 任何项目私有配置（例如业务 `.env`）  
__AR_EOF_197faf93c64f__

  write_file "README.md" <<'__AR_EOF_b33563055168__'
## 说明
本仓库用于维护个人 AI 规则与项目初始化脚本。  
Antigravity 优先，兼容 Cursor/VS Code。  

## 最简用法
把 `setup_agent_rules.sh` 复制到任意项目根目录并执行：  
`bash setup_agent_rules.sh`  

## 一键初始化（推荐）
- wget：`wget -O init_agent_rules.sh <raw-url> && bash init_agent_rules.sh --verify`  
- curl：`curl -fsSL <raw-url> | bash -s -- --verify`  

## 维护与生成
- 重新生成 `init_agent_rules.sh`：`bash tools/build_init.sh`  

## 安装结果
- 规则安装到：`.agent/rules/*.mdc`  
- 可选同步到：`.cursor/rules/*.mdc`（默认开启，可用 `--no-cursor` 关闭）  
- 生成：`AGENTS.md`、`.editorconfig`  
- 若存在 `.git/`：生成 `pre-commit` 钩子  
__AR_EOF_b33563055168__

  write_file "scripts/templates/build.sh" <<'__AR_EOF_45b46c36a382__'
#!/usr/bin/env bash
set -e
echo "[BUILD] 构建生产包..."
__AR_EOF_45b46c36a382__

  write_file "scripts/templates/clean.sh" <<'__AR_EOF_71a01bb3e257__'
#!/usr/bin/env bash
set -e
echo "[CLEAN] 清理缓存与依赖..."
rm -rf node_modules dist .venv build
__AR_EOF_71a01bb3e257__

  write_file "scripts/templates/debug.sh" <<'__AR_EOF_1c4bd787aa66__'
#!/usr/bin/env bash
set -e
echo "[DEBUG] 调试模式启动..."
__AR_EOF_1c4bd787aa66__

  write_file "scripts/templates/dev.sh" <<'__AR_EOF_c6cb1027027f__'
#!/usr/bin/env bash
set -e
echo "[DEV] 启动开发环境..."
__AR_EOF_c6cb1027027f__

  write_file "scripts/templates/diagnose.sh" <<'__AR_EOF_e873de7940b7__'
#!/usr/bin/env bash
set -e
echo "[DIAGNOSE] 系统诊断信息"
echo "Node: $(node -v 2>/dev/null || echo 'n/a')"
echo "Python: $(python3 --version 2>/dev/null || echo 'n/a')"
echo "Flutter: $(flutter --version 2>/dev/null | head -n1 || echo 'n/a')"
echo "Ports in use:"
lsof -i -P -n | grep LISTEN
df -h | head -n 5
__AR_EOF_e873de7940b7__

  write_file "scripts/templates/reset.sh" <<'__AR_EOF_77255be797a0__'
#!/usr/bin/env bash
set -e
echo "[RESET] 重置环境并拉起依赖..."
./scripts/clean.sh
__AR_EOF_77255be797a0__

  write_file "scripts/templates/start.sh" <<'__AR_EOF_9bb62c430145__'
#!/usr/bin/env bash
set -e
echo "[START] 启动生产服务..."
__AR_EOF_9bb62c430145__

  write_file "scripts/templates/tail.sh" <<'__AR_EOF_3c79b12c4667__'
#!/usr/bin/env bash
set -e
N=${N:-200}
PATTERN=${PATTERN:-.}
LOGFILE=${1:-logs/app.log}
echo "[TAIL] 打印 ${LOGFILE} 最后 ${N} 行，过滤模式：${PATTERN}"
tail -n "$N" -f "$LOGFILE" | grep --line-buffered -E "$PATTERN"
__AR_EOF_3c79b12c4667__

  write_file "scripts/templates/test.sh" <<'__AR_EOF_8e99b9799392__'
#!/usr/bin/env bash
set -e
echo "[TEST] 运行测试..."
__AR_EOF_8e99b9799392__

  # 内嵌 setup_agent_rules.sh（仅用于参考/审计；init 默认不写出该文件）
  embedded_setup_agent_rules_sh() {
    cat <<'__AR_EOF_3de447742749__'
#!/usr/bin/env bash
set -euo pipefail

## setup_agent_rules.sh
## 说明：项目内安装器/初始化器（Antigravity 优先 + Cursor 兼容）。
## 用法：把本脚本复制到任意项目根目录执行，即可安装规则到 `.agent/rules/` 并完成基础初始化。
## 提示：一键初始化/可复现打包优先使用 `init_agent_rules.sh`；本脚本保留为开发/调试版入口。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT_DIR="$(pwd)"
SRC_DIR=""
SYNC_CURSOR="1"
FORCE="0"
DRY_RUN="0"
NO_BACKUP="0"

# 临时文件列表（用于退出时清理）
TMP_FILES=()

# 输出 INFO 日志
log_info() { echo "[INFO] $*"; }
# 输出 WARN 日志
log_warn() { echo "[WARN] $*" >&2; }
# 输出 ERROR 日志
log_error() { echo "[ERROR] $*" >&2; }

# 打印帮助信息
usage() {
  cat <<'EOF'
用法：
  ./setup_agent_rules.sh [--dir <path>] [--src <path>] [--no-cursor] [--force] [--no-backup] [--dry-run] [--help]

参数：
  --dir <path>       指定安装到哪个项目根目录（默认：当前目录）
  --src <path>       指定外部规则目录（模式 B）；默认使用脚本同目录（模式 A），找不到则使用内置规则
  --no-cursor        不同步到 .cursor/rules/
  --force            允许覆盖已有文件（默认不覆盖）
  --no-backup        覆盖时不备份（默认覆盖会备份到 .backup/<timestamp>/）
  --dry-run          仅输出将创建/覆盖的清单，不做实际写入
  --help             显示帮助
EOF
}

# 打印错误并退出
fail() {
  log_error "$*"
  exit 1
}

# 校验目录存在
require_dir() {
  local dir="$1"
  [ -d "$dir" ] || fail "目录不存在：$dir"
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

# 备份已存在文件到 .backup/<timestamp>/
backup_existing() {
  local dest="$1"
  local root="$2"
  local ts="$3"
  if [ "$NO_BACKUP" = "1" ]; then
    return 0
  fi
  if [ ! -e "$dest" ]; then
    return 0
  fi

  local abs_root
  abs_root="$(abs_dir "$root")"
  local abs_dest
  abs_dest="$(abs_path "$dest")"

  case "$abs_dest" in
    "$abs_root"/*) ;;
    *)
      fail "安全保护：目标文件不在项目根目录内，拒绝备份/覆盖：$dest"
      ;;
  esac

  local rel="${abs_dest#"$abs_root"/}"
  local backup_path="$abs_root/.backup/$ts/$rel"
  mkdir -p "$(dirname "$backup_path")"
  cp -p "$abs_dest" "$backup_path"
  log_info "已备份：$rel -> .backup/$ts/$rel"
}

# 安装/写入单个文件（默认不覆盖；覆盖时按需备份）
install_file() {
  local src="$1"
  local dest="$2"
  local root="$3"
  local ts="$4"

  local abs_root
  abs_root="$(abs_dir "$root")"

  case "$dest" in
    */../*|*/..|../*|..)
      fail "安全保护：目标路径包含 ..，拒绝写入：$dest"
      ;;
  esac

  local abs_dest
  abs_dest="$(abs_path "$dest")"
  case "$abs_dest" in
    "$abs_root"/*) ;;
    *)
      fail "安全保护：目标文件不在项目根目录内，拒绝写入：$dest"
      ;;
  esac

  if [ -e "$dest" ] && [ "$FORCE" != "1" ]; then
    log_warn "已存在且默认不覆盖：$(abs_path "$dest")（可用 --force 覆盖）"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    if [ -e "$dest" ]; then log_info "[DRY-RUN] 将覆盖：$dest"; else log_info "[DRY-RUN] 将创建：$dest"; fi
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    backup_existing "$dest" "$root" "$ts"
  fi
  cp -p "$src" "$dest"
  log_info "已写入：$dest"
}

# 写入临时文件并返回路径（会自动登记清理）
write_temp_file() {
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  TMP_FILES+=("$tmp")
  echo "$tmp"
}

# 内置 AGENTS.md（当外部来源缺失时使用）
embedded_agents_md() {
  cat <<'EOF'
# AGENTS.md

## 总则
你是一个出色的高级程序员。你在 Antigravity 中工作时必须遵守本规范；同时保持对 Cursor/VS Code 的兼容。  

- 严格遵循规则，不得越权修改  
- 对外输出（回复/文档/注释/脚本日志）必须使用简体中文  
- 分析/检索/推理过程可使用英文，但最终交付必须中文  
- 调试与排查遵循 `Debugging-Rules.md`，并主动提供可复现的日志/命令  
- 每次修复/优化必须更新 `CHANGELOG.md`（使用当前日期，遵循模板）  
- 脚本模板统一放在 `scripts/templates/`  

---

## 规则加载约定（Antigravity 优先 + Cursor 兼容）
- Antigravity 项目规则目录：`.agent/rules/*.mdc`（自动加载）  
- Cursor/VS Code 兼容目录：`.cursor/rules/*.mdc`（如存在则同步）  

---

## 强护栏（权限边界与破坏性操作）
### 文件系统边界（硬性）
- 禁止在项目根目录之外写入/删除/迁移文件  
- 如必须跨目录操作：先说明影响范围并征求确认，再执行  

### 破坏性操作（必须先征求确认）
- 删除/迁移：`rm`、`mv`、`git clean`、批量替换/重构  
- Git 高风险：`git reset --hard`、`git push -f`、重写历史  
- CI/发布：修改 `.github/`、流水线、发布脚本  
- 依赖与版本：升级/降级依赖、改 lock、改包管理器  

### 终端执行策略（硬性）
- 先 dry-run：先列出匹配项/影响面，再执行实际修改  
- 先小后大：先对单文件/小范围验证，再扩大范围  
- 失败先定位：必须输出关键日志、命令与复现路径  

---

## Communication（对话规范）
- 对外输出必须中文；分析/检索可英文；最终交付中文  
- 解释复杂概念时：先给结论，再分点说明  
✅ 正确：「这是因为……（结论）→ 三个原因如下」  
❌ 错误：「原因有很多，我们先来一步一步分析」  

---

## Documentation（文档规范）
- 编写 `.md` 文档时必须使用中文  
- 正式文档写到 `docs/` 目录下  
- 讨论和评审文档写到 `discuss/` 目录下  
- 文档风格：一段 ≤ 3 句，句子 ≤ 20 字，优先用列表  

✅ 正确：`docs/架构设计.md`  
❌ 错误：`docs/architecture_design.md`  

✅ 正确：`discuss/技术方案评审.md`  
❌ 错误：`docs/技术方案评审.md`  

---

## Code Architecture（代码结构与坏味道）
### 硬性指标
- Python / JavaScript / TypeScript 文件 ≤ 260 行  
- Java / Go / Rust 文件 ≤ 260 行  
- 每层目录 ≤ 8 个文件（不含子目录），多了需拆子目录  

✅ 正确：`user_service.py` 260 行  
❌ 错误：`main.js` 450 行  

✅ 正确：`services/` 下 6 个文件  
❌ 错误：`utils/` 下 20 个文件堆一起  

### 坏味道（必须避免）
1. 僵化：改动困难，牵一发而动全身  
2. 冗余：重复逻辑多处出现  
3. 循环依赖：模块互相缠绕  
4. 脆弱性：改动一处导致其他地方报错  
5. 晦涩性：代码意图不明，难以理解  
6. 数据泥团：多个参数总是成对出现，应封装对象  
7. 不必要的复杂性：过度设计  

【非常重要】  
- 一旦识别坏味道：先提示用户是否需要优化，并给出可落地方案  

---

## 依赖与版本策略（以仓库锁为准）
- 前端：以 `package.json` + lock（`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` 等）为单一真相  
- 后端 Python：以 `pyproject.toml` + lock（例如 `uv.lock` 或项目既有锁）为单一真相  
- 未经用户明确要求：不得升级/降级依赖版本，不得更换包管理器  
- `requirements.txt`：如项目需要，只能由 lock 导出生成；禁止“随手更新”  

---

## HTML（分离关注点）
- 遵循“分离关注点”原则：样式（CSS）、行为（JS）、结构（HTML）必须分离  
- 单个 HTML 文件 ≤ 500 行，功能过多时拆分为组件  

✅ 正确：  
```html
<link rel="stylesheet" href="style.css">
<script src="app.js"></script>
<div class="user-card">张三</div>
```
❌ 错误：  
```html
<div style="color:red;" onclick="alert('hi')">张三</div>
```

---

## Python（uv 优先）
- 数据结构必须强类型；如必须用 `dict`/弱类型结构，需征求用户同意  
- 虚拟环境目录统一为 `.venv`；优先用 `uv venv` 创建并管理  
- 依赖管理必须使用 `uv`；禁止 `pip install`（也不直接使用 `python`/`python3` 执行项目命令）  
- 依赖与锁：以 `pyproject.toml` + lock 为准；`requirements.txt` 仅允许从 lock 导出  
- 根目录保持简洁；`main.py` 保持最小启动逻辑（业务逻辑下沉到模块）  

✅ 正确：  
```python
@dataclass
class User:
    id: int
    name: str
```
❌ 错误：  
```python
user = {"id": 1, "name": "张三"}  # 未定义结构
```

✅ 正确：`uv add requests`  
❌ 错误：`pip install requests`  

✅ 正确：  
```python
if __name__ == "__main__":
    run_app()
```
❌ 错误：在 `main.py` 里写 500 行业务逻辑  

---

## React / Next.js / TypeScript / JavaScript
- 版本以项目 `package.json` 与 lock 为准；未经用户明确要求不得升级/降级  
- 严禁使用 CommonJS（禁止 `require` / `module.exports`）  
- 尽量使用 TypeScript；如必须用 JS，需说明原因  
- 数据结构必须强类型；如必须用 `any` 或未定义结构的 JSON，需征求用户同意  

✅ 正确：`import fs from "fs"`  
❌ 错误：`const fs = require("fs")`  

✅ 正确：  
```ts
interface User {
  id: number
  name: string
}
```
❌ 错误：  
```ts
let user: any = {}
```

---

## Run & Debug（运行与调试）
- 运行/调试/构建脚本必须维护在 `scripts/` 目录下，并通过 `scripts/*.sh` 执行  
- `.sh` 脚本失败：先修复脚本，再继续使用脚本（不要绕开脚本手动跑命令）  
- 调试前配置 Logger：统一输出到 `logs/`；并在输出中包含关键上下文  
- 初始化类脚本（例如 `setup_agent_rules.sh`）用于一次性安装/初始化，不属于日常 Run/Debug 流程  

✅ 正确：`./scripts/run_server.sh`  
❌ 错误：`npm run dev` 或 `python main.py`  

---

## Flutter Widget 树括号封闭规则
在 Widget 树嵌套较深时，必须在封闭括号后添加注释，标明对应的 Widget 名称，便于识别层级。  

✅ 正确示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ), // ElevatedButton
      ],
    ), // Column
  ), // Center
); // Scaffold
```

❌ 错误示例：
```dart
return Scaffold(
  body: Center(
    child: Column(
      children: [
        Text("Hello"),
        ElevatedButton(
          onPressed: () {},
          child: Text("Click"),
        ),
      ],
    ),
  ),
);
```

---

## 开发流程规范
- 分析代码问题可英文；回答与注释必须中文  
- 修复错误必须检查完整链路，并修复关联代码（仅限相关范围）  
- 非本问题范围的改动：必须先征求用户确认  
- 修改后必须输出代码改动对比（例如 `git diff` 关键片段或摘要）  
- 修改需基于上下文（如 @ 引用文件），避免脱离上下文的推断  
- 新增/修改文件、类、函数、方法声明前必须有中文注释  
- 不得私自修改界面样式或配置文件（除非为修复所必需，并说明原因）  
- 如项目需要 `requirements.txt`：必须由 lock 导出生成，禁止手工维护  
- Python 项目运行需确保 `.venv` 已就绪；优先通过 `uv run` 执行命令  

---

## 项目管理规范
- 使用 monocode 架构：功能模块按文件分开，文件开头提供说明，并保持更新  
- 如缺失 `.gitignore`：按需补齐（至少忽略 `.venv/`、`__pycache__/`、`logs/` 等）  
- 项目功能、使用方法、todo-list 必须写入 `README.md`  
- 每次修复问题要记录：原因、解决方案、更改内容  
- 必须在 `CHANGELOG.md` 中记录修复情况，遵循统一模板  

## Monocode 约束
- 源码统一置于 `src/`；按功能（feature）为第一维度拆分目录  
- 每个功能目录内包含：`models/`、`repo/`、`service/`、`api/`、`schemas/`（缺失项按需补全）  
- `service` 不得直接调用外部依赖（DB/HTTP/缓存）；此类依赖只允许在 `repo` 层  
- `shared` 仅存放基础设施与纯工具，禁止业务逻辑  
- 单文件 ≤ 260 行；HTML 单文件 ≤ 500 行；同层 ≤ 8 文件（不含子目录），超限必须拆分  
- 运行/调试/构建仅通过 `scripts/*.sh`  

### 文件/目录数量约束
- 每个目录下的直接文件 ≤ 8 个（不含子目录）  
- 目录层级 ≤ 3 层  
- 目录必须表达明确的功能边界，禁止使用 “misc/、common/、utils/” 作为垃圾桶  
EOF
}

# 内置 Debugging-Rules.md（当外部来源缺失时使用）
embedded_debugging_rules_md() {
  cat <<'EOF'
# Antigravity（优先）/ Cursor（兼容）调试与排查最佳实践

## 一、硬性规则
1. **可复现优先**：所有问题写最小复现 (`scripts/repro.sh`)。
2. **环境锁定**：Node `.nvmrc` / Python `.python-version` / Flutter `tools/.flutter-version`。
3. **Run & Debug 收敛到 `scripts/`**：dev.sh / debug.sh / test.sh / lint.sh / build.sh / start.sh。
4. **日志统一**：等级、落盘、轮转，生产与本地一致。
5. **失败快照**：报错时采集日志/截图/重放脚本。
6. **CI 失败重跑**：归档日志与截图。
7. **一键清理与重置**：`scripts/clean.sh` / `scripts/reset.sh`。

## 二、Antigravity / Cursor 内工作方式
- 问题卡片化（现象→期望→复现→已尝试→下一步）。
- 从断点到根因的最短路径，优先条件断点。
- 日志即断点，统一结构化。
- 对照编译：dev vs prod。
- 小步验证 + 快速回滚。

## 三、排查清单
1. 环境能跑吗？
2. 复现稳定吗？
3. 日志看了吗？
4. 外部依赖稳吗？
5. 构建链路正常吗？
6. 并发与时序？
7. 配置与环境差异？
8. 网络层（DNS/代理/证书）？
9. 资源与性能？
10. 回滚验证。
EOF
}

# 生成 .editorconfig 模板
generate_editorconfig() {
  cat <<'EOF'
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
}

# 生成 pre-commit 钩子脚本内容
generate_pre_commit_hook() {
  cat <<'EOF'
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
  if [ -f "pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1; then
    echo "pnpm"
    return 0
  fi
  if [ -f "yarn.lock" ] && command -v yarn >/dev/null 2>&1; then
    echo "yarn"
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    echo "npm"
    return 0
  fi
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
EOF
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
      --src)
        shift
        [ $# -gt 0 ] || fail "--src 需要一个路径"
        SRC_DIR="$1"
        ;;
      --no-cursor)
        SYNC_CURSOR="0"
        ;;
      --force)
        FORCE="1"
        ;;
      --no-backup)
        NO_BACKUP="1"
        ;;
      --dry-run)
        DRY_RUN="1"
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

# 选择规则来源目录（模式 A：脚本同目录/同目录 rules_src；模式 B：--src）
pick_source_dir() {
  if [ -n "$SRC_DIR" ]; then
    echo "$SRC_DIR"
    return 0
  fi
  if [ -d "$SCRIPT_DIR/rules_src" ]; then
    echo "$SCRIPT_DIR/rules_src"
    return 0
  fi
  echo "$SCRIPT_DIR"
}

# 安装规则到 .agent/rules，并可选同步到 .cursor/rules
install_rules() {
  local root="$1"
  local ts="$2"
  local src
  src="$(pick_source_dir)"

  local abs_root
  abs_root="$(abs_dir "$root")"
  require_dir "$abs_root"

  src="$(abs_path "$src")"
  [ -d "$src" ] || fail "规则来源目录不存在：$src"

  log_info "项目根目录：$abs_root"
  log_info "规则来源：$src"

  local agent_rules_dir="$abs_root/.agent/rules"
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将确保目录存在：$agent_rules_dir"
  else
    mkdir -p "$agent_rules_dir"
  fi

  local src_root="$src"
  local src_rules_dir="$src"
  if [ "$(basename "$src")" = "rules_src" ]; then
    src_root="$(dirname "$src")"
    src_rules_dir="$src"
  elif [ -d "$src/rules_src" ]; then
    src_rules_dir="$src/rules_src"
  fi

  local agents_md_src=""
  local debugging_md_src=""
  if [ -f "$src_root/AGENTS.md" ]; then agents_md_src="$src_root/AGENTS.md"; fi
  if [ -f "$src_root/Debugging-Rules.md" ]; then debugging_md_src="$src_root/Debugging-Rules.md"; fi

  if [ -z "$agents_md_src" ] && [ -n "$SRC_DIR" ]; then
    log_warn "在 --src 中未找到 AGENTS.md，将使用内置规则。"
  fi

  local tmp_agents=""
  if [ -n "$agents_md_src" ]; then
    tmp_agents="$agents_md_src"
  else
    tmp_agents="$(embedded_agents_md | write_temp_file)"
  fi
  install_file "$tmp_agents" "$abs_root/AGENTS.md" "$abs_root" "$ts"

  local tmp_debugging=""
  if [ -n "$debugging_md_src" ]; then
    tmp_debugging="$debugging_md_src"
  else
    tmp_debugging="$(embedded_debugging_rules_md | write_temp_file)"
  fi
  install_file "$tmp_debugging" "$abs_root/Debugging-Rules.md" "$abs_root" "$ts"

  install_file "$abs_root/AGENTS.md" "$agent_rules_dir/AGENTS.mdc" "$abs_root" "$ts"
  install_file "$abs_root/Debugging-Rules.md" "$agent_rules_dir/Debugging-Rules.mdc" "$abs_root" "$ts"

  if [ -d "$src_rules_dir" ]; then
    local rule
    while IFS= read -r -d '' rule; do
      local base
      base="$(basename "$rule")"
      case "$base" in
        AGENTS.md|Debugging-Rules.md) continue ;;
      esac
      local dest_name="$base"
      if [[ "$base" == *.md ]]; then dest_name="${base%.md}.mdc"; fi
      install_file "$rule" "$agent_rules_dir/$dest_name" "$abs_root" "$ts"
    done < <(find "$src_rules_dir" -maxdepth 1 -type f \( -name "*.md" -o -name "*.mdc" \) -print0)
  fi

  log_info "规则安装目录就绪：$agent_rules_dir"

  if [ "$SYNC_CURSOR" = "1" ]; then
    local cursor_rules_dir="$abs_root/.cursor/rules"
    if [ "$DRY_RUN" = "1" ]; then
      log_info "[DRY-RUN] 将同步到：$cursor_rules_dir"
    else
      mkdir -p "$cursor_rules_dir"
      local mdc
      for mdc in "$agent_rules_dir"/*.mdc; do
        [ -f "$mdc" ] || continue
        install_file "$mdc" "$cursor_rules_dir/$(basename "$mdc")" "$abs_root" "$ts"
      done
      log_info "已同步到 Cursor 兼容目录：$cursor_rules_dir"
    fi
  else
    log_info "已关闭 Cursor 同步（--no-cursor）。"
  fi
}

# 安装/生成 .editorconfig
install_editorconfig() {
  local root="$1"
  local ts="$2"

  local tmp
  tmp="$(generate_editorconfig | write_temp_file)"
  install_file "$tmp" "$root/.editorconfig" "$root" "$ts"
}

# 安装 scripts/templates/*.sh（如来源存在；默认不覆盖）
install_script_templates() {
  local root="$1"
  local ts="$2"

  local src
  src="$(abs_path "$(pick_source_dir)")"

  local src_root="$src"
  if [ "$(basename "$src")" = "rules_src" ]; then
    src_root="$(dirname "$src")"
  fi

  local templates_src_dir="$src_root/scripts/templates"
  if [ ! -d "$templates_src_dir" ]; then
    log_info "未检测到来源脚本模板目录，跳过：$templates_src_dir"
    return 0
  fi

  log_info "开始安装脚本模板：$templates_src_dir -> $root/scripts/templates/"
  local f
  while IFS= read -r -d '' f; do
    install_file "$f" "$root/scripts/templates/$(basename "$f")" "$root" "$ts"
  done < <(find "$templates_src_dir" -maxdepth 1 -type f -name "*.sh" -print0)
}

# 安装/生成 pre-commit 钩子（仅当存在 .git/）
install_pre_commit() {
  local root="$1"
  local ts="$2"
  local hooks_dir="$root/.git/hooks"
  if [ ! -d "$root/.git" ]; then
    log_warn "未检测到 .git/，跳过 pre-commit 钩子生成。"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log_info "[DRY-RUN] 将生成：$hooks_dir/pre-commit"
    return 0
  fi

  mkdir -p "$hooks_dir"
  local tmp
  tmp="$(generate_pre_commit_hook | write_temp_file)"
  install_file "$tmp" "$hooks_dir/pre-commit" "$root" "$ts"
  chmod +x "$hooks_dir/pre-commit"
  log_info "pre-commit 钩子已生成并可执行：$hooks_dir/pre-commit"
}

# 打印安装结果摘要
print_summary() {
  local root="$1"
  log_info "安装完成（或 dry-run 完成）"
  log_info "规则目录：$root/.agent/rules/"
  if [ "$SYNC_CURSOR" = "1" ]; then
    log_info "Cursor 目录：$root/.cursor/rules/"
  fi

  if [ -f "$root/AGENTS.md" ]; then
    log_info "已存在：$root/AGENTS.md"
  else
    log_warn "缺失：$root/AGENTS.md"
  fi

  if [ -f "$root/.editorconfig" ]; then
    log_info "已存在：$root/.editorconfig"
  else
    log_warn "缺失：$root/.editorconfig"
  fi

  if [ -d "$root/.git" ]; then
    if [ -f "$root/.git/hooks/pre-commit" ]; then
      log_info "已存在：$root/.git/hooks/pre-commit"
    else
      log_warn "缺失：$root/.git/hooks/pre-commit"
    fi
  fi
}

# 主入口
main() {
  # 退出时清理临时文件
  cleanup() {
    if [ "${#TMP_FILES[@]}" -gt 0 ]; then
      rm -f "${TMP_FILES[@]}" 2>/dev/null || true
    fi
  }
  trap cleanup EXIT

  parse_args "$@"

  local abs_root
  abs_root="$(abs_dir "$ROOT_DIR")"
  require_dir "$abs_root"

  local ts
  ts="$(timestamp)"

  log_info "=== setup_agent_rules 开始 ==="
  install_rules "$abs_root" "$ts"
  install_script_templates "$abs_root" "$ts"
  install_editorconfig "$abs_root" "$ts"
  install_pre_commit "$abs_root" "$ts"
  print_summary "$abs_root"
  log_info "=== setup_agent_rules 结束 ==="
}

main "$@"
__AR_EOF_3de447742749__
  }

  write_file "tools/build_init.sh" <<'__AR_EOF_4b394cf8c6fb__'
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
  bash init_agent_rules.sh [--dir <path>] [--force] [--no-cursor] [--dry-run] [--verify] [--manifest] [--help]

参数：
  --dir <path>     指定输出/安装目录（默认：当前目录）
  --force          允许覆盖已存在文件（不备份）
  --no-cursor      不同步到 .cursor/rules/
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
__AR_EOF_4b394cf8c6fb__

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
