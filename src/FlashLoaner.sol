// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {UniswapV2Library} from "./libraries/UniswapV2Library.sol";

contract FlashLoaner {
    error UnauthorizedPair(address caller);
    error InvalidAmounts();
    error InsufficientProceeds(uint256 received, uint256 required);

    event LoanExecuted(
        address indexed pair,
        address indexed initiator,
        address indexed borrowedToken,
        address repaymentToken,
        uint256 amountBorrowed,
        uint256 amountRequired,
        uint256 profit
    );

    address public immutable factory;
    IUniswapV2Router02 public immutable router;

    constructor(address factory_, address router_) {
        if (factory_ == address(0) || router_ == address(0)) {
            revert("FlashLoaner: zero address");
        }
        factory = factory_;
        router = IUniswapV2Router02(router_);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata)
        external
    {
        if (amount0 != 0 && amount1 != 0) revert InvalidAmounts();

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        if (msg.sender != UniswapV2Library.pairFor(factory, token0, token1)) {
            revert UnauthorizedPair(msg.sender);
        }

        bool isBorrowingToken0 = amount0 != 0;
        uint256 amountBorrowed = isBorrowingToken0 ? amount0 : amount1;
        address borrowedToken = isBorrowingToken0 ? token0 : token1;
        address repaymentToken = isBorrowingToken0 ? token1 : token0;

        address[] memory path = new address[](2);
        path[0] = borrowedToken;
        path[1] = repaymentToken;

        IERC20(borrowedToken).approve(address(router), amountBorrowed);

        uint256 amountRequired = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];
        uint256 amountReceived = router.swapExactTokensForTokens(
            amountBorrowed, amountRequired, path, address(this), block.timestamp + 1 hours
        )[1];

        if (amountReceived < amountRequired) {
            revert InsufficientProceeds(amountReceived, amountRequired);
        }

        IERC20(repaymentToken).transfer(msg.sender, amountRequired);

        uint256 profit = amountReceived - amountRequired;
        if (profit > 0) IERC20(repaymentToken).transfer(sender, profit);

        emit LoanExecuted(
            msg.sender,
            sender,
            borrowedToken,
            repaymentToken,
            amountBorrowed,
            amountRequired,
            profit
        );
    }
}
