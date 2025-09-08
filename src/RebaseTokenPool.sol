// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Pool} from "@chainlink/contracts-ccip/contracts/libraries/Pool.sol";
import "./interfaces/IRebaseToken.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
contract RebaseTokenPool is TokenPool{
    //一个 跨链 Rebase Token 桥接池，让带利息的代币也能通过 CCIP 跨链，而且在跨链后用户的收益不会丢失。
    constructor(IERC20 token, uint8 localTokenDecimals, address[] memory allowlist, address rmnProxy, address router) 
     TokenPool(token, localTokenDecimals, allowlist, rmnProxy, router)
    {   }


    /// @notice burns the tokens on the source chain
    /// 源链上的操作：
    /// 跨链时，不仅传输数量，还要传输「用户利率」这种额外信息，否则目标链 mint 的时候无法还原利息逻辑。
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        virtual
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        //验证请求是否合法（_validateLockOrBurn）。
        _validateLockOrBurn(lockOrBurnIn);
        
        // Burn the tokens on the source chain. This returns their userAccumulatedInterest before the tokens were burned (in case all tokens were burned, we don't want to send 0 cross-chain)
        //调用 IRebaseToken.getUserInterestRate 获取用户的利率（比如 3%/年）。
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        //uint256 currentInterestRate = IRebaseToken(address(i_token)).getInterestRate();
        //在源链上 burn 用户代币（销毁一定数量）。
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        // encode a function call to pass the caller's info to the destination pool and update it
        //将利率信息编码 (abi.encode(userInterestRate)) 并打包到跨链消息里。
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    /// @notice Mints the tokens on the source chain
    //目标链上的操作：
    //保证目标链上重新 mint 出来的代币，既保留了本金数量，又保留了用户在源链上的利息增长逻辑。
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        //验证请求合法
        _validateReleaseOrMint(releaseOrMintIn);
        address receiver = releaseOrMintIn.receiver;
        //从跨链消息里 decode 出用户的利率
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        // Mint rebasing tokens to the receiver on the destination chain
        // This will also mint any interest that has accrued since the last time the user's balance was updated.
        //mint 时会根据用户利率自动把利息补上。
        IRebaseToken(address(i_token)).mint(receiver, releaseOrMintIn.amount, userInterestRate);
        //返回最终用户获得的代币数量。
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}