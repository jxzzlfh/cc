#!/bin/bash

# ============================================================
#  Claude Code 一键安装与配置脚本 (交互式菜单版)
#  参考官方文档: https://code.claude.com/docs/zh-CN/setup
# ============================================================

set -e

# ----- 颜色定义 -----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ----- 全局变量 -----
SCRIPT_VERSION="2.2"
SCRIPT_REMOTE_URL="https://cang.zixi.run/claude.sh"
CC_BIN_DIR="$HOME/.local/bin"
CC_BIN_PATH="$CC_BIN_DIR/cc"

OS="$(uname -s)"
IS_WINDOWS=false
IS_MAC=false
IS_LINUX=false
SUDO_CMD=""
INSTALL_METHOD=""  # native / npm / homebrew / winget / unknown

# ----- 工具函数 -----
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║          Claude Code 一键安装配置工具  v${SCRIPT_VERSION}              ║"
    echo "║          https://code.claude.com                         ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_sep() {
    echo -e "${BLUE}──────────────────────────────────────────────────────────${NC}"
}

msg_info()    { echo -e "${CYAN}[信息]${NC} $1"; }
msg_ok()      { echo -e "${GREEN}[完成]${NC} $1"; }
msg_warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
msg_error()   { echo -e "${RED}[错误]${NC} $1"; }
msg_step()    { echo -e "${BOLD}${BLUE}>>> $1${NC}"; }

input_param() {
    local prompt_msg=$1
    local var_name=$2
    local user_input
    read -p "$prompt_msg" user_input < /dev/tty
    eval "$var_name=\"$user_input\""
}

press_enter() {
    echo ""
    read -p "按 Enter 键返回主菜单..." < /dev/tty
}

# ----- 网络检测 -----
check_claude_ai_access() {
    # 尝试访问 claude.ai 安装脚本地址，5 秒超时
    local http_code
    http_code=$(curl -sL -m 5 -o /dev/null -w "%{http_code}" https://claude.ai/install.sh 2>/dev/null)
    if [[ "$http_code" =~ ^(200|301|302|303|307|308)$ ]]; then
        return 0
    else
        return 1
    fi
}

# ----- 环境检测 -----
detect_os() {
    if [[ "$OS" == *"MINGW"* ]] || [[ "$OS" == *"CYGWIN"* ]] || [[ "$OS" == *"MSYS"* ]]; then
        IS_WINDOWS=true
    elif [[ "$OS" == "Darwin" ]]; then
        IS_MAC=true
    else
        IS_LINUX=true
    fi
}

detect_sudo() {
    SUDO_CMD=""
    if [ "$IS_WINDOWS" = false ] && [ "$(id -u)" -ne 0 ]; then
        if command -v sudo &> /dev/null; then
            SUDO_CMD="sudo"
        fi
    fi
}

detect_install_method() {
    INSTALL_METHOD="unknown"

    # 原生安装：二进制在 ~/.local/bin/claude
    if [ -f "$HOME/.local/bin/claude" ]; then
        INSTALL_METHOD="native"
        return
    fi

    # Windows 原生安装
    if [ "$IS_WINDOWS" = true ] && [ -f "$USERPROFILE/.local/bin/claude.exe" ] 2>/dev/null; then
        INSTALL_METHOD="native"
        return
    fi

    # Homebrew 安装
    if command -v brew &> /dev/null && brew list --cask claude-code &> /dev/null; then
        INSTALL_METHOD="homebrew"
        return
    fi

    # WinGet 安装
    if command -v winget &> /dev/null && winget list Anthropic.ClaudeCode &> /dev/null 2>&1; then
        INSTALL_METHOD="winget"
        return
    fi

    # npm 全局安装
    if command -v npm &> /dev/null && npm list -g @anthropic-ai/claude-code &> /dev/null 2>&1; then
        INSTALL_METHOD="npm"
        return
    fi

    # 通过 PATH 检测 claude 命令是否存在
    if command -v claude &> /dev/null; then
        local claude_path
        claude_path=$(command -v claude)
        if [[ "$claude_path" == *"node_modules"* ]] || [[ "$claude_path" == *"npm"* ]]; then
            INSTALL_METHOD="npm"
        else
            INSTALL_METHOD="native"
        fi
        return
    fi

    INSTALL_METHOD="not_installed"
}

get_install_method_label() {
    case "$INSTALL_METHOD" in
        native)        echo "原生安装 (Native)" ;;
        npm)           echo "npm 全局安装" ;;
        homebrew)      echo "Homebrew" ;;
        winget)        echo "WinGet" ;;
        not_installed) echo "未安装" ;;
        *)             echo "未知" ;;
    esac
}

