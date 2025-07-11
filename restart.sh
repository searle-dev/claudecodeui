#!/bin/bash

# Claude Code UI 重启脚本
# 功能：重启前后端服务并记录日志
# 适配认证系统和nginx代理

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 读取环境变量
if [ -f ".env" ]; then
    source .env
    echo "已加载 .env 配置文件"
else
    echo "警告: 未找到 .env 文件，使用默认配置"
fi

# 默认端口配置
BACKEND_PORT=${PORT:-3008}
FRONTEND_PORT=${VITE_PORT:-3009}

# 日志目录
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/app_$(date +%Y%m%d_%H%M%S).log"

# 创建日志目录
mkdir -p $LOG_DIR

# 日志函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 带颜色的输出函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR" "$1"
}

log_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
    log "HEADER" "$1"
}

# 检查进程是否运行
check_process() {
    local port=$1
    local process_name=$2
    
    if command -v ss >/dev/null 2>&1; then
        # 使用 ss 命令 (推荐)
        if ss -ln | grep -q ":$port "; then
            log_info "$process_name 正在端口 $port 上运行"
            return 0
        fi
    elif command -v lsof >/dev/null 2>&1; then
        # 使用 lsof 命令
        if lsof -i :$port >/dev/null 2>&1; then
            log_info "$process_name 正在端口 $port 上运行"
            return 0
        fi
    else
        # 使用 netstat 命令 (最后备选)
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            log_info "$process_name 正在端口 $port 上运行"
            return 0
        fi
    fi
    
    log_warning "$process_name 未在端口 $port 上运行"
    return 1
}

# 获取端口上的进程ID
get_pids_by_port() {
    local port=$1
    local pids=""
    
    if command -v ss >/dev/null 2>&1; then
        # 使用 ss 命令
        pids=$(ss -lntp | grep ":$port " | sed 's/.*pid=\([0-9]*\).*/\1/' | sort -u)
    elif command -v lsof >/dev/null 2>&1; then
        # 使用 lsof 命令
        pids=$(lsof -ti :$port 2>/dev/null)
    fi
    
    echo "$pids"
}

# 停止进程
stop_process() {
    local port=$1
    local process_name=$2
    
    log_info "正在停止 $process_name (端口: $port)..."
    
    # 查找并终止进程
    local pids=$(get_pids_by_port $port)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            if kill -0 $pid 2>/dev/null; then
                log_info "发送 TERM 信号到进程 PID: $pid"
                kill -TERM $pid 2>/dev/null
            fi
        done
        
        # 等待进程优雅退出
        log_info "等待进程优雅退出..."
        sleep 5
        
        # 检查是否还有进程在运行
        pids=$(get_pids_by_port $port)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if kill -0 $pid 2>/dev/null; then
                    log_warning "强制终止进程 PID: $pid"
                    kill -KILL $pid 2>/dev/null
                fi
            done
            sleep 2
        fi
        
        log_success "$process_name 已停止"
    else
        log_info "$process_name 未运行"
    fi
}

# 停止相关的npm进程
stop_npm_processes() {
    log_info "正在停止相关的npm进程..."
    
    # 停止npm run server进程
    local server_pids=$(pgrep -f "npm run server" 2>/dev/null)
    if [ -n "$server_pids" ]; then
        for pid in $server_pids; do
            log_info "停止 npm run server 进程 PID: $pid"
            kill -TERM $pid 2>/dev/null
        done
    fi
    
    # 停止npm run client进程
    local client_pids=$(pgrep -f "npm run client" 2>/dev/null)
    if [ -n "$client_pids" ]; then
        for pid in $client_pids; do
            log_info "停止 npm run client 进程 PID: $pid"
            kill -TERM $pid 2>/dev/null
        done
    fi
    
    # 停止node server/index.js进程
    local node_pids=$(pgrep -f "node server/index.js" 2>/dev/null)
    if [ -n "$node_pids" ]; then
        for pid in $node_pids; do
            log_info "停止 node server/index.js 进程 PID: $pid"
            kill -TERM $pid 2>/dev/null
        done
    fi
    
    # 停止vite进程
    local vite_pids=$(pgrep -f "vite.*--host" 2>/dev/null)
    if [ -n "$vite_pids" ]; then
        for pid in $vite_pids; do
            log_info "停止 vite 进程 PID: $pid"
            kill -TERM $pid 2>/dev/null
        done
    fi
    
    sleep 3
}

# 检查依赖
check_dependencies() {
    log_info "检查项目依赖..."
    
    if [ ! -f "package.json" ]; then
        log_error "未找到 package.json 文件，请在项目根目录运行此脚本"
        exit 1
    fi
    
    if [ ! -d "node_modules" ]; then
        log_warning "未找到 node_modules 目录，正在安装依赖..."
        npm install
        if [ $? -ne 0 ]; then
            log_error "依赖安装失败"
            exit 1
        fi
    fi
    
    # 检查是否需要构建
    if [ ! -d "dist" ] || [ "src" -nt "dist" ]; then
        log_info "正在构建项目..."
        npm run build
        if [ $? -ne 0 ]; then
            log_error "项目构建失败"
            exit 1
        fi
        log_success "项目构建完成"
    fi
}

