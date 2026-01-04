#!/bin/bash
# OpenCode 规则安装脚本
# 用于将 opencode_rules 安装到项目根目录

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

DRY_RUN=false
FORCE=false
NO_BACKUP=false
NO_SKILLS=false
NO_TEMPLATES=false
OPENCODE_RULES_DIR=""
PROJECT_ROOT=""

usage() {
    cat << EOF
OpenCode 规则安装脚本

用法：$0 [选项]

选项：
    --dir <path>           指定项目根目录（默认：当前目录）
    --src <path>           指定 opencode_rules 目录（默认：脚本所在目录/opencode_rules）
    --dry-run              仅打印清单，不实际写入
    --force                覆盖已有文件（默认不覆盖）
    --no-backup            覆盖时不备份
    --no-skills            不复制 SKILLS 目录
    --no-templates         不复制脚本模板
    -h, --help             显示帮助信息

示例：
    # 基本安装
    $0

    # 指定项目目录
    $0 --dir /path/to/project

    # 干运行（查看将要安装的文件）
    $0 --dry-run

    # 强制覆盖并跳过备份
    $0 --force --no-backup

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dir)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            --src)
                OPENCODE_RULES_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --no-skills)
                NO_SKILLS=true
                shift
                ;;
            --no-templates)
                NO_TEMPLATES=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "未知选项: $1"
                usage
                ;;
        esac
    done
}

init_paths() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -z "$OPENCODE_RULES_DIR" ]; then
        OPENCODE_RULES_DIR="$SCRIPT_DIR/opencode_rules"
    fi

    if [ -z "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
    fi

    OPENCODE_RULES_DIR="$(cd "$OPENCODE_RULES_DIR" && pwd)"
    PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

    log_info "规则源目录: $OPENCODE_RULES_DIR"
    log_info "项目根目录: $PROJECT_ROOT"
}

validate_env() {
    if [ ! -d "$OPENCODE_RULES_DIR" ]; then
        log_error "找不到 opencode_rules 目录: $OPENCODE_RULES_DIR"
        exit 1
    fi

    if [ ! -f "$OPENCODE_RULES_DIR/AGENTS.md" ]; then
        log_error "opencode_rules/AGENTS.md 不存在"
        exit 1
    fi

    if [ ! -f "$OPENCODE_RULES_DIR/opencode.json" ]; then
        log_error "opencode_rules/opencode.json 不存在"
        exit 1
    fi
}

backup_existing() {
    local file="$1"
    local backup_dir=".backup/$(date +%Y%m%d_%H%M%S)"

    if [ -e "$file" ]; then
        if [ "$NO_BACKUP" = true ]; then
            log_warn "跳过备份（--no-backup）: $file"
        else
            mkdir -p "$backup_dir"
            cp -r "$file" "$backup_dir/"
            log_info "已备份: $file -> $backup_dir/$(basename "$file")"
        fi
    fi
}

copy_file() {
    local src="$1"
    local dest="$2"
    local relative_dest="${dest#$PROJECT_ROOT/}"

    if [ "$DRY_RUN" = true ]; then
        echo "  [复制] $relative_dest"
        return
    fi

    backup_existing "$dest"
    cp "$src" "$dest"
    log_info "已安装: $relative_dest"
}

copy_dir() {
    local src="$1"
    local dest="$2"
    local relative_dest="${dest#$PROJECT_ROOT/}"

    if [ "$DRY_RUN" = true ]; then
        echo "  [复制] $relative_dest/"
        return
    fi

    backup_existing "$dest"
    mkdir -p "$dest"
    cp -r "$src"/* "$dest/"
    log_info "已安装: $relative_dest/"
}

install_rules() {
    log_step "安装 OpenCode 规则文件..."

    copy_file "$OPENCODE_RULES_DIR/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
    copy_file "$OPENCODE_RULES_DIR/opencode.json" "$PROJECT_ROOT/opencode.json"
}

install_skills() {
    if [ "$NO_SKILLS" = true ]; then
        log_warn "跳过 SKILLS 目录（--no-skills）"
        return
    fi

    if [ ! -d "$OPENCODE_RULES_DIR/SKILLS" ]; then
        log_warn "SKILLS 目录不存在，跳过"
        return
    fi

    log_step "安装 Agent Skills..."
    copy_dir "$OPENCODE_RULES_DIR/SKILLS" "$PROJECT_ROOT/SKILLS"
}

install_templates() {
    if [ "$NO_TEMPLATES" = true ]; then
        log_warn "跳过脚本模板（--no-templates）"
        return
    fi

    if [ ! -d "$OPENCODE_RULES_DIR/scripts/templates" ]; then
        log_warn "scripts/templates 目录不存在，跳过"
        return
    fi

    log_step "安装脚本模板..."
    mkdir -p "$PROJECT_ROOT/scripts"
    copy_dir "$OPENCODE_RULES_DIR/scripts/templates" "$PROJECT_ROOT/scripts/templates"
}

verify_install() {
    log_step "验证安装..."

    local required_files=(
        "$PROJECT_ROOT/AGENTS.md"
        "$PROJECT_ROOT/opencode.json"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "验证失败: $(basename "$file") 未安装"
            return 1
        fi
    done

    if command -v python3 &> /dev/null; then
        if ! python3 -m json.tool "$PROJECT_ROOT/opencode.json" > /dev/null 2>&1; then
            log_error "验证失败: opencode.json 语法错误"
            return 1
        fi
    fi

    log_info "✓ 所有必需文件已安装"
    return 0
}

print_next_steps() {
    cat << EOF

${GREEN}✓ OpenCode 规则安装完成！${NC}

${BLUE}下一步：${NC}
1. 在 OpenCode 中打开项目
2. 运行 /opencode config show 验证规则加载
3. 尝试使用 background_task 并行探索

${BLUE}使用示例：${NC}
  请帮我并行探索以下内容：
  1. 查找所有 API 端点
  2. 查找数据库模型
  3. 查找测试文件
  4. 查找配置文件

  使用 background_task 并行启动探索任务。

${BLUE}文件清单：${NC}
  - AGENTS.md              (OpenCode 专用主规则)
  - opencode.json          (OpenCode 配置模板)
EOF

    if [ "$NO_SKILLS" = false ] && [ -d "$OPENCODE_RULES_DIR/SKILLS" ]; then
        echo "  - SKILLS/               (Agent 技能文件)"
    fi

    if [ "$NO_TEMPLATES" = false ] && [ -d "$OPENCODE_RULES_DIR/scripts/templates" ]; then
        echo "  - scripts/templates/     (并行任务脚本模板)"
    fi

    echo ""
    echo "详细说明请参考: opencode_rules/README.md"
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  OpenCode 规则安装脚本${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    parse_args "$@"
    init_paths
    validate_env

    if [ "$DRY_RUN" = true ]; then
        log_warn "=== 干运行模式，仅打印清单 ==="
    fi

    echo ""

    install_rules
    install_skills
    install_templates

    if [ "$DRY_RUN" = false ]; then
        verify_install
        print_next_steps
    fi

    echo -e "${GREEN}✓ 安装完成${NC}"
}

main "$@"
