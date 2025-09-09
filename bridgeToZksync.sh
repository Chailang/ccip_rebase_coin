#!/bin/bash # 指定使用 Bash 解释器

# 设置错误处理
set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时退出

# 定义常量  # 定义常量
AMOUNT=100000 # 跨链金额（代币数量）

TEST_PLACE_ADDRESS="0xbc4b0Fc8eB6c564488c6Cb8859c09e37f839E441"
DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110" # 本地默认私钥（示例）
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049" # 本地默认地址（示例）
#配置 zkSync Sepolia 和 Sepolia 主网的合约地址与链选择器 在 ccip 文档中有地址: https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia
ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0x3139687Ee9938422F57933C3CDB3E21EE43c4d0F" # zkSync 上 RegistryModuleOwnerCustom 地址
ZKSYNC_TOKEN_ADMIN_REGISTRY="0xc7777f12258014866c677Bdb679D0b007405b7DF" # zkSync 上 TokenAdminRegistry 地址
ZKSYNC_ROUTER="0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16" # zkSync 上 CCIP Router 地址
ZKSYNC_RNM_PROXY_ADDRESS="0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467" # zkSync 上 RMN Proxy 地址
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="6898391096552792247" # zkSync Sepolia 链选择器
ZKSYNC_LINK_ADDRESS="0x23A1aFD896c8c8876AF46aDc38521f4432658d1e" # zkSync 上 LINK 代币地址

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790" # Sepolia 上 RegistryModuleOwnerCustom 地址
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82" # Sepolia 上 TokenAdminRegistry 地址
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59" # Sepolia 上 CCIP Router 地址
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991" # Sepolia 上 RMN Proxy 地址
SEPOLIA_CHAIN_SELECTOR="16015286601757825753" # Sepolia 链选择器
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789" # Sepolia 上 LINK 代币地址

# ========================================
# 预检查
# ========================================

echo "=========================================="
echo "开始 CCIP 跨链部署脚本"
echo "=========================================="

# 检查必要的文件是否存在
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在，请创建包含 RPC URL 和账户信息的 .env 文件"
    exit 1
fi

if [ ! -f "./switch-foundry.sh" ]; then
    echo "错误: switch-foundry.sh 脚本不存在"
    exit 1
fi

# 检查 Foundry 版本切换脚本是否可执行
if [ ! -x "./switch-foundry.sh" ]; then
    echo "设置 switch-foundry.sh 执行权限..."
    chmod +x ./switch-foundry.sh
fi

echo "预检查完成，开始部署流程..."
echo ""

# ========================================
# 第一部分：部署到 zkSync Sepolia
# ========================================

echo "=========================================="
echo "第一部分：部署到 zkSync Sepolia"
echo "=========================================="

# 切换到 zkSync Foundry 版本
echo "切换到 zkSync Foundry..."
./switch-foundry.sh zksync
# 手动更新 PATH 以确保使用正确的 Foundry 版本
export PATH="$HOME/.foundry-zksync/bin:$PATH"

# 加载环境变量（包含 RPC、账户等）
source .env # 加载环境变量（包含 RPC、账户等）
echo "Using ZKsync RPC URL: ${ZKSYNC_SEPOLIA_RPC_URL}" # 输出使用的 zkSync RPC URL
echo "Using Sepolia RPC URL: ${SEPOLIA_RPC_URL}" # 输出使用的 Sepolia RPC URL

# 使用 zkSync 编译模式构建
echo "使用 zkSync Foundry 编译项目..."
forge build --zksync
echo "Compiling and deploying the Rebase Token contract on ZKsync..." # 输出编译/部署提示
ZKSYNC_REBASE_TOKEN_ADDRESS=$(forge create --zksync src/RebaseToken.sol:RebaseToken --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 --legacy --broadcast | awk '/Deployed to:/ {print $3}') # 部署 RebaseToken 并提取地址
echo "ZKsync rebase token address: $ZKSYNC_REBASE_TOKEN_ADDRESS" # 打印部署后的代币地址

# Compile and deploy the pool contract # 编译并部署池合约（zkSync） 地址给空编译不过去，给个假的
echo "Compiling and deploying the pool contract on ZKsync..." # 输出提示
ZKSYNC_POOL_ADDRESS=$(forge create --zksync src/RebaseTokenPool.sol:RebaseTokenPool \
  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
  --account metaMask-Test1 \
  --legacy \
  --broadcast \
  --constructor-args ${ZKSYNC_REBASE_TOKEN_ADDRESS} 18 "[]" ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER} \
  | awk '/Deployed to:/ {print $3}')

echo "Pool address: $ZKSYNC_POOL_ADDRESS" # 打印池地址

# 检查池合约是否成功部署
if [ -z "$ZKSYNC_POOL_ADDRESS" ]; then
    echo "错误: 池合约部署失败"
    exit 1
fi

#Set the permissions for the pool contract # 设置池合约权限（zkSync）
echo "Setting the permissions for the pool contract on ZKsync..." # 输出提示
cast send ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 --legacy "grantMintAndBurnRole(address)" ${ZKSYNC_POOL_ADDRESS} # 授权池铸造/销毁权限
echo "Pool permissions set" # 打印完成

