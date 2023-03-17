// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@layerzerolabs/contracts/contracts/app/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract DestinationChainUA is NonblockingLzApp {
    address private _uniswapRouter;
    address private _syAsset;
    address private _nativeAsset;

    constructor(
        address layerzero,
        address uniswapRouter,
        address syAsset,
        address nativeAsset
    ) NonblockingLzApp(layerzero) {
        _uniswapRouter = uniswapRouter;
        _syAsset = syAsset;
        _nativeAsset = nativeAsset;
    }

    function _nonblockingLzReceive(bytes memory data) internal override {
        // Decode the received data
        (address sender, uint256 amountIn, uint256 amountOutMin, address[] memory path) = abi.decode(data, (address, uint256, uint256, address[]));

        // Approve Uniswap to spend the syAsset
        IERC20(_syAsset).approve(_uniswapRouter, amountIn);

        // Swap the syAsset for the native asset
        ISwapRouter(_uniswapRouter).exactInput(
            ISwapRouter.ExactInputParams({
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                path: path,
                recipient: sender,
                deadline: block.timestamp + 300 // 5 minutes from the current block timestamp
            })
        );
    }
}