# ----- 状态概览 -----
show_status() {
    print_sep
    echo -e "${BOLD} 当前环境状态${NC}"
    print_sep

    # 系统
    if [ "$IS_WINDOWS" = true ]; then
        echo -e "  系统平台:  ${GREEN}Windows (Git Bash)${NC}"
    elif [ "$IS_MAC" = true ]; then
        echo -e "  系统平台:  ${GREEN}macOS${NC}"
    else
        echo -e "  系统平台:  ${GREEN}Linux${NC}"
    fi

    # Node.js
    if command -v node &> /dev/null; then
        echo -e "  Node.js:   ${GREEN}$(node -v)${NC}"
    else
        echo -e "  Node.js:   ${RED}未安装${NC}"
    fi

    # Claude Code
    detect_install_method
    if [ "$INSTALL_METHOD" != "not_installed" ]; then
        local ver=""
        if command -v claude &> /dev/null; then
            ver=$(claude --version 2>/dev/null || echo "未知版本")
        fi
        echo -e "  Claude Code: ${GREEN}已安装${NC} ($ver)"
        echo -e "  安装方式:  ${CYAN}$(get_install_method_label)${NC}"
    else
        echo -e "  Claude Code: ${RED}未安装${NC}"
    fi

    # 配置文件
    if [ -f "$HOME/.claude/settings.json" ]; then
        echo -e "  配置文件:  ${GREEN}已存在${NC} (~/.claude/settings.json)"
    else
        echo -e "  配置文件:  ${YELLOW}未配置${NC}"
    fi

    # 验证跳过标识
    if [ -f "$HOME/.claude.json" ]; then
        echo -e "  验证跳过:  ${GREEN}已设置${NC}"
    else
        echo -e "  验证跳过:  ${YELLOW}未设置${NC}"
    fi

    # cc 快捷命令
    if [ -f "$CC_BIN_PATH" ] && [ -x "$CC_BIN_PATH" ]; then
        echo -e "  快捷命令:  ${GREEN}已安装${NC} (终端输入 ${BOLD}cc${NC} 启动本面板)"
    else
        echo -e "  快捷命令:  ${YELLOW}未安装${NC} (菜单 9 可设置)"
    fi

    print_sep
}

# ============================================================
#  功能模块
# ============================================================

# ----- 1. 安装环境依赖 -----
menu_install_env() {
    clear
    print_banner
    msg_step "安装环境依赖 (Node.js / Git)"
    print_sep

    # Node.js
    if command -v node &> /dev/null; then
        msg_ok "Node.js 已安装: $(node -v)"
    else
        msg_warn "未检测到 Node.js，开始安装..."
        if [ "$IS_WINDOWS" = true ]; then
            winget install OpenJS.NodeJS -e --source winget
            msg_ok "Node.js 安装完成。请重新打开终端后再运行脚本。"
        elif [ "$IS_MAC" = true ]; then
            if command -v brew &> /dev/null; then
                brew install node
            else
                msg_info "未检测到 Homebrew，使用 NodeSource 安装..."
                curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO_CMD bash -
                $SUDO_CMD apt-get install -y nodejs 2>/dev/null || true
            fi
        else
            if command -v apt-get &> /dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO_CMD bash -
                $SUDO_CMD apt-get install -y nodejs
            elif command -v yum &> /dev/null; then
                curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO_CMD bash -
                $SUDO_CMD yum install -y nodejs
            elif command -v apk &> /dev/null; then
                $SUDO_CMD apk add nodejs npm
            elif command -v pacman &> /dev/null; then
                $SUDO_CMD pacman -S --noconfirm nodejs npm
            else
                msg_error "无法识别包管理器，请手动安装 Node.js 18+。"
            fi
        fi
        if command -v node &> /dev/null; then
            msg_ok "Node.js 安装成功: $(node -v)"
        fi
    fi

    # Git (Windows)
    if [ "$IS_WINDOWS" = true ]; then
        if command -v git &> /dev/null; then
            msg_ok "Git 已安装: $(git --version)"
        else
            msg_warn "Windows 上需要 Git for Windows，正在安装..."
            winget install Git.Git -e --source winget
            msg_ok "Git 安装完成。"
        fi
    fi

    # npm 镜像检测
    msg_info "检测网络区域..."
    if curl -sL -m 3 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -q "loc=CN"; then
        msg_info "检测到中国大陆网络，自动切换 npm 为淘宝镜像源..."
        npm config set registry https://registry.npmmirror.com
        msg_ok "npm 镜像已切换为淘宝源。"
    else
        msg_ok "当前网络位于海外，使用默认 npm 源。"
    fi

    press_enter
}

