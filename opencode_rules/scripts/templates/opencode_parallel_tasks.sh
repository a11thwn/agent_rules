#!/bin/bash
# OpenCode 并行任务脚本模板
# 用于同时执行多个独立的代码探索或分析任务

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 示例：并行执行多个探索任务
# 在 OpenCode 中使用 background_task 实现真正的并行

# 任务 1：查找所有 API 端点
task_1() {
    log_info "任务 1: 查找 API 端点..."
    find src -name "*.ts" -o -name "*.js" | xargs grep -l "router\|endpoint\|@app\|@router" || true
}

# 任务 2：查找数据库模型
task_2() {
    log_info "任务 2: 查找数据库模型..."
    find src -name "*model*.ts" -o -name "*entity*.ts" -o -name "*schema*.ts" || true
}

# 任务 3：查找测试文件
task_3() {
    log_info "任务 3: 查找测试文件..."
    find . -name "*.test.ts" -o -name "*.spec.ts" -o -name "__tests__" -type d || true
}

# 任务 4：查找配置文件
task_4() {
    log_info "任务 4: 查找配置文件..."
    find . -name "*.config.*" -o -name "*.env.*" -o -name "tsconfig.json" -o -name "package.json" | grep -v node_modules || true
}

# 主函数
main() {
    log_info "开始执行并行任务..."

    # 记录开始时间
    START_TIME=$(date +%s)

    # 并行执行所有任务（在 OpenCode 中使用 background_task 实现真正的并行）
    # 这里使用 & 符号在 shell 中模拟并行
    task_1 &
    PID_1=$!

    task_2 &
    PID_2=$!

    task_3 &
    PID_3=$!

    task_4 &
    PID_4=$!

    # 等待所有任务完成
    wait $PID_1
    wait $PID_2
    wait $PID_3
    wait $PID_4

    # 计算耗时
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    log_info "所有任务完成，耗时 ${DURATION} 秒"
}

# 执行主函数
main "$@"
