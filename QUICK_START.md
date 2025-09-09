# zkSync Foundry 快速开始指南

## 🚀 快速安装和切换

### 1. 安装 zkSync Foundry

**方法 A: 自动安装（推荐）**
```bash
./switch-foundry.sh install
```

**方法 B: 手动安装（网络问题时）**
```bash
./install-zksync-manual.sh
```

### 2. 版本切换

```bash
# 查看当前状态
./switch-foundry.sh status

# 切换到 zkSync Foundry
./switch-foundry.sh zksync

# 切换到标准 Foundry
./switch-foundry.sh standard
```

### 3. 应用更改

```bash
# 重新加载配置
source ~/.zshrc

# 或者重新打开终端
```

## 🔧 基本使用

### 编译合约

**标准 Foundry:**
```bash
forge build
```

**zkSync Foundry:**
```bash
forge build --zksync
```

### 部署合约

**标准 Foundry:**
```bash
forge create src/RebaseToken.sol:RebaseToken --rpc-url $RPC_URL --account $ACCOUNT
```

**zkSync Foundry:**
```bash
forge create --zksync src/RebaseToken.sol:RebaseToken --rpc-url $ZKSYNC_RPC_URL --account $ACCOUNT
```

### 运行测试

**标准 Foundry:**
```bash
forge test
```

**zkSync Foundry:**
```bash
forge test --zksync
```

## 📋 项目特定使用

### 运行桥接脚本

```bash
# 1. 切换到 zkSync Foundry
./switch-foundry.sh zksync
source ~/.zshrc

# 2. 运行桥接脚本
./bridgeToZksync.sh
```

### 使用不同的配置文件

项目已配置两个配置文件：
- `[profile.default]`: 标准以太坊网络
- `[profile.zksync]`: zkSync Era 网络

## 🛠️ 故障排除

### 检查安装状态
```bash
./switch-foundry.sh status
```

### 重置配置
```bash
# 备份当前配置
cp ~/.zshrc ~/.zshrc.backup

# 重置为标准 Foundry
./switch-foundry.sh standard
```

### 手动下载（网络问题时）

如果自动下载失败，手动下载以下文件到 `~/.foundry-zksync/bin/`:

**macOS ARM64 (Apple Silicon):**
- forge: https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-aarch64
- cast: https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-aarch64
- anvil: https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-aarch64
- chisel: https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-aarch64

**macOS x86_64 (Intel):**
- forge: https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-x86_64
- cast: https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-x86_64
- anvil: https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-x86_64
- chisel: https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-x86_64

下载后设置执行权限：
```bash
chmod +x ~/.foundry-zksync/bin/*
```

## 📚 更多信息

- 详细安装指南: [ZKSYNC_FOUNDRY_SETUP.md](./ZKSYNC_FOUNDRY_SETUP.md)
- zkSync 官方文档: https://github.com/matter-labs/foundry-zksync
- 项目配置: [foundry.toml](./foundry.toml)

## ⚠️ 注意事项

1. **网络连接**: 如果 GitHub 访问有问题，使用手动安装方法
2. **版本兼容**: 确保使用兼容的 zkSync Foundry 版本
3. **配置文件**: 项目已预配置 zkSync 设置，无需额外配置
4. **测试**: 在部署到主网前，先在测试网上测试