# ----- 2. 一键安装 Claude Code -----
do_install_native() {
    msg_info "使用原生安装方式..."
    if [ "$IS_WINDOWS" = true ]; then
        msg_info "请在 PowerShell 中运行以下命令完成原生安装:"
        echo -e "  ${YELLOW}irm https://claude.ai/install.ps1 | iex${NC}"
        msg_info "或在 CMD 中运行:"
        echo -e "  ${YELLOW}curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd${NC}"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        msg_ok "Claude Code 原生安装完成！"
    fi
}

do_install_homebrew() {
    if ! command -v brew &> /dev/null; then
        msg_error "未检测到 Homebrew，请先安装 Homebrew: https://brew.sh"
        return 1
    fi
    msg_info "使用 Homebrew 安装..."
    brew install --cask claude-code
    msg_ok "Claude Code Homebrew 安装完成！"
    msg_info "提示: Homebrew 不会自动更新，请定期运行 brew upgrade claude-code"
}

do_install_winget() {
    if ! command -v winget &> /dev/null; then
        msg_error "未检测到 WinGet，请通过 Microsoft Store 安装 App Installer。"
        return 1
    fi
    msg_info "使用 WinGet 安装..."
    winget install Anthropic.ClaudeCode
    msg_ok "Claude Code WinGet 安装完成！"
    msg_info "提示: WinGet 不会自动更新，请定期运行 winget upgrade Anthropic.ClaudeCode"
}

do_install_npm() {
    if ! command -v node &> /dev/null; then
        msg_error "未检测到 Node.js，请先执行「安装环境依赖」(菜单 1)。"
        return 1
    fi
    local node_major
    node_major=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
    if [ -n "$node_major" ] && [ "$node_major" -lt 18 ] 2>/dev/null; then
        msg_error "Node.js 版本过低 (需 18+)，当前: $(node -v)。请先升级 Node.js。"
        return 1
    fi
    msg_info "使用 npm 全局安装..."
    npm install -g @anthropic-ai/claude-code
    msg_ok "Claude Code npm 安装完成！"
}

