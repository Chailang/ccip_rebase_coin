// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
//用于配置 Chainlink CCIP 的跨链 TokenPool 的参数
// 它不发送代币，而是管理和设置跨链代币池（TokenPool）的行为
// 配置本链 TokenPool 的跨链连接与速率限制：
// 将本地池与远程池、远程代币关联。
// 设置 发送/接收的速率限制（防止过快发送导致链上拥堵或安全风险）。
// 让 TokenPool 可以安全、可控地支持跨链转账。
contract ConfigurePoolScript is Script {
    function run(
        address localPool, // 本地 TokenPool 合约地址
        uint64 remoteChainSelector, // 远程链的标识符（CCIP 用）
        address remotePool, // 远程 TokenPool 合约地址
        address remoteToken, // 远程链上对应的代币合约地址
        bool outboundRateLimiterIsEnabled, // 是否启用出站速率限制
        uint128 outboundRateLimiterCapacity, // 出站速率限制的容量
        uint128 outboundRateLimiterRate, // 出站速率限制的速率
        bool inboundRateLimiterIsEnabled, // 是否启用入站速率限制
        uint128 inboundRateLimiterCapacity, // 入站速率限制的容量
        uint128 inboundRateLimiterRate // 入站速率限制的速率
    ) public {
        vm.startBroadcast();// 开始广播交易
        // 1. 构造链更新信息
        // CCIP 的 TokenPool 支持多个远程池，这里只设置了一个。    
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        //定义了远程链的池信息和速率限制。
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector, // 远程链选择器
            remotePoolAddresses: remotePoolAddresses, // 远程池地址
            remoteTokenAddress: abi.encode(remoteToken), // 远程代币地址
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRateLimiterRate
            }), // 出站速率限制配置
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterIsEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            }) // 入站速率限制配置
        });
        //应用配置
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
        vm.stopBroadcast();
    }
}