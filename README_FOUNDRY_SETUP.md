# Foundry 双版本安装完成总结

## ✅ 已完成的工作

### 1. 创建了版本切换脚本
- **文件**: `switch-foundry.sh`
- **功能**: 在标准 Foundry 和 zkSync Foundry 之间切换
- **命令**:
  - `./switch-foundry.sh status` - 查看当前状态
  - `./switch-foundry.sh standard` - 切换到标准 Foundry
  - `./switch-foundry.sh zksync` - 切换到 zkSync Foundry
  - `./switch-foundry.sh install` - 安装 zkSync Foundry
  - `./switch-foundry.sh help` - 显示帮助

### 2. 更新了项目配置
- **文件**: `foundry.toml`
- **新增配置**:
  - `[profile.zksync]` - zkSync 专用配置
  - zkSync RPC 端点配置
  - 优化的编译器设置

### 3. 创建了安装脚本
- **文件**: `install-zksync-manual.sh`
- **功能**: 手动安装 zkSync Foundry（网络问题时使用）

### 4. 提供了完整文档
- **ZKSYNC_FOUNDRY_SETUP.md** - 详细安装和配置指南
- **QUICK_START.md** - 快速开始指南
- **README_FOUNDRY_SETUP.md** - 本总结文档

## 🚀 下一步操作

### 安装 zkSync Foundry

由于网络连接问题，你需要手动安装 zkSync Foundry：

```bash
# 方法 1: 尝试自动安装
./switch-foundry.sh install

# 方法 2: 如果网络有问题，使用手动安装
./install-zksync-manual.sh
```

### 手动下载（如果自动安装失败）

下载以下文件到 `~/.foundry-zksync/bin/` 目录：

**macOS ARM64 (Apple Silicon):**
```bash
mkdir -p ~/.foundry-zksync/bin
cd ~/.foundry-zksync/bin

# 下载二进制文件
curl -L -o forge https://github.com/matter-labs/foundry-zksync/releases/latest/download/forge-darwin-aarch64
curl -L -o cast https://github.com/matter-labs/foundry-zksync/releases/latest/download/cast-darwin-aarch64
curl -L -o anvil https://github.com/matter-labs/foundry-zksync/releases/latest/download/anvil-darwin-aarch64
curl -L -o chisel https://github.com/matter-labs/foundry-zksync/releases/latest/download/chisel-darwin-aarch64

# 设置执行权限
chmod +x *
```

### 验证安装

```bash
# 检查安装状态
./switch-foundry.sh status

# 切换到 zkSync Foundry
./switch-foundry.sh zksync

# 重新加载配置
source ~/.zshrc

# 验证版本
forge --version
```

## 📋 使用示例

### 标准 Foundry 工作流
```bash
# 切换到标准 Foundry
./switch-foundry.sh standard
source ~/.zshrc

# 编译和测试
forge build
forge test
```

### zkSync Foundry 工作流
```bash
# 切换到 zkSync Foundry
./switch-foundry.sh zksync
source ~/.zshrc

# 编译和测试
forge build --zksync
forge test --zksync

# 运行桥接脚本
./bridgeToZksync.sh
```

## 🔧 配置文件说明

### foundry.toml 中的配置

1. **标准配置** (`[profile.default]`):
   - 用于标准以太坊网络
   - 标准编译器设置

2. **zkSync 配置** (`[profile.zksync]`):
   - 启用 `via_ir = true`
   - 优化的编译器设置
   - zkSync 特定的重映射

3. **RPC 端点**:
   - `zksync_sepolia`: 测试网
   - `zksync_mainnet`: 主网

## ⚠️ 注意事项

1. **网络连接**: 如果 GitHub 访问有问题，使用手动下载方法
2. **版本兼容**: 确保使用最新的 zkSync Foundry 版本
3. **配置文件**: 项目已预配置，无需额外设置
4. **备份**: 切换脚本会自动备份配置文件

## 🆘 故障排除

### 常见问题

1. **命令未找到**:
   ```bash
   ./switch-foundry.sh status
   source ~/.zshrc
   ```

2. **网络连接问题**:
   - 使用手动下载方法
   - 检查防火墙设置

3. **权限问题**:
   ```bash
   chmod +x ~/.foundry-zksync/bin/*
   ```

### 重置配置

```bash
# 备份当前配置
cp ~/.zshrc ~/.zshrc.backup

# 重置为标准 Foundry
./switch-foundry.sh standard
```

## 📚 相关文档

- [ZKSYNC_FOUNDRY_SETUP.md](./ZKSYNC_FOUNDRY_SETUP.md) - 详细安装指南
- [QUICK_START.md](./QUICK_START.md) - 快速开始指南
- [foundry.toml](./foundry.toml) - 项目配置文件

## 🎉 完成状态

- ✅ 版本切换脚本
- ✅ 项目配置更新
- ✅ 安装脚本
- ✅ 完整文档
- ⏳ zkSync Foundry 安装（需要网络连接）
- ⏳ 最终测试

安装完成后，你就可以在标准 Foundry 和 zkSync Foundry 之间自由切换了！


