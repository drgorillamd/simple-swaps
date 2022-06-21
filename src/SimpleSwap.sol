// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "interfaces/SwapInterfaces.sol";

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
        @param minOut the minimum amount of tokenOut to receive
    */
    function swapUniV2(
        IERC20 tokenIn,
        IERC20 tokenOut,
        IUniswapV2Pair pool,
        uint256 amountIn,
        uint256 minOut,
    ) external payable {
        (uint256 reserve0, uint256 reserve1, ) = getReserves();

        bool tokenInIsZero = tokenIn < tokenOut;

        (uint256 reserveIn, uint256 reserveOut) = tokenInIsZero
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;

        if(minOut < amountOut) revert SimpleSwap_MaxSlippage();

        if(msg.value != 0) {
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
        @dev ETH is address(0)

        @dev
        needs approval is erc20
    */
    function swapMooniswap(
        IERC20 tokenIn,
        IERC20 tokenOut,
        IMooniswap pool,
        uint256 amountIn,
        uint256 minOut,
        uint256 maxSlippage
    ) external payable {
        if (tokenIn == address(0)) exactIn = msg.value;
        else {
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenIn.approve(address(pool), amountIn);
        }

        uint256 amountOut = pool.swap{value: msg.value}(
            tokenIn,
            tokenOut,
            amountIn,
            minOut,
            address(msg.sender)
        );

        tokenOut.transfer(msg.sender, amountOut);
    }

    function swapCurve(
        IERC20 tokenIn,
        IERC20 tokenOut,
        ICurve curvePool,
        uint256 amountIn,
        uint256 minAmountOut
    ) external payable {
        if (msg.value != 0)
            tokenIn = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;
        else {
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenIn.approve(address(curvePool), amountIn);
        }

        int128 i = curvePool.coins(0) == tokenIn ? 0 : 1;
        int128 j = i == 1 ? 0 : 1;

        uint256 amountOut = curvePool.exchange{value: msg.value}(i, j, amountIn, minAmountOut);

        tokenOut.transfer(msg.sender, amountOut);
    }

    function swapUniV3() external {}
}
