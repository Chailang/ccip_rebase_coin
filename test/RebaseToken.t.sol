// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console, Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

// Foundry 的测试规则：
// 任何带有随机输入参数的测试函数都会被视为模糊测试
// 不需要特定的命名约定（比如 testFuzz_）
// Foundry 会自动对这些参数进行多次随机取值测试

/**
 * @title RebaseToken 测试合约
 * @notice 本合约包含了 RebaseToken 和 Vault 合约的测试用例
 */
contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    // 测试账户和常量设置
    address public user = makeAddr("user");
    address public owner = makeAddr("owner");
    uint256 public SEND_VALUE = 1e5;

    /**
     * @notice 向 Vault 添加奖励
     * @dev 通过 receive 函数向 vault 发送 ETH
     */
    function addRewardsToVault(uint256 amount) public {
        payable(address(vault)).call{value: amount}("");
        // 向 vault 直接发送 ETH（空 calldata），触发 Vault 的 receive()，模拟收益注入。
        // 用 address(vault).call{value: amount}("") 的形式，忽略返回值，用于测试时喂资金。
    }

    /**
     * @notice 测试前的设置
     * @dev 部署合约并授予权限
     */
    function setUp() public {
        // 把后续所有外部调用伪装成 owner 发起（直到 stopPrank）。
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        //赋予 vault 铸造/销毁权限（grantMintAndBurnRole），符合系统设计（只有金库可 mint/burn）。
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    /**
     * @notice 测试线性存款和利息增长
     * @dev 验证存款后余额随时间线性增长
     */
    function testDepositLinear(uint256 amount) public {
        // 限制存款金额范围
        amount = bound(amount, 1e5, type(uint96).max);
        
        // 1. 存款
        vm.startPrank(user);
        //用 vm.deal 给 user 发 ETH，
        vm.deal(user, amount);
        //然后以 user 身份往金库 deposit
        vault.deposit{value: amount}();
        
        // 2. 检查初始 rebase token 余额
        // 初始余额应等于存入金额（没有时间流逝前利息≈0）。
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        
        // 3. 时间推进并检查余额增长
        //往后挪 1 小时（warp 修改 block.timestamp），余额应增大（线性计息）。
        vm.warp(block.timestamp + 1 hours);
        console.log("block.timestamp", block.timestamp);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        
        // 4. 再次时间推进并验证线性增长
        // 再挪 1 小时，余额继续增长
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("endBalance", endBalance);
        assertGt(endBalance, middleBalance);

        // 验证两个时间段的增长量相等（允许误差为1）
        //验证相同时间间隔内的增量基本相等（线性增长），允许 1 wei 绝对误差。
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    /**
     * @notice 测试立即赎回功能
     * @dev 验证存款后立即赎回的场景
     */
    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        
        // 存款
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // 立即赎回
        vault.redeem(amount);

        // 验证余额为0
        uint256 balance = rebaseToken.balanceOf(user);
        console.log("User balance: %d", balance);
        assertEq(balance, 0);
        vm.stopPrank();
    }
    /**
     * @notice 有收益时的赎回，测试经过一段时间后的赎回功能
     * @dev 验证存款后经过时间流逝再赎回的场景
     */
    function testRedeemAfterTimeHasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // this is an Ether value of max 2^78 which is crazy

        // Deposit funds 充值
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // check the balance has increased after some time has passed 过了一段时间后，检查余额是否增加
        vm.warp(time);

        // Get balance after time has passed 经过时间流逝后的余额
        uint256 balance = rebaseToken.balanceOf(user);

        // Add rewards to the vault 给金库添加奖励
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);

        // Redeem funds 赎回资金
        vm.prank(user);
        vault.redeem(balance);

        uint256 ethBalance = address(user).balance;

        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }
    /**
     * @notice 测试无法直接调用 mint
     * @dev 验证权限控制，确保只有 Vault 能调用 mint
     */
    function testCannotCallMint() public {
        // Deposit funds
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectRevert();
        rebaseToken.mint(user, SEND_VALUE, interestRate);
        vm.stopPrank();
    }
    /**
     * @notice 测试无法直接调用 burn
     * @dev 验证权限控制，确保只有 Vault 能调用 burn
     */
    function testCannotCallBurn() public {
        // Deposit funds
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, SEND_VALUE);
        vm.stopPrank();
    }
    /**
     * @notice 测试无法赎回超出余额的金额
     * @dev 验证赎回金额超过余额时的错误处理
     */
    function testCannotWithdrawMoreThanBalance() public {
        // Deposit funds
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 1e3, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
    }
    /**
     * @notice 测试转账功能
     * @dev 验证转账后余额和利率的正确性
     */
    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address userTwo = makeAddr("userTwo");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 userTwoBalance = rebaseToken.balanceOf(userTwo);
        assertEq(userBalance, amount);
        assertEq(userTwoBalance, 0);

        // Update the interest rate so we can check the user interest rates are different after transferring.
        // 中途更新利率，以验证转账后用户利率的继承情况。
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // Send half the balance to another user
        // 把一半余额转给另一个用户
        vm.prank(user);
        rebaseToken.transfer(userTwo, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 userTwoBalancAfterTransfer = rebaseToken.balanceOf(userTwo);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(userTwoBalancAfterTransfer, userTwoBalance + amountToSend);
        // After some time has passed, check the balance of the two users has increased
        // 过了一段时间后，检查两个用户的余额是否增加
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(userTwo);
        // check their interest rates are as expected
        // 检查他们的利率是否符合预期
        // since user two hadn't minted before, their interest rate should be the same as in the contract
        // userTwo 之前没有 mint 过，所以他们的利率应该和合约中的利率相同
        uint256 userTwoInterestRate = rebaseToken.getUserInterestRate(userTwo);
        assertEq(userTwoInterestRate, 5e10);
        // since user had minted before, their interest rate should be the previous interest rate
        // user 之前 mint 过，所以他们的利率应该是之前的利率
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(userTwoBalanceAfterWarp, userTwoBalancAfterTransfer);
    }
    /**
     * @notice 测试所有者设置利率
     * @dev 验证利率更新和用户利率继承
     */
    function testSetInterestRate(uint256 newInterestRate) public {
        // bound the interest rate to be less than the current interest rate
        // 把利率限定在当前利率以下
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getInterestRate() - 1);
        // Update the interest rate
        // 更新利率
        vm.startPrank(owner);
        rebaseToken.setInterestRate(newInterestRate);
        uint256 interestRate = rebaseToken.getInterestRate();
        assertEq(interestRate, newInterestRate);
        vm.stopPrank();

        // check that if someone deposits, this is their new interest rate
        // 检查如果有人存款，他们的新利率是否正确
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        vm.stopPrank();
        assertEq(userInterestRate, newInterestRate);
    }
    /**
     * @notice 测试非所有者无法设置利率
     * @dev 验证权限控制
     */
    function testCannotSetInterestRate(uint256 newInterestRate) public {
        // Update the interest rate
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }
    /**
     * @notice 测试利率只能降低
     * @dev 验证提高利率时的错误处理
     */
    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    /**
     * @notice 测试获取本金金额
     * @dev 验证本金金额在时间推移后保持不变
     */
    function testGetPrincipleAmount() public {
        uint256 amount = 1e5;
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmount, amount);

        // 验证时间推移后本金不变
        vm.warp(block.timestamp + 1 days);
        uint256 principleAmountAfterWarp = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmountAfterWarp, amount);
    }
}