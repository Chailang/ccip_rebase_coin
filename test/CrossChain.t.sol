// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "@chainlink/local/src/ccip/Register.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

import {RebaseToken} from "../src/RebaseToken.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
/*
代币跨链的两种核心模式
1. Lock & Mint (锁定 + 铸造)

常见于原生资产（如 ETH、BTC）

源链的代币不能随便销毁，所以只能 锁在桥合约里

目标链生成一个 对应的镜像代币（wrapped token）

回来时 burn 镜像代币，再从源链合约里 解锁原生资产

👉 例子：

ETH → Arbitrum/Optimism

BTC → WBTC (比特币锁定在多签，Ethereum 上 mint WBTC)


2. Burn & Mint (销毁 + 铸造)

常见于合约代币（ERC20, RebaseToken, Stablecoin 等）

代币可以在每条链上部署同一份合约

跨链时 源链 burn，目标链 mint

跨链后的代币看起来“移动”了，但其实是不同链上的部署实例在同步供应量

👉 例子：

USDT / USDC（Circle 在不同链上都有官方部署，跨链就是 burn + mint）

你测试的 RebaseToken

*/

/*

1.部署环境

使用 Foundry 分叉测试，分别 fork Sepolia 和 Arbitrum Sepolia 测试网。

使用 CCIPLocalSimulatorFork 来模拟 Chainlink CCIP 的跨链消息传递。

在两个链上分别部署：

    RebaseToken（代币）

    RebaseTokenPool（池子，负责跨链通信）

    Vault（金库，存 ETH 发 RebaseToken）

2.配置角色 & 权限

    给 TokenPool、Vault 分配 mint/burn 权限（RebaseToken 不是自由增发的，需要白名单角色）。

    把 RebaseToken 和对应的 TokenPool 注册到 TokenAdminRegistry。

3.配置跨链桥接关系

    configureTokenPool：让两个链的池子互相认识（告诉源链的池子目标链的地址，反之亦然）。

4.桥接代币

bridgeTokens：模拟用户从本地链把 RebaseToken 桥到远程链。

    用户 approve 路由器（router）销毁代币。

    生成 CCIP 跨链消息（Client.EVM2AnyMessage）。

    支付 LINK 作为 CCIP 手续费。

    调用 ccipSend 把代币桥出。

    在测试中使用 switchChainAndRouteMessage 把消息送到目标链。

5.测试用例

    testBridgeAllTokens：存 ETH → 获得 RebaseToken → 桥接全部代币 → 检查余额正确。

    testBridgeAllTokensBack：桥接到目标链后，再桥接回来，确保余额对得上。

    testBridgeTwice：先桥一半，再桥另一半，再从目标链桥回来，测试多次桥接 & 累积利息是否正确。

🛠 涉及到的 API（大分类）

你不用全都记住，大概知道分工就行了：

Foundry 测试工具（forge-std/Test.sol）

    vm.createFork / vm.selectFork / vm.createSelectFork → 分叉控制

    vm.startPrank / vm.stopPrank → 模拟某个地址发交易

    vm.deal → 给地址转 ETH

    vm.warp → 时间快进

Chainlink CCIP 模拟器（CCIPLocalSimulatorFork）

    getNetworkDetails → 获取链的 router、registry 地址

    requestLinkFromFaucet → 给测试账户发 LINK 用来支付手续费

    switchChainAndRouteMessage → 手动把消息路由到目标链

代币相关（RebaseToken / ERC20 / Vault / TokenPool）

    deposit → 往 Vault 存 ETH 换取 RebaseToken

    grantMintAndBurnRole → 给合约铸造/销毁代币权限

    applyChainUpdates → 设置跨链池子关系

    balanceOf / approve → ERC20 标准方法

跨链消息格式（Client.EVM2AnyMessage）

    receiver → 接收方地址（目标链 Alice）

    tokenAmounts → 跨链转多少代币

    feeToken → 用哪种代币付手续费（这里是 LINK）


*/

