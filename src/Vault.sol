// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IRebaseToken.sol";
/**
 * @title Vault contract 金库
 * @author Cyfrin
 * @notice This contract is used to deposit and redeem the underlying asset
 * @dev This contract interacts with the RebaseToken contract
 * Vault（金库）合约是一个存储和赎回系统，并与 RebaseToken 合约交互。
 * 用户存入 ETH，铸造 RebaseToken
 * 用户赎回 RebaseToken，销毁 RebaseToken，返还 ETH
 */
contract Vault {
    IRebaseToken public immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    // allows the contract to receive rewards
    receive() external payable {}
    
  
    /**
     * @dev deposits the underlying asset and mints rebase token
     * The amount of rebase token minted is based on the current interest rate
     * @notice 用户存入 ETH，铸造 RebaseToken
     * 用户 → 发送 ETH → Vault
     * Vault → 调用 RebaseToken.mint() → 给用户铸造代币
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev redeems rebase token for the underlying asset
     * @param _amount the amount being redeemed
     * @notice 用户赎回 RebaseToken，销毁 RebaseToken，返还 ETH
     * 用户 → 请求赎回 RebaseToken
     * Vault → 调用 RebaseToken.burn() → 销毁代币
     * Vault → 向用户发送对应的 ETH
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        // executes redeem of the underlying asset
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }
}