#!/bin/bash

# 设置错误处理
set -e
set -u

echo "=========================================="
echo "测试部署脚本"
echo "=========================================="

# 加载环境变量
source .env
echo "Using ZKsync RPC URL: ${ZKSYNC_SEPOLIA_RPC_URL}"

# 切换到 zkSync Foundry
echo "切换到 zkSync Foundry..."
./switch-foundry.sh zksync
export PATH="$HOME/.foundry-zksync/bin:$PATH"

# 验证版本
echo "当前 Forge 版本:"
forge --version

# 编译项目
echo "编译项目..."
forge build --zksync

# 检查账户
echo "检查账户..."
cast wallet list

echo "测试完成！"


