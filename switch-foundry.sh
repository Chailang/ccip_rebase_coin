#!/bin/bash

# Foundry 版本切换脚本
# 用于在标准 Foundry 和 zkSync Foundry 之间切换

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置路径
STANDARD_FOUNDRY_PATH="/opt/homebrew/bin"
ZKSYNC_FOUNDRY_PATH="$HOME/.foundry-zksync/bin"
BACKUP_PATH="$HOME/.foundry-backup"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Foundry 版本切换工具${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  standard    切换到标准 Foundry"
    echo "  zksync      切换到 zkSync Foundry"
    echo "  status      显示当前版本状态"
    echo "  install     安装 zkSync Foundry"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 standard    # 切换到标准 Foundry"
    echo "  $0 zksync      # 切换到 zkSync Foundry"
    echo "  $0 status      # 查看当前版本"
}

# 检查当前版本
check_status() {
    echo -e "${BLUE}当前 Foundry 版本状态:${NC}"
    echo ""
    
    if command -v forge &> /dev/null; then
        FORGE_PATH=$(which forge)
        echo -e "Forge 路径: ${GREEN}$FORGE_PATH${NC}"
        echo -e "Forge 版本: ${GREEN}$(forge --version)${NC}"
        
        if [[ "$FORGE_PATH" == *"foundry-zksync"* ]]; then
            echo -e "当前版本: ${YELLOW}zkSync Foundry${NC}"
        else
            echo -e "当前版本: ${YELLOW}标准 Foundry${NC}"
        fi
    else
        echo -e "Forge: ${RED}未安装${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}可用版本:${NC}"
    
    if [ -d "$STANDARD_FOUNDRY_PATH" ] && [ -f "$STANDARD_FOUNDRY_PATH/forge" ]; then
        echo -e "标准 Foundry: ${GREEN}已安装${NC} ($STANDARD_FOUNDRY_PATH)"
    else
        echo -e "标准 Foundry: ${RED}未安装${NC}"
    fi
    
    if [ -d "$ZKSYNC_FOUNDRY_PATH" ] && [ -f "$ZKSYNC_FOUNDRY_PATH/forge" ]; then
        echo -e "zkSync Foundry: ${GREEN}已安装${NC} ($ZKSYNC_FOUNDRY_PATH)"
    else
        echo -e "zkSync Foundry: ${RED}未安装${NC}"
    fi
}

