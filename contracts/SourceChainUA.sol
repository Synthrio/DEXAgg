// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@layerzero/core/contracts/interfaces/ILayerZero.sol";
import "@layerzero/core/contracts/base/NonblockingLzApp.sol";

contract SourceChainUA is NonblockingLzApp {
    address private constant UNISWAP_ROUTER_ADDRESS = 0x...; // Uniswap router address
    address private constant DESTINATION_UA_ADDRESS = 0x...; // DestinationChainUA contract address
    ILayerZero private layerZero;

    constructor(ILayerZero _layerZero) NonblockingLzApp(_layerZero) {
        layerZero = _layerZero;
    }

    function swapToSyAsset(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external {
        ISwapRouter uniswapRouter = ISwapRouter(UNISWAP_ROUTER_ADDRESS);

        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        uniswapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: to,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function crossChainSwap(bytes32 destinationChainId, bytes memory data) external {
        bytes memory payload = abi.encodeWithSignature("_nonblockingLzReceive(bytes)", data);
        uint256 nonce = _lzSend(destinationChainId, DESTINATION_UA_ADDRESS, payload);
    }

    function _nonblockingLzReceive(bytes memory data) internal override {
        // This function intentionally left empty, as it's not needed for the SourceChainUA contract
    }
}
