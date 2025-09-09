#!/bin/bash

# 手动安装 zkSync Foundry 脚本
# 用于网络连接有问题时的离线安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.foundry-zksync"
BIN_DIR="$INSTALL_DIR/bin"

echo -e "${BLUE}zkSync Foundry 手动安装脚本${NC}"
echo ""

# 检测系统架构
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${YELLOW}检测到系统: $OS $ARCH${NC}"

if [[ "$ARCH" == "arm64" ]]; then
    ARCH_SUFFIX="aarch64"
elif [[ "$ARCH" == "x86_64" ]]; then
    ARCH_SUFFIX="x86_64"
else
    echo -e "${RED}不支持的架构: $ARCH${NC}"
    exit 1
fi

echo -e "${YELLOW}使用架构后缀: $ARCH_SUFFIX${NC}"
echo ""

# 创建安装目录
echo -e "${BLUE}创建安装目录...${NC}"
mkdir -p "$BIN_DIR"

# 定义下载函数
download_binary() {
    local tool_name="$1"
    local url="$2"
    local output_path="$3"
    
    echo -e "${YELLOW}下载 $tool_name...${NC}"
    echo "URL: $url"
    
    if curl -L -o "$output_path" "$url"; then
        chmod +x "$output_path"
        echo -e "${GREEN}✓ $tool_name 下载成功${NC}"
    else
        echo -e "${RED}✗ $tool_name 下载失败${NC}"
        echo "请手动下载: $url"
        echo "保存到: $output_path"
        echo "然后运行: chmod +x $output_path"
    fi
    echo ""
}

# 下载二进制文件
echo -e "${BLUE}开始下载 zkSync Foundry 二进制文件...${NC}"
echo ""

# 基础 URL
BASE_URL="https://github.com/matter-labs/foundry-zksync/releases/latest/download"

# 下载各个工具
download_binary "forge" "$BASE_URL/forge-$OS-$ARCH_SUFFIX" "$BIN_DIR/forge"
download_binary "cast" "$BASE_URL/cast-$OS-$ARCH_SUFFIX" "$BIN_DIR/cast"
download_binary "anvil" "$BASE_URL/anvil-$OS-$ARCH_SUFFIX" "$BIN_DIR/anvil"
download_binary "chisel" "$BASE_URL/chisel-$OS-$ARCH_SUFFIX" "$BIN_DIR/chisel"

# 验证安装
echo -e "${BLUE}验证安装...${NC}"
echo ""

if [ -f "$BIN_DIR/forge" ] && [ -x "$BIN_DIR/forge" ]; then
    echo -e "${GREEN}✓ forge 安装成功${NC}"
    echo "版本: $($BIN_DIR/forge --version | head -n1)"
else
    echo -e "${RED}✗ forge 安装失败${NC}"
fi

if [ -f "$BIN_DIR/cast" ] && [ -x "$BIN_DIR/cast" ]; then
    echo -e "${GREEN}✓ cast 安装成功${NC}"
else
    echo -e "${RED}✗ cast 安装失败${NC}"
fi

if [ -f "$BIN_DIR/anvil" ] && [ -x "$BIN_DIR/anvil" ]; then
    echo -e "${GREEN}✓ anvil 安装成功${NC}"
else
    echo -e "${RED}✗ anvil 安装失败${NC}"
fi

if [ -f "$BIN_DIR/chisel" ] && [ -x "$BIN_DIR/chisel" ]; then
    echo -e "${GREEN}✓ chisel 安装成功${NC}"
else
    echo -e "${RED}✗ chisel 安装失败${NC}"
fi

echo ""
echo -e "${BLUE}安装完成！${NC}"
echo ""
echo "安装位置: $BIN_DIR"
echo ""
echo "下一步:"
echo "1. 运行 './switch-foundry.sh zksync' 切换到 zkSync Foundry"
echo "2. 运行 'source ~/.zshrc' 或重新打开终端"
echo "3. 运行 './switch-foundry.sh status' 验证切换"
echo ""
echo "如果下载失败，请手动下载以下文件到 $BIN_DIR:"
echo "- forge: $BASE_URL/forge-$OS-$ARCH_SUFFIX"
echo "- cast: $BASE_URL/cast-$OS-$ARCH_SUFFIX"
echo "- anvil: $BASE_URL/anvil-$OS-$ARCH_SUFFIX"
echo "- chisel: $BASE_URL/chisel-$OS-$ARCH_SUFFIX"


