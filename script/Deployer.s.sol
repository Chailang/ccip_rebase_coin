// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CCIPLocalSimulatorFork,Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

/*
注意点

CCIP 模拟器：

    这个脚本依赖 CCIPLocalSimulatorFork，你需要在 Foundry 环境中有对应的本地库。

    部署时确保 @chainlink/local 的路径正确。

权限管理：

    grantMintAndBurnRole 是关键操作，保证只有 Pool 和 Vault 能修改 token 总量。

广播与 Foundry：

    vm.startBroadcast() / vm.stopBroadcast() 是 Foundry 脚本特有的写法，不是标准 Solidity。

多链模拟：
    networkDetails.rmnProxyAddress 和 networkDetails.routerAddress 是跨链模拟必须的。

    如果你想在真实链上部署，需要替换为正式地址。

*/
contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        //这里初始化了一个 本地 CCIP 模拟器，用来模拟跨链环境。
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        token = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(token)), 
            18, 
            new address[](0), 
            networkDetails.rmnProxyAddress, 
            networkDetails.routerAddress
        );
        //给 pool 授权 铸币和销毁 RebaseToken 的权限。 RebaseToken 的设计里，一般只有池子或 Vault 有权操作供应量。
        token.grantMintAndBurnRole(address(pool));

        //Token 的注册与管理员角色的配置：
        //1.通过 Registry 模块注册 token。
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(token));
        //2. Token 管理员角色被激活。
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        //3. 将 token 和 pool 关联起来。
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        //并把它赋予 铸币和销毁权限。
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}