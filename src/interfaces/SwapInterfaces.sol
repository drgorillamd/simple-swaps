pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMooniswap {
    function swap(
        IERC20 src,
        IERC20 dst,
        uint256 amount,
        uint256 minReturn,
        address referral
    ) external payable returns (uint256 result);

    function getReturn(
        IERC20 src,
        IERC20 dst,
        uint256 amount
    ) external view returns (uint256);
}

interface ICurve {
    function coins(uint256 idx) external returns (address token);

    // quote a swap of an amount _dx of token index i for token index j
    function get_dy(
        int128 i,
        int128 j,
        uint256 _dx
    ) external returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy
    ) external payable returns (uint256);
}

interface IWETH9 is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}