# 备份当前配置
backup_current() {
    echo -e "${YELLOW}备份当前 Foundry 配置...${NC}"
    mkdir -p "$BACKUP_PATH"
    
    # 备份 PATH 配置
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$BACKUP_PATH/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    if [ -f "$HOME/.zshenv" ]; then
        cp "$HOME/.zshenv" "$BACKUP_PATH/.zshenv.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# 切换到标准 Foundry
switch_to_standard() {
    echo -e "${BLUE}切换到标准 Foundry...${NC}"
    
    # 检查标准 Foundry 是否安装
    if [ ! -f "$STANDARD_FOUNDRY_PATH/forge" ]; then
        echo -e "${RED}错误: 标准 Foundry 未安装${NC}"
        echo "请先运行: brew install foundry"
        exit 1
    fi
    
    backup_current
    
    # 更新 PATH
    update_path "$STANDARD_FOUNDRY_PATH"
    
    echo -e "${GREEN}已切换到标准 Foundry${NC}"
    echo "请运行 'source ~/.zshrc' 或重新打开终端以应用更改"
}

# 切换到 zkSync Foundry
switch_to_zksync() {
    echo -e "${BLUE}切换到 zkSync Foundry...${NC}"
    
    # 检查 zkSync Foundry 是否安装
    if [ ! -f "$ZKSYNC_FOUNDRY_PATH/forge" ]; then
        echo -e "${RED}错误: zkSync Foundry 未安装${NC}"
        echo "请先运行: $0 install"
        exit 1
    fi
    
    backup_current
    
    # 更新 PATH
    update_path "$ZKSYNC_FOUNDRY_PATH"
    
    echo -e "${GREEN}已切换到 zkSync Foundry${NC}"
    echo "请运行 'source ~/.zshrc' 或重新打开终端以应用更改"
}

# 更新 PATH 配置
update_path() {
    local foundry_path="$1"
    
    # 创建或更新 .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        # 移除旧的 Foundry PATH 配置
        sed -i.bak '/# Foundry PATH/d' "$HOME/.zshrc"
        sed -i.bak '/export PATH.*foundry/d' "$HOME/.zshrc"
    fi
    
    # 添加新的 PATH 配置
    echo "" >> "$HOME/.zshrc"
    echo "# Foundry PATH - 由 switch-foundry.sh 管理" >> "$HOME/.zshrc"
    echo "export PATH=\"$foundry_path:\$PATH\"" >> "$HOME/.zshrc"
    
    # 更新当前会话的 PATH
    export PATH="$foundry_path:$PATH"
}

# 安装 zkSync Foundry
install_zksync() {
    echo -e "${BLUE}安装 zkSync Foundry...${NC}"
    
    # 创建安装目录
    mkdir -p "$HOME/.foundry-zksync"
    cd "$HOME/.foundry-zksync"
    
    echo -e "${YELLOW}正在下载 zkSync Foundry...${NC}"
    
    # 尝试不同的下载方法
    if command -v curl &> /dev/null; then
        # 方法1: 从 GitHub 下载
        echo "尝试从 GitHub 下载..."
        if curl -L -o foundryup-zksync "https://github.com/matter-labs/foundry-zksync/releases/latest/download/foundryup-zksync"; then
            chmod +x foundryup-zksync
            ./foundryup-zksync
        else
            echo -e "${YELLOW}GitHub 下载失败，尝试备用方法...${NC}"
            install_zksync_manual
        fi
    else
        install_zksync_manual
    fi
    
    if [ -f "$ZKSYNC_FOUNDRY_PATH/forge" ]; then
        echo -e "${GREEN}zkSync Foundry 安装成功！${NC}"
        echo "运行 '$0 zksync' 切换到 zkSync Foundry"
    else
        echo -e "${RED}zkSync Foundry 安装失败${NC}"
        echo "请手动安装或检查网络连接"
    fi
}

# 手动安装 zkSync Foundry
install_zksync_manual() {
    echo -e "${YELLOW}使用手动安装方法...${NC}"
    
    # 创建安装脚本
    cat > install_manual.sh << 'EOF'
#!/bin/bash

# 手动安装 zkSync Foundry 的脚本
# 基于官方文档: https://github.com/matter-labs/foundry-zksync

set -e

INSTALL_DIR="$HOME/.foundry-zksync"
BIN_DIR="$INSTALL_DIR/bin"

echo "创建安装目录..."
mkdir -p "$BIN_DIR"

echo "下载 zkSync Foundry 二进制文件..."

# 根据系统架构下载对应的二进制文件
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$ARCH" == "arm64" ]]; then
    ARCH="aarch64"
elif [[ "$ARCH" == "x86_64" ]]; then
    ARCH="x86_64"
fi

# 下载 forge
FORGE_URL="https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-${OS}-${ARCH}"
echo "下载 forge: $FORGE_URL"
curl -L -o "$BIN_DIR/forge" "$FORGE_URL"
chmod +x "$BIN_DIR/forge"

# 下载 cast
CAST_URL="https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-${OS}-${ARCH}"
echo "下载 cast: $CAST_URL"
curl -L -o "$BIN_DIR/cast" "$CAST_URL"
chmod +x "$BIN_DIR/cast"

# 下载 anvil
ANVIL_URL="https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-${OS}-${ARCH}"
echo "下载 anvil: $ANVIL_URL"
curl -L -o "$BIN_DIR/anvil" "$ANVIL_URL"
chmod +x "$BIN_DIR/anvil"

# 下载 chisel
CHISEL_URL="https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-${OS}-${ARCH}"
echo "下载 chisel: $CHISEL_URL"
curl -L -o "$BIN_DIR/chisel" "$CHISEL_URL"
chmod +x "$BIN_DIR/chisel"

echo "安装完成！"
echo "二进制文件位置: $BIN_DIR"
EOF
    
    chmod +x install_manual.sh
    ./install_manual.sh
    rm install_manual.sh
}

# 主函数
main() {
    case "${1:-help}" in
        "standard")
            switch_to_standard
            ;;
        "zksync")
            switch_to_zksync
            ;;
        "status")
            check_status
            ;;
        "install")
            install_zksync
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"


