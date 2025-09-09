# CCIP 跨链部署脚本使用指南

## 概述

`bridgeToZksync.sh` 脚本用于在 zkSync Sepolia 和 Ethereum Sepolia 之间部署 CCIP 跨链 Rebase Token 系统。

## 脚本功能

### 第一部分：zkSync Sepolia 部署
- 自动切换到 zkSync Foundry
- 编译项目（使用 `--zksync` 标志）
- 部署 RebaseToken 合约
- 部署 RebaseTokenPool 合约
- 设置合约权限和 CCIP 角色

### 第二部分：Ethereum Sepolia 部署
- 自动切换到标准 Foundry
- 部署 RebaseToken 合约
- 部署 RebaseTokenPool 合约
- 部署 Vault 合约
- 配置跨链池
- 执行代币桥接

## 前置条件

### 1. 环境文件 (.env)
创建 `.env` 文件，包含以下内容：

```bash
# RPC URLs
ZKSYNC_SEPOLIA_RPC_URL="https://sepolia.era.zksync.dev"
SEPOLIA_RPC_URL="https://ethereum-sepolia.publicnode.com"

# 账户配置
# 确保你的 MetaMask 账户已配置为 metaMask-Test1
```

### 2. 账户配置
确保你的 Foundry 配置中有 `metaMask-Test1` 账户：

```bash
# 添加账户到 Foundry
cast wallet import metaMask-Test1 --interactive
```

### 3. 网络代币
确保账户在以下网络有足够的代币：
- **zkSync Sepolia**: ETH (用于 gas 费)
- **Ethereum Sepolia**: ETH (用于 gas 费) 和 LINK (用于 CCIP 费用)

## 使用方法

### 执行完整部署
```bash
./bridgeToZksync.sh
```

### 脚本执行流程

1. **预检查**
   - 检查 `.env` 文件是否存在
   - 检查 `switch-foundry.sh` 脚本是否存在
   - 设置必要的执行权限

2. **第一部分：zkSync 部署**
   - 切换到 zkSync Foundry
   - 编译项目
   - 部署合约
   - 配置权限

3. **第二部分：Sepolia 部署**
   - 切换到标准 Foundry
   - 部署合约
   - 配置跨链
   - 执行桥接

4. **完成总结**
   - 显示所有部署地址
   - 显示桥接状态

## 输出示例

```
==========================================
开始 CCIP 跨链部署脚本
==========================================
预检查完成，开始部署流程...

==========================================
第一部分：部署到 zkSync Sepolia
==========================================
切换到 zkSync Foundry...
使用 zkSync Foundry 编译项目...
[⠃] Using zksolc-1.5.15
[⠊] Compiling (zksync)
...

==========================================
第二部分：部署到 Sepolia
==========================================
切换到标准 Foundry...
Running the script to deploy the contracts on Sepolia...

==========================================
部署完成总结
==========================================
zkSync Sepolia 部署地址:
  RebaseToken: 0x...
  Pool: 0x...

Sepolia 部署地址:
  RebaseToken: 0x...
  Pool: 0x...
  Vault: 0x...

桥接状态:
  桥接前余额: 100000
  桥接后余额: 0
==========================================
```

## 故障排除

### 常见问题

1. **环境变量未设置**
   ```
   错误: .env 文件不存在
   ```
   解决：创建 `.env` 文件并设置必要的环境变量

2. **账户未配置**
   ```
   Error: No such account: metaMask-Test1
   ```
   解决：使用 `cast wallet import` 导入账户

3. **网络连接问题**
   ```
   Error: Failed to connect to RPC
   ```
   解决：检查 RPC URL 和网络连接

4. **Gas 费不足**
   ```
   Error: Insufficient funds
   ```
   解决：确保账户有足够的 ETH 用于 gas 费

### 调试模式

如果需要调试，可以在脚本开头添加：
```bash
set -x  # 显示执行的每个命令
```

## 注意事项

1. **网络费用**: 确保账户在两个网络都有足够的 ETH
2. **CCIP 费用**: Sepolia 网络需要 LINK 代币支付 CCIP 费用
3. **部署时间**: 完整部署可能需要几分钟时间
4. **版本兼容**: 脚本会自动切换 Foundry 版本，无需手动操作

## 相关文档

- [zkSync Foundry 安装指南](./ZKSYNC_FOUNDRY_SETUP.md)
- [快速开始指南](./QUICK_START.md)
- [CCIP 官方文档](https://docs.chain.link/ccip)
- [zkSync 官方文档](https://docs.zksync.io)


