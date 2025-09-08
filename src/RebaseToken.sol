// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
* @title RebaseToken
* @author Ciara Nightingale
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* 这是一个跨链 rebase 代币，激励用户向金库存款并获得奖励利息。
* @notice The interest rate in the smart contract can only decrease 
* 智能合约中的利率只能下降
* @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
* 每个用户都将拥有自己的利率，该利率是存款时的全局利率。
*/
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 newInterestRate);

    /////////////////////
    // State Variables // 状态变量
    /////////////////////

    uint256 private constant PRECISION_FACTOR = 1e18; // Used to handle fixed-point calculations // 用于处理定点计算
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE"); // Role for minting and burning tokens (the pool and vault contracts) // 铸造和销毁代币的角色(池和保险库合约)
    mapping(address => uint256) private s_userInterestRate; // Keeps track of the interest rate of the user at the time they last deposited, bridged or were transferred tokens. // 跟踪用户在最后一次存款、跨链或转账时的利率
    mapping(address => uint256) private s_userLastUpdatedTimestamp; // the last time a user balance was updated to mint accrued interest. // 用户余额最后一次更新以铸造累积利息的时间
    uint256 private s_interestRate = 5e10; // this is the global interest rate of the token - when users mint (or receive tokens via transferral), this is the interest rate they will get. // 这是代币的全局利率 - 当用户铸造(或通过转账接收代币)时，这就是他们将获得的利率

    /////////////////////
    // Events // 事件
    /////////////////////
    event InterestRateSet(uint256 newInterestRate);

    /////////////////////
    // Constructor // 构造函数
    /////////////////////

    constructor() Ownable(msg.sender) ERC20("RebaseToken", "RBT") {}

    /////////////////////
    // Functions // 函数
    /////////////////////

    /**
     * @dev grants the mint and burn role to an address. This is only called by the protocol owner.
     * 授予地址铸造和销毁的角色。这只能由协议所有者调用。
     * @param _address the address to grant the role to
     * 要授予角色的地址
     */
    function grantMintAndBurnRole(address _address) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _address);
    }

    /**
     * @notice Set the interest rate in the contract
     * 设置合约中的利率
     * @param _newInterestRate The new interest rate to set
     * 要设置的新利率
     * @dev The interest rate can only decrease
     * 利率只能下降
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @dev returns the principal balance of the user. The principal balance is the last
     * updated stored balance, which does not consider the perpetually accruing interest that has not yet been minted.
     * 返回用户的本金余额。本金余额是最后更新的存储余额，不考虑尚未铸造的永久累积利息。
     * @param _user the address of the user
     * 用户的地址
     * @return the principal balance of the user
     * 返回用户的本金余额
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /// @notice Mints new tokens for a given address. Called when a user either deposits or bridges tokens to this chain.
    /// 为指定地址铸造新代币。当用户存款或跨链转移代币到此链时调用。
    /// @param _to The address to mint the tokens to.
    /// 接收铸造代币的地址
    /// @param _value The number of tokens to mint.
    /// 要铸造的代币数量
    /// @param _userInterestRate The interest rate of the user. This is either the contract interest rate if the user is depositing or the user's interest rate from the source token if the user is bridging.
    /// 用户的利率。如果用户是存款，则为合约利率；如果用户是跨链，则为源代币的用户利率。
    /// @dev this function increases the total supply.
    /// 此函数增加总供应量
    function mint(address _to, uint256 _value, uint256 _userInterestRate) public onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _value);
    }

    /// @notice Burns tokens from the sender.
    /// 从发送者处销毁代币
    /// @param _from The address to burn the tokens from.
    /// 要销毁代币的地址
    /// @param _value The number of tokens to be burned
    /// 要销毁的代币数量
    /// @dev this function decreases the total supply.
    /// 此函数减少总供应量
    function burn(address _from, uint256 _value) public onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _value);
    }

    /**
     * @dev calculates the balance of the user, which is the
     * principal balance + interest generated by the principal balance
     * 计算用户的余额，即本金余额 + 本金余额产生的利息
     * @param _user the user for which the balance is being calculated
     * 要计算余额的用户
     * @return the total balance of the user
     * 返回用户的总余额
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 currentPrincipalBalance = super.balanceOf(_user);
        if (currentPrincipalBalance == 0) {
            return 0;
        }
        return (currentPrincipalBalance * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
    }

    /**
     * @dev transfers tokens from the sender to the recipient. This function also mints any accrued interest since the last time the user's balance was updated.
     * 从发送者向接收者转移代币。此函数还铸造自上次用户余额更新以来的所有应计利息。
     * @param _recipient the address of the recipient
     * 接收者的地址
     * @param _amount the amount of tokens to transfer
     * 要转移的代币数量
     * @return true if the transfer was successful
     * 如果转账成功则返回true
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @dev transfers tokens from the sender to the recipient. This function also mints any accrued interest since the last time the user's balance was updated.
     * 从发送者向接收者转移代币。此函数还铸造自上次用户余额更新以来的所有应计利息。
     * @param _sender the address of the sender
     * 发送者的地址
     * @param _recipient the address of the recipient
     * 接收者的地址 
     * @param _amount the amount of tokens to transfer
     * 要转移的代币数量
     * @return true if the transfer was successful
     * 如果转账成功则返回true
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        // 如果传入的是 uint256 最大值，代表转账全部余额
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        // 先把发送方和接收方的利息累计到本金
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
         // 如果接收方当前余额为0，则继承发送方利率
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        // 调用 ERC20 的 transfer 实现实际转账
        return super.transferFrom(_sender, _recipient, _amount);
        /**
         * 以 Alice 给 Bob 转账 500 举例：

        _mintAccruedInterest(Alice)

        把 Alice 账户未铸造利息 mint 出来
        假设 Alice 本金 1000 + 利息 50 → 本金更新为 1050

        _mintAccruedInterest(Bob)

        把 Bob 账户未铸造利息 mint 出来
        假设 Bob 本金 200 + 利息 20 → 本金更新为 220


        super.transfer(Bob, 500)

        实际转账 500 本金（包含 Alice 已累积利息）
        转账完成后，Alice 本金 = 1050 - 500 = 550
        Bob 本金 = 220 + 500 = 720
         * 
        */
    }

    /**
     * @dev returns the interest accrued since the last update of the user's balance - aka since the last time the interest accrued was minted to the user.
     * 返回自用户余额最后更新以来的应计利息 - 即自上次利息铸造给用户以来的利息。
     * @return linearInterest the interest accrued since the last update
     * 返回自上次更新以来的应计利息
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeDifference = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = (s_userInterestRate[_user] * timeDifference) + PRECISION_FACTOR;
    }

    /**
     * @dev accumulates the accrued interest of the user to the principal balance. This function mints the users accrued interest since they last transferred or bridged tokens.
     * 将用户的应计利息累积到本金余额中。此函数铸造用户自上次转账或跨链以来的应计利息。
     * @param _user the address of the user for which the interest is being minted
     * 要铸造利息的用户地址
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        _mint(_user, balanceIncrease);
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @dev returns the global interest rate of the token for future depositors
     * 返回代币对未来存款人的全局利率
     * @return s_interestRate
     * 返回利率
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @dev returns the interest rate of the user
     * 返回用户的利率
     * @param _user the address of the user
     * 用户的地址
     * @return s_userInterestRate[_user] the interest rate of the user
     * 返回用户的利率
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}