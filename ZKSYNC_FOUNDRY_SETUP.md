# zkSync Foundry 安装和配置指南

本指南将帮助你在保留标准 Foundry 的情况下安装和配置 zkSync 版 Foundry。

## 目录
- [概述](#概述)
- [安装方法](#安装方法)
- [版本切换](#版本切换)
- [配置说明](#配置说明)
- [使用方法](#使用方法)
- [故障排除](#故障排除)

## 概述

zkSync Foundry 是专门为 zkSync Era 网络设计的 Foundry 工具链版本。它支持 zkSync 特定的编译器和部署功能。

### 主要特性
- 支持 zkSync Era 网络部署
- 优化的编译器设置
- 与标准 Foundry 兼容的 API
- 支持 zkSync 特定的合约功能

## 安装方法

### 方法 1: 使用切换脚本（推荐）

1. 运行安装命令：
```bash
./switch-foundry.sh install
```

2. 如果网络连接有问题，可以手动下载二进制文件。

### 方法 2: 手动安装

由于网络连接问题，你可以手动下载 zkSync Foundry 二进制文件：

1. 创建安装目录：
```bash
mkdir -p ~/.foundry-zksync/bin
```

2. 从以下链接下载对应你系统的二进制文件：
   - **macOS ARM64 (Apple Silicon)**:
     - forge: https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-aarch64
     - cast: https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-aarch64
     - anvil: https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-aarch64
     - chisel: https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-aarch64

   - **macOS x86_64 (Intel)**:
     - forge: https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-x86_64
     - cast: https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-x86_64
     - anvil: https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-x86_64
     - chisel: https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-x86_64

3. 下载并设置执行权限：
```bash
cd ~/.foundry-zksync/bin

# 下载 forge
curl -L -o forge https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-aarch64
chmod +x forge

# 下载 cast
curl -L -o cast https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-aarch64
chmod +x cast

# 下载 anvil
curl -L -o anvil https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-aarch64
chmod +x anvil

# 下载 chisel
curl -L -o chisel https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-aarch64
chmod +x chisel
```

## 版本切换

使用提供的切换脚本在标准 Foundry 和 zkSync Foundry 之间切换：

### 查看当前状态
```bash
./switch-foundry.sh status
```

### 切换到标准 Foundry
```bash
./switch-foundry.sh standard
```

### 切换到 zkSync Foundry
```bash
./switch-foundry.sh zksync
```

### 显示帮助信息
```bash
./switch-foundry.sh help
```

## 配置说明

### foundry.toml 配置

项目已经配置了两个 Foundry 配置文件：

1. **标准配置** (`[profile.default]`): 用于标准以太坊网络
2. **zkSync 配置** (`[profile.zksync]`): 用于 zkSync Era 网络

### zkSync 特定配置

```toml
[profile.zksync]
src = "src"
out = "out"
libs = ["lib"]
via_ir = true          # zkSync 需要启用 via_ir
optimizer = true       # 启用优化器
optimizer_runs = 200   # 优化器运行次数
```

### RPC 端点

已配置的 zkSync RPC 端点：
- `zksync_sepolia`: https://sepolia.era.zksync.dev
- `zksync_mainnet`: https://mainnet.era.zksync.io

## 使用方法

### 编译合约

**标准 Foundry**:
```bash
forge build
```

**zkSync Foundry**:
```bash
forge build --zksync
```

### 部署合约

**标准 Foundry**:
```bash
forge create src/RebaseToken.sol:RebaseToken --rpc-url $RPC_URL --account $ACCOUNT
```

**zkSync Foundry**:
```bash
forge create --zksync src/RebaseToken.sol:RebaseToken --rpc-url $ZKSYNC_RPC_URL --account $ACCOUNT
```

### 运行测试

**标准 Foundry**:
```bash
forge test
```

**zkSync Foundry**:
```bash
forge test --zksync
```

### 使用脚本

项目中的 `bridgeToZksync.sh` 脚本已经配置为使用 zkSync Foundry：

```bash
# 确保使用 zkSync Foundry
./switch-foundry.sh zksync
source ~/.zshrc

# 运行桥接脚本
./bridgeToZksync.sh
```

## 故障排除

### 常见问题

1. **命令未找到**
   - 确保已正确安装 zkSync Foundry
   - 检查 PATH 环境变量
   - 运行 `./switch-foundry.sh status` 检查安装状态

2. **编译错误**
   - 确保使用正确的配置文件
   - 检查 `via_ir = true` 设置
   - 验证合约兼容性

3. **网络连接问题**
   - 检查 RPC 端点是否可访问
   - 验证网络配置
   - 尝试使用不同的 RPC 提供商

### 重置配置

如果需要重置配置：

```bash
# 备份当前配置
cp ~/.zshrc ~/.zshrc.backup

# 移除 Foundry 相关配置
sed -i.bak '/# Foundry PATH/d' ~/.zshrc
sed -i.bak '/export PATH.*foundry/d' ~/.zshrc

# 重新配置
./switch-foundry.sh standard
```

### 获取帮助

- 运行 `./switch-foundry.sh help` 查看脚本帮助
- 查看 [zkSync Foundry 官方文档](https://github.com/matter-labs/foundry-zksync)
- 检查项目的 `foundry.toml` 配置

## 注意事项

1. **版本兼容性**: 确保使用兼容的 zkSync Foundry 版本
2. **合约兼容性**: 某些标准以太坊合约可能需要在 zkSync 上进行修改
3. **网络费用**: zkSync 网络使用 ETH 作为 gas 费用
4. **测试**: 在部署到主网前，先在测试网上进行充分测试

## 更新

要更新 zkSync Foundry：

```bash
# 删除旧版本
rm -rf ~/.foundry-zksync

# 重新安装
./switch-foundry.sh install
```