// 需要包含的测试用例
// 测试可以桥接代币 - 检查余额是否正确
// 测试可以桥接部分代币 - 检查余额是否正确
// 测试可以桥接然后桥接回全部余额 - 检查余额
// 测试可以桥接然后桥接回部分余额 - 检查余额
contract CrossChainTest is Test {
    address public owner = makeAddr("owner"); // 创建所有者地址
    address alice = makeAddr("alice"); // 创建测试用户 Alice 地址
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork; // CCIP 本地模拟器分叉实例
    uint256 public SEND_VALUE = 1e5; // 发送的 ETH 数量（100,000 wei）

    uint256 sepoliaFork; // Sepolia 测试网分叉 ID
    uint256 arbSepoliaFork; // Arbitrum Sepolia 测试网分叉 ID

    RebaseToken destRebaseToken; // 目标链上的 Rebase 代币合约
    RebaseToken sourceRebaseToken; // 源链上的 Rebase 代币合约

    RebaseTokenPool destPool; // 目标链上的代币池合约
    RebaseTokenPool sourcePool; // 源链上的代币池合约

    TokenAdminRegistry tokenAdminRegistrySepolia; // Sepolia 链上的代币管理员注册表
    TokenAdminRegistry tokenAdminRegistryarbSepolia; // Arbitrum Sepolia 链上的代币管理员注册表

    Register.NetworkDetails sepoliaNetworkDetails; // Sepolia 网络详细信息
    Register.NetworkDetails arbSepoliaNetworkDetails; // Arbitrum Sepolia 网络详细信息

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia; // Sepolia 链上的注册模块所有者自定义合约
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia; // Arbitrum Sepolia 链上的注册模块所有者自定义合约

    Vault vault; // 金库合约，用于存储奖励

    // SourceDeployer sourceDeployer; // 源链部署器（已注释）

    function setUp() public {
        address[] memory allowlist = new address[](0); // 创建空的允许列表

        // sourceDeployer = new SourceDeployer(); // 源链部署器（已注释）

        // 1. 设置 Sepolia 和 Arbitrum 分叉
        sepoliaFork = vm.createSelectFork("eth"); // 创建并选择 Sepolia 分叉
        arbSepoliaFork = vm.createFork("arb"); // 创建 Arbitrum Sepolia 分叉

        //注意：这个做什么？
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); // 创建 CCIP 本地模拟器分叉实例
        vm.makePersistent(address(ccipLocalSimulatorFork)); // 使模拟器地址持久化，避免在分叉切换时丢失

        // 2. 在源链上部署和配置：Sepolia
        //sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // 获取网络详情（已注释）
        //(sourceRebaseToken, sourcePool, vault) = sourceDeployer.run(owner); // 使用部署器运行（已注释）
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // 获取 Sepolia 网络详细信息
        vm.startPrank(owner); // 开始以所有者身份执行
        sourceRebaseToken = new RebaseToken(); // 部署源链 Rebase 代币合约
        console.log("source rebase token address"); // 打印源链 Rebase 代币地址
        console.log(address(sourceRebaseToken)); // 输出源链 Rebase 代币地址
        console.log("Deploying token pool on Sepolia"); // 打印在 Sepolia 上部署代币池
        sourcePool = new RebaseTokenPool( // 部署源链代币池
            IERC20(address(sourceRebaseToken)), // 代币地址
            18, // 本地代币小数位数
            allowlist, // 允许列表
            sepoliaNetworkDetails.rmnProxyAddress, // RMN 代理地址
            sepoliaNetworkDetails.routerAddress // 路由器地址
        );
        // 部署金库
        vault = new Vault(IRebaseToken(address(sourceRebaseToken))); // 部署金库合约
        // 向金库添加奖励
        vm.deal(address(vault), 1e18); // 给金库地址发送 1 ETH 作为奖励
        // 在 Sepolia 上为代币合约设置池的权限
        sourceRebaseToken.grantMintAndBurnRole(address(sourcePool)); // 授予代币池铸造和销毁角色
        sourceRebaseToken.grantMintAndBurnRole(address(vault)); // 授予金库铸造和销毁角色
        // 在 Sepolia 上声明角色
        registryModuleOwnerCustomSepolia =
            RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress); // 获取注册模块所有者自定义合约
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sourceRebaseToken)); // 通过所有者注册管理员
        // 在 Sepolia 上接受角色
        tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress); // 获取代币管理员注册表
        tokenAdminRegistrySepolia.acceptAdminRole(address(sourceRebaseToken)); // 接受代币的管理员角色
        // 在 Sepolia 的代币管理员注册表中将代币链接到池
        tokenAdminRegistrySepolia.setPool(address(sourceRebaseToken), address(sourcePool)); // 设置代币对应的池地址
        vm.stopPrank(); // 停止以所有者身份执行

        // 3. 在目标链上部署和配置：Arbitrum
        // 在 Arbitrum 上部署代币合约
        vm.selectFork(arbSepoliaFork); // 切换到 Arbitrum Sepolia 分叉
        vm.startPrank(owner); // 开始以所有者身份执行
        console.log("Deploying token on Arbitrum"); // 打印在 Arbitrum 上部署代币
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // 获取 Arbitrum Sepolia 网络详细信息
        destRebaseToken = new RebaseToken(); // 部署目标链 Rebase 代币合约
        console.log("dest rebase token address"); // 打印目标链 Rebase 代币地址
        console.log(address(destRebaseToken)); // 输出目标链 Rebase 代币地址
        // 在 Arbitrum 上部署代币池
        console.log("Deploying token pool on Arbitrum"); // 打印在 Arbitrum 上部署代币池
        destPool = new RebaseTokenPool( // 部署目标链代币池
            IERC20(address(destRebaseToken)), // 代币地址
            18, // 本地代币小数位数
            allowlist, // 允许列表
            arbSepoliaNetworkDetails.rmnProxyAddress, // RMN 代理地址
            arbSepoliaNetworkDetails.routerAddress // 路由器地址
        );
        // 在 Arbitrum 上为代币合约设置池的权限
        destRebaseToken.grantMintAndBurnRole(address(destPool)); // 授予代币池铸造和销毁角色
        // 在 Arbitrum 上声明角色
        registryModuleOwnerCustomarbSepolia =
            RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress); // 获取注册模块所有者自定义合约
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(address(destRebaseToken)); // 通过所有者注册管理员
        // 在 Arbitrum 上接受角色
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress); // 获取代币管理员注册表
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(destRebaseToken)); // 接受代币的管理员角色
        // 在 Arbitrum 的代币管理员注册表中将代币链接到池
        tokenAdminRegistryarbSepolia.setPool(address(destRebaseToken), address(destPool)); // 设置代币对应的池地址
        vm.stopPrank(); // 停止以所有者身份执行
    }

    function configureTokenPool( // 配置代币池函数
        uint256 fork, // 分叉 ID
        TokenPool localPool, // 本地代币池
        TokenPool remotePool, // 远程代币池
        IRebaseToken remoteToken, // 远程代币合约
        Register.NetworkDetails memory remoteNetworkDetails // 远程网络详细信息
    ) public {
        vm.selectFork(fork); // 选择指定的分叉
        vm.startPrank(owner); // 开始以所有者身份执行
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1); // 创建链更新数组
        bytes[] memory remotePoolAddresses = new bytes[](1); // 创建远程池地址数组
        remotePoolAddresses[0] = abi.encode(address(remotePool)); // 编码远程池地址
        chains[0] = TokenPool.ChainUpdate({ // 创建链更新结构体
            remoteChainSelector: remoteNetworkDetails.chainSelector, // 远程链选择器
            remotePoolAddresses: remotePoolAddresses, // 远程池地址数组
            remoteTokenAddress: abi.encode(address(remoteToken)), // 编码远程代币地址
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}), // 出站速率限制配置（禁用）
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}) // 入站速率限制配置（禁用）
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0); // 创建要移除的远程链选择器数组（空）
        localPool.applyChainUpdates(remoteChainSelectorsToRemove, chains); // 应用链更新到本地池
        vm.stopPrank(); // 停止以所有者身份执行
    }

    function bridgeTokens( // 桥接代币函数
        uint256 amountToBridge, // 要桥接的代币数量
        uint256 localFork, // 本地分叉 ID
        uint256 remoteFork, // 远程分叉 ID
        Register.NetworkDetails memory localNetworkDetails, // 本地网络详细信息
        Register.NetworkDetails memory remoteNetworkDetails, // 远程网络详细信息
        RebaseToken localToken, // 本地代币合约
        RebaseToken remoteToken // 远程代币合约
    ) public {
        // 创建跨链发送代币的消息
        vm.selectFork(localFork); // 选择本地分叉
        vm.startPrank(alice); // 开始以 Alice 身份执行
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1); // 创建要发送的代币详情数组
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge}); // 创建代币金额结构体
        tokenToSendDetails[0] = tokenAmount; // 设置要发送的代币详情
        // 批准路由器代表用户销毁代币
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge); // 批准路由器使用代币

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({ // 创建跨链消息
            receiver: abi.encode(alice), // 我们需要将地址编码为字节
            data: "", // 这个例子中我们不需要任何数据
            tokenAmounts: tokenToSendDetails, // 这需要是 EVMTokenAmount[] 类型，因为你可以发送多个代币
            extraArgs: "", // 这个例子中我们不需要任何额外参数
            feeToken: localNetworkDetails.linkAddress // 用于支付费用的代币
        });
        // 获取并批准费用
        vm.stopPrank(); // 停止以 Alice 身份执行
        // 给用户提供费用金额的 LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet( // 从水龙头请求 LINK
            alice, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message) // 获取费用
        );
        vm.startPrank(alice); // 重新开始以 Alice 身份执行
        IERC20(localNetworkDetails.linkAddress).approve( // 批准 LINK 费用
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        ); // 批准费用
        // 记录桥接前的余额
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(alice); // 获取桥接前余额
        console.log("Local balance before bridge: %d", balanceBeforeBridge); // 打印桥接前本地余额

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message); // 发送消息
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken)).balanceOf(alice); // 获取桥接后源链余额
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge); // 打印桥接后本地余额
        assertEq(sourceBalanceAfterBridge, balanceBeforeBridge - amountToBridge); // 断言余额正确减少
        vm.stopPrank(); // 停止以 Alice 身份执行

        vm.selectFork(remoteFork); // 选择远程分叉
        // 假设桥接代币需要 15 分钟
        vm.warp(block.timestamp + 900); // 时间快进 15 分钟
        // 获取 Arbitrum 上的初始余额
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(alice); // 获取远程链初始余额
        console.log("Remote balance before bridge: %d", initialArbBalance); // 打印桥接前远程余额
        vm.selectFork(localFork); // 在 chainlink-local 的最新版本中，它假设你在调用 switchChainAndRouteMessage 之前当前在本地分叉上
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork); // 切换链并路由消息

        console.log("Remote user interest rate: %d", remoteToken.getUserInterestRate(alice)); // 打印远程用户利率
        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(alice); // 获取目标链余额
        console.log("Remote balance after bridge: %d", destBalance); // 打印桥接后远程余额
        assertEq(destBalance, initialArbBalance + amountToBridge); // 断言余额正确增加
    }

    function testBridgeAllTokens() public { // 测试桥接所有代币
        configureTokenPool( // 配置代币池
            sepoliaFork, sourcePool, destPool, IRebaseToken(address(destRebaseToken)), arbSepoliaNetworkDetails // Sepolia 到 Arbitrum 的配置
        );
        configureTokenPool( // 配置代币池
            arbSepoliaFork, destPool, sourcePool, IRebaseToken(address(sourceRebaseToken)), sepoliaNetworkDetails // Arbitrum 到 Sepolia 的配置
        );
        // 我们在源链上工作（Sepolia）
        vm.selectFork(sepoliaFork); // 选择 Sepolia 分叉
        // 假设用户正在与协议交互
        // 给用户一些 ETH
        vm.deal(alice, SEND_VALUE); // 给 Alice 发送 ETH
        vm.startPrank(alice); // 开始以 Alice 身份执行
        // 存入金库并接收代币
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}(); // 向金库存入 ETH 并接收代币
        // 桥接代币
        console.log("Bridging %d tokens", SEND_VALUE); // 打印桥接的代币数量
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice); // 获取 Alice 的起始余额
        assertEq(startBalance, SEND_VALUE); // 断言起始余额等于发送值
        vm.stopPrank(); // 停止以 Alice 身份执行
        // 将所有代币桥接到目标链
        bridgeTokens( // 调用桥接代币函数
            SEND_VALUE, // 桥接数量
            sepoliaFork, // 本地分叉
            arbSepoliaFork, // 远程分叉
            sepoliaNetworkDetails, // 本地网络详情
            arbSepoliaNetworkDetails, // 远程网络详情
            sourceRebaseToken, // 本地代币
            destRebaseToken // 远程代币
        );
    }

    function testBridgeAllTokensBack() public { // 测试桥接所有代币并桥接回来
        configureTokenPool( // 配置代币池
            sepoliaFork, sourcePool, destPool, IRebaseToken(address(destRebaseToken)), arbSepoliaNetworkDetails // Sepolia 到 Arbitrum 的配置
        );
        configureTokenPool( // 配置代币池
            arbSepoliaFork, destPool, sourcePool, IRebaseToken(address(sourceRebaseToken)), sepoliaNetworkDetails // Arbitrum 到 Sepolia 的配置
        );
        // 我们在源链上工作（Sepolia）
        vm.selectFork(sepoliaFork); // 选择 Sepolia 分叉
        // 假设用户正在与协议交互
        // 给用户一些 ETH
        vm.deal(alice, SEND_VALUE); // 给 Alice 发送 ETH
        vm.startPrank(alice); // 开始以 Alice 身份执行
        // 存入金库并接收代币
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}(); // 向金库存入 ETH 并接收代币
        // 桥接代币
        console.log("Bridging %d tokens", SEND_VALUE); // 打印桥接的代币数量
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice); // 获取 Alice 的起始余额
        assertEq(startBalance, SEND_VALUE); // 断言起始余额等于发送值
        vm.stopPrank(); // 停止以 Alice 身份执行
        // 将所有代币桥接到目标链
        bridgeTokens( // 调用桥接代币函数
            SEND_VALUE, // 桥接数量
            sepoliaFork, // 本地分叉
            arbSepoliaFork, // 远程分叉
            sepoliaNetworkDetails, // 本地网络详情
            arbSepoliaNetworkDetails, // 远程网络详情
            sourceRebaseToken, // 本地代币
            destRebaseToken // 远程代币
        );
        // 1 小时后将所有代币桥接回源链
        vm.selectFork(arbSepoliaFork); // 选择 Arbitrum Sepolia 分叉
        console.log("User Balance Before Warp: %d", destRebaseToken.balanceOf(alice)); // 打印时间快进前用户余额
        vm.warp(block.timestamp + 3600); // 时间快进 1 小时
        console.log("User Balance After Warp: %d", destRebaseToken.balanceOf(alice)); // 打印时间快进后用户余额
        uint256 destBalance = IERC20(address(destRebaseToken)).balanceOf(alice); // 获取目标链余额
        console.log("Amount bridging back %d tokens ", destBalance); // 打印要桥接回来的代币数量
        bridgeTokens( // 调用桥接代币函数
            destBalance, // 桥接数量（全部余额）
            arbSepoliaFork, // 本地分叉（现在是 Arbitrum）
            sepoliaFork, // 远程分叉（现在是 Sepolia）
            arbSepoliaNetworkDetails, // 本地网络详情
            sepoliaNetworkDetails, // 远程网络详情
            destRebaseToken, // 本地代币
            sourceRebaseToken // 远程代币
        );
    }

    function testBridgeTwice() public { // 测试桥接两次
        configureTokenPool( // 配置代币池
            sepoliaFork, sourcePool, destPool, IRebaseToken(address(destRebaseToken)), arbSepoliaNetworkDetails // Sepolia 到 Arbitrum 的配置
        );
        configureTokenPool( // 配置代币池
            arbSepoliaFork, destPool, sourcePool, IRebaseToken(address(sourceRebaseToken)), sepoliaNetworkDetails // Arbitrum 到 Sepolia 的配置
        );
        // 我们在源链上工作（Sepolia）
        vm.selectFork(sepoliaFork); // 选择 Sepolia 分叉
        // 假设用户正在与协议交互
        // 给用户一些 ETH
        vm.deal(alice, SEND_VALUE); // 给 Alice 发送 ETH
        vm.startPrank(alice); // 开始以 Alice 身份执行
        // 存入金库并接收代币
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}(); // 向金库存入 ETH 并接收代币
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice); // 获取 Alice 的起始余额
        assertEq(startBalance, SEND_VALUE); // 断言起始余额等于发送值
        vm.stopPrank(); // 停止以 Alice 身份执行
        // 将一半代币桥接到目标链
        // 桥接代币
        console.log("Bridging %d tokens (first bridging event)", SEND_VALUE / 2); // 打印第一次桥接的代币数量
        bridgeTokens( // 调用桥接代币函数
            SEND_VALUE / 2, // 桥接数量（一半）
            sepoliaFork, // 本地分叉
            arbSepoliaFork, // 远程分叉
            sepoliaNetworkDetails, // 本地网络详情
            arbSepoliaNetworkDetails, // 远程网络详情
            sourceRebaseToken, // 本地代币
            destRebaseToken // 远程代币
        );
        // 等待 1 小时让利息累积
        vm.selectFork(sepoliaFork); // 选择 Sepolia 分叉
        vm.warp(block.timestamp + 3600); // 时间快进 1 小时
        uint256 newSourceBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice); // 获取新的源链余额
        // 桥接代币
        console.log("Bridging %d tokens (second bridging event)", newSourceBalance); // 打印第二次桥接的代币数量
        bridgeTokens( // 调用桥接代币函数
            newSourceBalance, // 桥接数量（新的余额）
            sepoliaFork, // 本地分叉
            arbSepoliaFork, // 远程分叉
            sepoliaNetworkDetails, // 本地网络详情
            arbSepoliaNetworkDetails, // 远程网络详情
            sourceRebaseToken, // 本地代币
            destRebaseToken // 远程代币
        );
        // 1 小时后将所有代币桥接回源链
        vm.selectFork(arbSepoliaFork); // 选择 Arbitrum Sepolia 分叉
        // 等待一小时让代币在目标链上累积利息
        console.log("User Balance Before Warp: %d", destRebaseToken.balanceOf(alice)); // 打印时间快进前用户余额
        vm.warp(block.timestamp + 3600); // 时间快进 1 小时
        console.log("User Balance After Warp: %d", destRebaseToken.balanceOf(alice)); // 打印时间快进后用户余额
        uint256 destBalance = IERC20(address(destRebaseToken)).balanceOf(alice); // 获取目标链余额
        console.log("Amount bridging back %d tokens ", destBalance); // 打印要桥接回来的代币数量
        bridgeTokens( // 调用桥接代币函数
            destBalance, // 桥接数量（全部余额）
            arbSepoliaFork, // 本地分叉（现在是 Arbitrum）
            sepoliaFork, // 远程分叉（现在是 Sepolia）
            arbSepoliaNetworkDetails, // 本地网络详情
            sepoliaNetworkDetails, // 远程网络详情
            destRebaseToken, // 本地代币
            sourceRebaseToken // 远程代币
        );
    }
}