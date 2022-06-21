// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/SwapInterfaces.sol";

/**
    @notice
    Provide simple exact input amount swap to uniswap v2, v3, Curve, Mooniswap.

    @dev
    This is a light proxy to be able to use with large multisig. LOTS of check needs to be done before sending
    the transaction (not passing msg.value and an erc20 token in for instance)
*/
contract SimpleSwap {
    /**
        @dev throws if the amount received is too low
    */
    error SimpleSwap_MaxSlippage();

    IWETH9 public weth;

    constructor(IWETH9 _weth) {
        weth = _weth;
    }

    /**
        @notice
        Provide compatibility with any Uniswap v2-clone

        @dev
        If tokenIn is 

        @param tokenIn the address of the token to swap
        @param tokenOut the address of the token to receive
        @param pool the pool address
        @param amountIn the amount to swap - will be overriden by msg.value if non-0
        @param minAmountOut the minimum amount of tokenOut to receive
    */
    function swapUniV2(
        IERC20 tokenIn,
        IERC20 tokenOut,
        IUniswapV2Pair pool,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable {
        (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();

        bool tokenInIsZero = tokenIn < tokenOut;

        (uint256 reserveIn, uint256 reserveOut) = tokenInIsZero
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        if (minAmountOut < amountOut) revert SimpleSwap_MaxSlippage();

        if (msg.value != 0) {
            amountIn = msg.value;
            weth.deposit{value: amountIn}();
            tokenIn = IERC20(weth);
        }

        tokenIn.transfer(address(pool), amountIn);

        pool.swap(
            tokenInIsZero ? 0 : amountOut,
            tokenInIsZero ? amountOut : 0,
            msg.sender,
            new bytes(0)
        );
    }

    /**
        @notice
        Provide compatibility with 1-inch Mooniswap pools

        @dev ERC20 needs to approve this contract first

        @param tokenIn the address of the token to swap
        @param tokenOut the address of the token to receive
        @param pool the pool address
        @param amountIn the amount to swap, needs to be msg.value is ETH is swapped
        @param minAmountOut the minimum amount of tokenOut to receive
    */
    function swapMooniswap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        IMooniswap pool,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable {
        if (msg.value != 0) {
            amountIn = msg.value;
            tokenIn = IERC20(address(0));
        } else {
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenIn.approve(address(pool), amountIn);
        }

        uint256 amountOut = pool.swap{value: amountIn}(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            address(msg.sender)
        );

        tokenOut.transfer(msg.sender, amountOut);
    }

    /**
        @notice
        Provide compatibility with Curve stableswap pools

        @dev ERC20 needs to approve this contract first

        @param tokenIn the address of the token to swap
        @param tokenOut the address of the token to receive
        @param pool the pool address
        @param amountIn the amount to swap, needs to be msg.value is ETH is swapped
        @param minAmountOut the minimum amount of tokenOut to receive
    */
    function swapCurve(
        IERC20 tokenIn,
        IERC20 tokenOut,
        ICurve pool,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable {
        if (msg.value != 0) {
            tokenIn = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
            amountIn = msg.value;
        } else {
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenIn.approve(address(pool), amountIn);
        }

        int128 i = pool.coins(0) == address(tokenIn) ? int128(0) : int128(1);
        int128 j = i == 1 ? int128(0) : int128(1);

        uint256 amountOut = pool.exchange{value: amountIn}(
            i,
            j,
            amountIn,
            minAmountOut
        );

        tokenOut.transfer(msg.sender, amountOut);
    }

    function swapUniV3() external {}
}