menu_install() {
    clear
    print_banner
    msg_step "一键安装 Claude Code"
    print_sep

    detect_install_method
    if [ "$INSTALL_METHOD" != "not_installed" ]; then
        msg_warn "检测到已安装 Claude Code ($(get_install_method_label))。"
        input_param "是否继续重新安装？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            press_enter
            return
        fi
    fi

    # 检测 claude.ai 网络可达性
    msg_info "正在检测 claude.ai 网络可达性..."
    local can_access=true
    if check_claude_ai_access; then
        msg_ok "claude.ai 连接正常"
    else
        can_access=false
        echo ""
        msg_warn "无法访问 claude.ai"
        msg_info "原生安装、Homebrew、WinGet 均需要从 claude.ai 下载，可能无法正常使用"
        msg_info "建议使用 npm 安装（从 npm 源下载，无需访问 claude.ai）"
    fi

    # 确定 npm 选项的编号（macOS/Windows 有 Homebrew/WinGet，npm 排第 3；Linux 排第 2）
    local npm_num=2
    if [ "$IS_MAC" = true ] || [ "$IS_WINDOWS" = true ]; then
        npm_num=3
    fi
    local default_choice=1
    if [ "$can_access" = false ]; then
        default_choice=$npm_num
    fi

    echo ""
    echo -e "  ${BOLD}请选择安装方式:${NC}"
    echo ""

    if [ "$can_access" = true ]; then
        echo -e "  ${CYAN}1)${NC} 原生安装 ${GREEN}(推荐，自动更新)${NC}"
        if [ "$IS_MAC" = true ]; then
            echo -e "  ${CYAN}2)${NC} Homebrew 安装"
        fi
        if [ "$IS_WINDOWS" = true ]; then
            echo -e "  ${CYAN}2)${NC} WinGet 安装"
        fi
        echo -e "  ${CYAN}${npm_num})${NC} npm 全局安装 (备选，需 Node.js 18+)"
    else
        echo -e "  ${CYAN}1)${NC} 原生安装 ${YELLOW}(需能访问 claude.ai)${NC}"
        if [ "$IS_MAC" = true ]; then
            echo -e "  ${CYAN}2)${NC} Homebrew 安装 ${YELLOW}(需能访问 claude.ai)${NC}"
        fi
        if [ "$IS_WINDOWS" = true ]; then
            echo -e "  ${CYAN}2)${NC} WinGet 安装 ${YELLOW}(需能访问 claude.ai)${NC}"
        fi
        echo -e "  ${CYAN}${npm_num})${NC} npm 全局安装 ${GREEN}(推荐，从 npm 源安装)${NC}"
    fi
    echo -e "  ${CYAN}0)${NC} 返回"
    echo ""
    input_param "请输入选项 [${default_choice}]: " install_choice
    install_choice=${install_choice:-$default_choice}

    case "$install_choice" in
        1)
            do_install_native
            ;;
        2)
            if [ "$IS_MAC" = true ]; then
                do_install_homebrew
            elif [ "$IS_WINDOWS" = true ]; then
                do_install_winget
            elif [ "$npm_num" = 2 ]; then
                do_install_npm
            else
                msg_error "无效选项。"
            fi
            ;;
        3)
            if [ "$npm_num" = 3 ]; then
                do_install_npm
            else
                msg_error "无效选项。"
            fi
            ;;
        0) return ;;
        *) msg_error "无效选项。" ;;
    esac

    press_enter
}