# Set the CCIP roles and permissions # 设置 CCIP 相关角色与权限（zkSync）
echo "Setting the CCIP roles and permissions on ZKsync..." # 输出提示
cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 --legacy "registerAdminViaOwner(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} # 在 RegistryModuleOwnerCustom 中注册管理员
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 --legacy "acceptAdminRole(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} # 接受管理员角色
cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 --legacy "setPool(address,address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} ${ZKSYNC_POOL_ADDRESS} # 绑定代币与池
echo "CCIP roles and permissions set" # 打印完成

# ========================================
# 第二部分：部署到 Sepolia (暂时注释)
# ========================================

echo "=========================================="
echo "第二部分：部署到 Sepolia"
echo "=========================================="

# 加载环境变量（包含 RPC、账户等）
source .env
echo "Using Sepolia RPC URL: ${SEPOLIA_RPC_URL}"
echo "Using ZKsync RPC URL: ${ZKSYNC_SEPOLIA_RPC_URL}"

# 切换到标准 Foundry 版本
echo "切换到标准 Foundry..."
./switch-foundry.sh standard
# 手动更新 PATH 以确保使用正确的 Foundry 版本
export PATH="/opt/homebrew/bin:$PATH"

echo "Running the script to deploy the contracts on Sepolia..." # 在 Sepolia 上运行部署脚本
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account metaMask-Test1 --broadcast) # 执行 Foundry 脚本并记录输出
echo "Contracts deployed and permission set on Sepolia" # 打印完成提示

# Extract the addresses from the output # 从脚本输出中提取地址
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}') # 提取 RebaseToken 地址
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}') # 提取池合约地址

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS" # 打印 Sepolia 代币地址
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS" # 打印 Sepolia 池地址

# Deploy the vault  # 部署金库合约（Sepolia）
echo "Deploying the vault on Sepolia..." # 输出提示
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account metaMask-Test1 --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}') # 部署金库并提取地址
echo "Vault address: $VAULT_ADDRESS" # 打印金库地址

# Configure the pool on Sepolia # 在 Sepolia 上配置池
echo "Configuring the pool on Sepolia..." # 输出提示
# uint64 remoteChainSelector, # 远程链选择器
#         address remotePoolAddress, / # 远程池地址
#         address remoteTokenAddress, / # 远程代币地址
#         bool outboundRateLimiterIsEnabled, false  # 出站限流是否启用
#         uint128 outboundRateLimiterCapacity, 0 # 出站容量
#         uint128 outboundRateLimiterRate, 0 # 出站速率
#         bool inboundRateLimiterIsEnabled, false  # 入站限流是否启用
#         uint128 inboundRateLimiterCapacity, 0  # 入站容量
#         uint128 inboundRateLimiterRate 0  # 入站速率
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account metaMask-Test1 --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0 # 执行池配置脚本

# Deposit funds to the vault # 向金库存入资金（Sepolia）
echo "Depositing funds to the vault on Sepolia..." # 输出提示
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account metaMask-Test1 "deposit()" # 调用金库存款

# Wait a beat for some interest to accrue # 留出时间产生利息（可按需添加等待）

# Configure the pool on ZKsync # 在 zkSync 上配置池 多余删除掉
# echo "Configuring the pool on ZKsync..." # 输出提示
# cast send ${ZKSYNC_POOL_ADDRESS}  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account metaMask-Test1 "applyChainUpdates(uint64[],(uint64,bytes[],bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" "[${SEPOLIA_CHAIN_SELECTOR}]" "[(${SEPOLIA_CHAIN_SELECTOR},[$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})],$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS}),(false,0,0),(false,0,0))]" # 应用链更新，加入 Sepolia 远程链配置

# Bridge the funds using the script to zksync  # 使用脚本将资金桥接到 zkSync
echo "Bridging the funds using the script to ZKsync..." # 输出提示
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account metaMask-Test1) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL}) # 查询桥接前余额
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE" # 打印桥接前余额
forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account metaMask-Test1 --broadcast --sig "sendMessage(address,uint64,address,uint256,address,address)" $(cast wallet address --account metaMask-Test1) ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER} # 执行桥接脚本
echo "Funds bridged to ZKsync" # 打印完成提示
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account metaMask-Test1) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL}) # 查询桥接后余额
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER" # 打印桥接后余额

# ========================================
# 部署完成总结
# ========================================

echo "=========================================="
echo "部署完成总结"
echo "=========================================="
echo "zkSync Sepolia 部署地址:"
echo "  RebaseToken: $ZKSYNC_REBASE_TOKEN_ADDRESS"
echo "  Pool: $ZKSYNC_POOL_ADDRESS"
echo ""
echo "Sepolia 部署地址:"
echo "  RebaseToken: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "  Pool: $SEPOLIA_POOL_ADDRESS"
echo "  Vault: $VAULT_ADDRESS"
echo ""
echo "注意: 第一部分（zkSync 部署）已注释，使用了之前部署的地址"
echo "=========================================="