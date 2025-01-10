// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "../../src/interfaces/IERC20.sol";

contract MockUniswapV2Router {
    mapping(bytes32 => uint256) private configuredOutputs;
    bool public enforceSlippage = true;

    function setAmountOut(address tokenIn, address tokenOut, uint256 amountOut) external {
        configuredOutputs[_routeKey(tokenIn, tokenOut)] = amountOut;
    }

    function setEnforceSlippage(bool newValue) external {
        enforceSlippage = newValue;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external returns (uint256[] memory amounts) {
        require(path.length == 2, "MockRouter: only two step routes supported");
        bytes32 key = _routeKey(path[0], path[1]);
        uint256 amountOut = configuredOutputs[key];
        if (enforceSlippage) {
            require(amountOut >= amountOutMin, "MockRouter: insufficient output configured");
        }

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).transfer(to, amountOut);

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    function _routeKey(address tokenIn, address tokenOut) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenIn, tokenOut));
    }
}