# ----- 3. 一键配置 -----
menu_config() {
    clear
    print_banner
    msg_step "一键配置 Claude Code"
    print_sep

    echo -e "\n${BOLD}  交互式配置流程（直接回车可跳过选填项）${NC}\n"

    input_param "  [必填] ANTHROPIC_AUTH_TOKEN: " auth_token
    if [ -z "$auth_token" ]; then
        msg_error "AUTH_TOKEN 不能为空！"
        press_enter
        return
    fi

    input_param "  [必填] ANTHROPIC_BASE_URL: " base_url
    if [ -z "$base_url" ]; then
        msg_error "BASE_URL 不能为空！"
        press_enter
        return
    fi

    input_param "  [选填] ANTHROPIC_DEFAULT_OPUS_MODEL: " opus_model
    input_param "  [选填] ANTHROPIC_DEFAULT_SONNET_MODEL: " sonnet_model
    input_param "  [选填] ANTHROPIC_DEFAULT_HAIKU_MODEL: " haiku_model
    input_param "  [选填] CLAUDE_CODE_SUBAGENT_MODEL: " subagent_model
    input_param "  [选填] DISABLE_AUTOUPDATER (1=禁用自动更新): " disable_update

    echo ""
    msg_info "正在生成配置文件..."
    mkdir -p "$HOME/.claude"

    # 构建 env JSON
    local env_entries=""
    env_entries="\"ANTHROPIC_AUTH_TOKEN\": \"$auth_token\""
    env_entries="$env_entries,\n    \"ANTHROPIC_BASE_URL\": \"$base_url\""
    env_entries="$env_entries,\n    \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": 1"

    [ -n "$opus_model" ]     && env_entries="$env_entries,\n    \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"$opus_model\""
    [ -n "$sonnet_model" ]   && env_entries="$env_entries,\n    \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"$sonnet_model\""
    [ -n "$haiku_model" ]    && env_entries="$env_entries,\n    \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"$haiku_model\""
    [ -n "$subagent_model" ] && env_entries="$env_entries,\n    \"CLAUDE_CODE_SUBAGENT_MODEL\": \"$subagent_model\""
    [ "$disable_update" = "1" ] && env_entries="$env_entries,\n    \"DISABLE_AUTOUPDATER\": \"1\""

    printf '{\n  "env": {\n    %b\n  },\n  "permissions": {\n    "allow": [],\n    "deny": []\n  }\n}\n' "$env_entries" > "$HOME/.claude/settings.json"

    msg_ok "settings.json 已生成！"

    # 跳过验证
    msg_info "写入跳过账号验证标识..."
    echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"
    msg_ok "账号验证已跳过！"

    # 展示配置摘要
    echo ""
    print_sep
    echo -e "${BOLD} 配置摘要${NC}"
    print_sep
    echo -e "  AUTH_TOKEN:   ${GREEN}${auth_token:0:8}...${NC} (已隐藏)"
    echo -e "  BASE_URL:     ${GREEN}$base_url${NC}"
    [ -n "$opus_model" ]     && echo -e "  OPUS_MODEL:   ${CYAN}$opus_model${NC}"
    [ -n "$sonnet_model" ]   && echo -e "  SONNET_MODEL: ${CYAN}$sonnet_model${NC}"
    [ -n "$haiku_model" ]    && echo -e "  HAIKU_MODEL:  ${CYAN}$haiku_model${NC}"
    [ -n "$subagent_model" ] && echo -e "  SUBAGENT:     ${CYAN}$subagent_model${NC}"
    echo -e "  配置路径:     ${CYAN}~/.claude/settings.json${NC}"
    print_sep

    press_enter
}

# ----- 4. 一键更新 -----
menu_update() {
    clear
    print_banner
    msg_step "一键更新 Claude Code"
    print_sep

    detect_install_method
    if [ "$INSTALL_METHOD" = "not_installed" ]; then
        msg_error "未检测到 Claude Code 安装，请先执行「一键安装」。"
        press_enter
        return
    fi

    msg_info "当前安装方式: $(get_install_method_label)"
    if command -v claude &> /dev/null; then
        msg_info "当前版本: $(claude --version 2>/dev/null || echo '未知')"
    fi
    echo ""

    case "$INSTALL_METHOD" in
        native)
            msg_info "原生安装支持自动更新，也可手动立即更新..."
            if command -v claude &> /dev/null; then
                claude update
                msg_ok "更新完成！"
            else
                msg_info "重新运行原生安装脚本以更新..."
                if [ "$IS_WINDOWS" = true ]; then
                    msg_info "请在 PowerShell 中执行: irm https://claude.ai/install.ps1 | iex"
                else
                    curl -fsSL https://claude.ai/install.sh | bash
                    msg_ok "更新完成！"
                fi
            fi
            ;;
        npm)
            msg_info "通过 npm 更新..."
            npm install -g @anthropic-ai/claude-code@latest
            msg_ok "npm 更新完成！"
            msg_warn "提示: npm 安装方式已弃用，建议迁移到原生安装。"
            echo -e "  迁移命令: ${YELLOW}curl -fsSL https://claude.ai/install.sh | bash && npm uninstall -g @anthropic-ai/claude-code${NC}"
            ;;
        homebrew)
            msg_info "通过 Homebrew 更新..."
            brew upgrade claude-code
            msg_ok "Homebrew 更新完成！"
            msg_info "清理旧版本缓存..."
            brew cleanup claude-code
            ;;
        winget)
            msg_info "通过 WinGet 更新..."
            winget upgrade Anthropic.ClaudeCode
            msg_ok "WinGet 更新完成！"
            ;;
        *)
            msg_error "无法确定安装方式，请手动更新。"
            ;;
    esac

    if command -v claude &> /dev/null; then
        echo ""
        msg_ok "更新后版本: $(claude --version 2>/dev/null || echo '未知')"
    fi

    press_enter
}