# 启动后端服务
start_backend() {
    log_info "正在启动后端服务 (端口: $BACKEND_PORT)..."
    
    # 后台启动服务器并记录日志
    nohup npm run server >> "$LOG_FILE" 2>&1 &
    local server_pid=$!
    
    log_info "后端服务已启动，PID: $server_pid"
    
    # 等待服务启动
    local max_wait=30
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        if check_process $BACKEND_PORT "后端服务"; then
            log_success "后端服务启动成功 (端口: $BACKEND_PORT)"
            return 0
        fi
        sleep 1
        wait_count=$((wait_count + 1))
        echo -n "."
    done
    
    echo ""
    log_error "后端服务启动超时"
    return 1
}

# 启动前端服务 (开发模式)
start_frontend() {
    log_info "正在启动前端开发服务 (端口: $FRONTEND_PORT)..."
    
    # 后台启动前端并记录日志
    nohup npm run client >> "$LOG_FILE" 2>&1 &
    local client_pid=$!
    
    log_info "前端服务已启动，PID: $client_pid"
    
    # 等待服务启动
    local max_wait=30
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        if check_process $FRONTEND_PORT "前端服务"; then
            log_success "前端服务启动成功 (端口: $FRONTEND_PORT)"
            return 0
        fi
        sleep 1
        wait_count=$((wait_count + 1))
        echo -n "."
    done
    
    echo ""
    log_error "前端服务启动超时"
    return 1
}

# 检查nginx状态
check_nginx() {
    if command -v nginx >/dev/null 2>&1; then
        if nginx -t >/dev/null 2>&1; then
            log_info "Nginx 配置正常"
            # 重新加载nginx配置
            if nginx -s reload >/dev/null 2>&1; then
                log_success "Nginx 配置已重新加载"
            else
                log_warning "Nginx 重新加载失败，可能需要手动重启"
            fi
        else
            log_error "Nginx 配置有误"
        fi
    else
        log_warning "未检测到 Nginx"
    fi
}

# 显示服务状态
show_status() {
    log_header "==================== 服务状态 ===================="
    
    echo -e "${BLUE}后端服务:${NC}"
    if check_process $BACKEND_PORT "后端服务"; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  地址: http://localhost:$BACKEND_PORT"
    else
        echo -e "  状态: ${RED}未运行${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}前端服务:${NC}"
    if check_process $FRONTEND_PORT "前端服务"; then
        echo -e "  状态: ${GREEN}运行中${NC}"
        echo -e "  地址: http://localhost:$FRONTEND_PORT"
    else
        echo -e "  状态: ${RED}未运行${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}访问地址:${NC}"
    echo -e "  开发模式: http://localhost:$FRONTEND_PORT"
    echo -e "  生产模式: https://ccui.weeklyai.art"
    echo -e "  实时日志: tail -f $LOG_FILE"
    
    if [ -f ".env" ]; then
        echo ""
        echo -e "${BLUE}认证信息:${NC}"
        echo -e "  访问密码: ${ACCESS_PASSWORD:-claude123}"
    fi
    
    log_header "=================================================="
}

# 主函数
main() {
    local mode=${1:-"dev"}
    
    log_header "================ 开始重启 Claude Code UI 服务 ================"
    log_info "日志文件: $LOG_FILE"
    log_info "模式: $mode"
    log_info "后端端口: $BACKEND_PORT"
    log_info "前端端口: $FRONTEND_PORT"
    
    # 检查依赖
    check_dependencies
    
    # 停止现有服务
    log_info "正在停止现有服务..."
    stop_npm_processes
    stop_process $BACKEND_PORT "后端服务"
    stop_process $FRONTEND_PORT "前端服务"
    
    # 等待端口释放
    sleep 3
    
    # 启动后端服务
    if start_backend; then
        log_success "后端服务启动成功"
        
        if [ "$mode" = "dev" ]; then
            # 开发模式：启动前端开发服务器
            if start_frontend; then
                log_success "前端开发服务启动成功"
                check_nginx
                show_status
            else
                log_error "前端服务启动失败"
                exit 1
            fi
        else
            # 生产模式：只启动后端服务（前端已构建到dist目录）
            log_info "生产模式：前端已构建，仅启动后端服务"
            check_nginx
            show_status
        fi
    else
        log_error "后端服务启动失败"
        exit 1
    fi
    
    log_header "================== 重启完成 =================="
}

# 显示帮助信息
show_help() {
    echo "Claude Code UI 重启脚本"
    echo ""
    echo "用法: $0 [mode]"
    echo ""
    echo "模式:"
    echo "  dev  - 开发模式 (启动前后端服务，默认)"
    echo "  prod - 生产模式 (仅启动后端服务)"
    echo ""
    echo "示例:"
    echo "  $0       # 开发模式"
    echo "  $0 dev   # 开发模式"
    echo "  $0 prod  # 生产模式"
    echo ""
    echo "环境变量 (.env 文件):"
    echo "  PORT=${BACKEND_PORT} (后端端口)"
    echo "  VITE_PORT=${FRONTEND_PORT} (前端端口)"
    echo "  ACCESS_PASSWORD=${ACCESS_PASSWORD:-claude123} (访问密码)"
}

# 处理命令行参数
case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    ""|dev|prod)
        # 处理 Ctrl+C 信号
        trap 'log_warning "接收到中断信号，正在清理..."; exit 130' INT
        
        # 运行主函数
        main "$1"
        ;;
    *)
        echo "错误: 未知参数 '$1'"
        echo "使用 '$0 --help' 查看帮助信息"
        exit 1
        ;;
esac