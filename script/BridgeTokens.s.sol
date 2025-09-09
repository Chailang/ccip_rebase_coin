// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(
        address receiverAddress, //目标链上的接收地址
        uint64 destinationChainSelector,//目标链的标识符（CCIP 用）
        address tokenToSendAddress, //要发送的 ERC20 代币合约地址
        uint256 amountToSend,//要发送的代币数量
        address linkTokenAddress, // 支付跨链费用的 LINK 代币地址
        address routerAddress // CCIP Router 合约地址
    ) public {
        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains 
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        // }

        // 1.构造要发送的代币列表
        //CCIP 可以同时发送多个代币，这里只发送一个代币。
        //EVMTokenAmount 包含代币地址和数量。
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSendAddress, amount: amountToSend});
        vm.startBroadcast();
        //2.构造跨链消息 EVM2AnyMessage
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),// 目标链接收地址
            data: "", // 跨链调用的数据 payload，这里为空。
            tokenAmounts: tokenAmounts, // 要发送的代币列表
            feeToken: linkTokenAddress, // 支付跨链费用的代币地址
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) //可选参数，这里只设置了 gasLimit。
        });
        //3.获取跨链手续费并授权

        //调用 getFee 获取当前消息跨链所需的 LINK 手续费。
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        // 给 Router 授权两笔：一笔支付跨链手续费，一笔转移要发送的代币。
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        //调用跨链发送 真正发起跨链交易。
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    }
}