# ----- 5. 一键卸载 -----
menu_uninstall() {
    clear
    print_banner
    msg_step "一键卸载 Claude Code"
    print_sep

    detect_install_method
    if [ "$INSTALL_METHOD" = "not_installed" ]; then
        msg_warn "未检测到 Claude Code 安装。"
        input_param "是否仍要清理残留配置文件？(y/N): " clean_confirm
        if [[ "$clean_confirm" == "y" || "$clean_confirm" == "Y" ]]; then
            clean_config_files
        fi
        press_enter
        return
    fi

    msg_info "检测到安装方式: ${BOLD}$(get_install_method_label)${NC}"
    if command -v claude &> /dev/null; then
        msg_info "当前版本: $(claude --version 2>/dev/null || echo '未知')"
    fi
    echo ""

    echo -e "  ${RED}${BOLD}警告: 卸载将删除 Claude Code 程序。${NC}"
    echo -e "  可选择是否同时清理配置文件和会话数据。"
    echo ""
    input_param "确认卸载 Claude Code？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        msg_info "已取消卸载。"
        press_enter
        return
    fi

    echo ""

    case "$INSTALL_METHOD" in
        native)
            msg_info "卸载原生安装..."
            if [ "$IS_WINDOWS" = true ]; then
                rm -f "$USERPROFILE/.local/bin/claude.exe" 2>/dev/null
                rm -rf "$USERPROFILE/.local/share/claude" 2>/dev/null
            else
                rm -f "$HOME/.local/bin/claude"
                rm -rf "$HOME/.local/share/claude"
            fi
            msg_ok "原生安装已卸载。"
            ;;
        npm)
            msg_info "卸载 npm 全局包..."
            npm uninstall -g @anthropic-ai/claude-code
            msg_ok "npm 包已卸载。"
            ;;
        homebrew)
            msg_info "卸载 Homebrew cask..."
            brew uninstall --cask claude-code
            msg_ok "Homebrew cask 已卸载。"
            ;;
        winget)
            msg_info "卸载 WinGet 包..."
            winget uninstall Anthropic.ClaudeCode
            msg_ok "WinGet 包已卸载。"
            ;;
        *)
            msg_error "无法自动卸载，请手动处理。"
            ;;
    esac

    echo ""
    input_param "是否清理所有配置文件和会话数据？(y/N): " clean_confirm
    if [[ "$clean_confirm" == "y" || "$clean_confirm" == "Y" ]]; then
        clean_config_files
    else
        msg_info "已保留配置文件。"
    fi

    press_enter
}

clean_config_files() {
    msg_info "清理配置文件和会话数据..."

    # 用户级配置
    if [ -d "$HOME/.claude" ]; then
        rm -rf "$HOME/.claude"
        msg_ok "已删除 ~/.claude/"
    fi

    if [ -f "$HOME/.claude.json" ]; then
        rm -f "$HOME/.claude.json"
        msg_ok "已删除 ~/.claude.json"
    fi

    # cc 快捷命令
    if [ -f "$CC_BIN_PATH" ]; then
        rm -f "$CC_BIN_PATH"
        msg_ok "已删除快捷命令 cc"
    fi

    # 项目级配置 (当前目录)
    if [ -d ".claude" ]; then
        input_param "检测到当前目录下的 .claude/ 项目配置，是否一并删除？(y/N): " del_proj
        if [[ "$del_proj" == "y" || "$del_proj" == "Y" ]]; then
            rm -rf .claude
            rm -f .mcp.json
            msg_ok "已删除当前目录的项目级配置。"
        fi
    fi

    msg_ok "配置文件清理完成！"
}

# ----- 6. 查看当前配置 -----
menu_show_config() {
    clear
    print_banner
    msg_step "查看当前配置"
    print_sep

    if [ -f "$HOME/.claude/settings.json" ]; then
        msg_ok "配置文件位置: ~/.claude/settings.json"
        echo ""
        cat "$HOME/.claude/settings.json"
        echo ""
    else
        msg_warn "配置文件不存在 (~/.claude/settings.json)"
    fi

    print_sep

    if [ -f "$HOME/.claude.json" ]; then
        msg_ok "验证标识文件: ~/.claude.json"
        cat "$HOME/.claude.json"
        echo ""
    else
        msg_warn "验证标识文件不存在 (~/.claude.json)"
    fi

    press_enter
}

# ----- 7. npm 迁移到原生安装 -----
menu_migrate_npm() {
    clear
    print_banner
    msg_step "从 npm 迁移到原生安装"
    print_sep

    detect_install_method
    if [ "$INSTALL_METHOD" != "npm" ]; then
        msg_warn "当前安装方式不是 npm ($(get_install_method_label))，无需迁移。"
        press_enter
        return
    fi

    msg_info "当前为 npm 安装方式，官方已弃用 npm 安装。"
    msg_info "原生安装更快，无需额外依赖，且支持后台自动更新。"
    echo ""
    input_param "确认迁移到原生安装？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        msg_info "已取消。"
        press_enter
        return
    fi

    msg_info "步骤 1/2: 安装原生二进制文件..."
    if [ "$IS_WINDOWS" = true ]; then
        msg_info "请在 PowerShell 中执行: irm https://claude.ai/install.ps1 | iex"
        msg_info "然后手动执行: npm uninstall -g @anthropic-ai/claude-code"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        msg_ok "原生安装完成。"

        msg_info "步骤 2/2: 卸载 npm 版本..."
        npm uninstall -g @anthropic-ai/claude-code
        msg_ok "npm 版本已卸载。"

        msg_ok "迁移完成！现在使用原生安装，支持自动更新。"
    fi

    press_enter
}

# ----- 8. 运行诊断 -----
menu_doctor() {
    clear
    print_banner
    msg_step "运行 Claude Code 诊断"
    print_sep

    if ! command -v claude &> /dev/null; then
        msg_error "未检测到 claude 命令，请先安装 Claude Code。"
        press_enter
        return
    fi

    msg_info "运行 claude doctor..."
    echo ""
    claude doctor || true
    echo ""

    press_enter
}

# ----- 9. 设置快捷命令 cc -----
menu_setup_alias() {
    clear
    print_banner
    msg_step "设置快捷命令 cc"
    print_sep

    if [ -f "$CC_BIN_PATH" ] && [ -x "$CC_BIN_PATH" ]; then
        msg_ok "快捷命令已安装: $CC_BIN_PATH"
        echo ""
        echo -e "  ${BOLD}选择操作:${NC}"
        echo -e "  ${CYAN}1)${NC} 更新脚本到最新版"
        echo -e "  ${CYAN}2)${NC} 卸载快捷命令"
        echo -e "  ${CYAN}0)${NC} 返回"
        echo ""
        input_param "请输入选项: " alias_action
        case "$alias_action" in
            1) install_cc_command ;;
            2) uninstall_cc_command ;;
            0) return ;;
            *) msg_error "无效选项。" ;;
        esac
    else
        msg_info "将脚本安装为快捷命令，之后在任意终端输入 ${BOLD}cc${NC} 即可启动本面板。"
        echo ""
        echo -e "  安装位置: ${CYAN}$CC_BIN_PATH${NC}"
        echo ""
        input_param "确认安装？(Y/n): " confirm
        confirm=${confirm:-Y}
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            msg_info "已取消。"
            press_enter
            return
        fi
        install_cc_command
    fi

    press_enter
}

install_cc_command() {
    mkdir -p "$CC_BIN_DIR"

    # 优先从远程下载最新版，失败则用当前运行中的脚本
    msg_info "下载最新脚本..."
    if curl -fsSL "$SCRIPT_REMOTE_URL" -o "$CC_BIN_PATH.tmp" 2>/dev/null; then
        mv "$CC_BIN_PATH.tmp" "$CC_BIN_PATH"
        msg_ok "已从远程下载最新版本。"
    elif [ -f "$0" ] && [ -s "$0" ]; then
        cp "$0" "$CC_BIN_PATH"
        msg_ok "已复制当前脚本。"
    else
        # 管道执行时 $0 不可靠，尝试用 /proc/self
        if [ -f "/proc/$$/fd/0" ]; then
            msg_warn "管道模式，使用当前缓存..."
        fi
        msg_error "无法获取脚本文件，请手动下载后放置到 $CC_BIN_PATH"
        rm -f "$CC_BIN_PATH.tmp"
        return
    fi

    chmod +x "$CC_BIN_PATH"

    ensure_path_in_rc
    msg_ok "快捷命令安装完成！"
    echo ""
    echo -e "  ${GREEN}${BOLD}现在新开终端后，输入 cc 即可启动本面板。${NC}"
    echo -e "  如需当前终端立即生效，请执行: ${YELLOW}export PATH=\"$CC_BIN_DIR:\$PATH\"${NC}"
}

uninstall_cc_command() {
    rm -f "$CC_BIN_PATH"
    msg_ok "快捷命令已卸载。"
    msg_info "如需清理 PATH 配置，请手动编辑 shell 配置文件移除相关行。"
}

ensure_path_in_rc() {
    # 检查 ~/.local/bin 是否已在 PATH 中
    if echo "$PATH" | tr ':' '\n' | grep -qx "$CC_BIN_DIR"; then
        return
    fi

    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local rc_files=()

    # 收集存在的 shell rc 文件
    [ -f "$HOME/.bashrc" ]       && rc_files+=("$HOME/.bashrc")
    [ -f "$HOME/.bash_profile" ] && rc_files+=("$HOME/.bash_profile")
    [ -f "$HOME/.zshrc" ]        && rc_files+=("$HOME/.zshrc")
    [ -f "$HOME/.profile" ]      && rc_files+=("$HOME/.profile")

    # 如果没有任何 rc 文件，创建 .bashrc
    if [ ${#rc_files[@]} -eq 0 ]; then
        rc_files+=("$HOME/.bashrc")
        touch "$HOME/.bashrc"
    fi

    local patched=false
    for rc_file in "${rc_files[@]}"; do
        if ! grep -qF '.local/bin' "$rc_file" 2>/dev/null; then
            printf '\n# Claude Code 快捷命令 cc\n%s\n' "$path_line" >> "$rc_file"
            msg_ok "已写入 PATH 到 $(basename "$rc_file")"
            patched=true
        fi
    done

    if [ "$patched" = false ]; then
        msg_ok "PATH 已包含 ~/.local/bin，无需修改。"
    fi
}

# ============================================================
#  主菜单
# ============================================================
main_menu() {
    while true; do
        clear
        print_banner
        show_status

        echo -e "  ${BOLD}请选择操作:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC}  安装环境依赖    - Node.js / Git 等基础环境"
        echo -e "  ${CYAN}2)${NC}  一键安装        - 安装 Claude Code (多种方式可选)"
        echo -e "  ${CYAN}3)${NC}  一键配置        - 交互式配置 API / 模型 / 环境变量"
        echo -e "  ${CYAN}4)${NC}  一键更新        - 智能检测安装方式并更新到最新版"
        echo -e "  ${CYAN}5)${NC}  一键卸载        - 完整卸载并可选清理所有残留"
        echo ""
        echo -e "  ${CYAN}6)${NC}  查看当前配置    - 查看 settings.json 内容"
        echo -e "  ${CYAN}7)${NC}  npm 迁移原生    - 从已弃用的 npm 迁移到原生安装"
        echo -e "  ${CYAN}8)${NC}  运行诊断        - 执行 claude doctor 自检"
        echo -e "  ${CYAN}9)${NC}  设置快捷命令    - 安装 ${BOLD}cc${NC} 命令，随时启动本面板"
        echo ""
        echo -e "  ${CYAN}0)${NC}  退出"
        echo ""

        input_param "请输入选项 [0-9]: " choice

        case "$choice" in
            1) menu_install_env ;;
            2) menu_install ;;
            3) menu_config ;;
            4) menu_update ;;
            5) menu_uninstall ;;
            6) menu_show_config ;;
            7) menu_migrate_npm ;;
            8) menu_doctor ;;
            9) menu_setup_alias ;;
            0) echo -e "\n${GREEN}再见！${NC}\n"; exit 0 ;;
            *) msg_error "无效选项，请重新输入。"; sleep 1 ;;
        esac
    done
}

# ============================================================
#  入口
# ============================================================
detect_os
detect_sudo
main_menu
