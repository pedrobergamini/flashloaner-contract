pragma solidity ^0.8.24;

import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "./interfaces/IERC20.sol";

contract FlashLoaner is IUniswapV2Callee {
    address public immutable factory;
    IUniswapV2Router02 public immutable altRouter;

    struct FlashParams {
        address profitReceiver;
        uint256 minProfit;
    }

    constructor(address _factory, address _altRouter) {
        require(_factory != address(0) && _altRouter != address(0), "Zero");
        factory = _factory;
        altRouter = IUniswapV2Router02(_altRouter);
    }

    function flashSwap(address pair, uint256 amount0Out, uint256 amount1Out, address profitReceiver, uint256 minProfit)
        external
    {
        require(pair != address(0), "pair zero");
        IUniswapV2Pair(pair).swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(FlashParams({profitReceiver: profitReceiver, minProfit: minProfit}))
        );
    }

    function uniswapV2Call(address, /* sender */ uint256 amount0, uint256 amount1, bytes calldata data)
        external
        override
    {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        // Validate caller is the canonical pair
        require(msg.sender == UniswapV2Library.pairFor(factory, token0, token1), "Unauthorized");
        require(amount0 == 0 || amount1 == 0, "one side only");

        FlashParams memory params = abi.decode(data, (FlashParams));

        bool borrowedToken0 = amount0 > 0;
        uint256 amountBorrowed = borrowedToken0 ? amount0 : amount1;
        address borrowedToken = borrowedToken0 ? token0 : token1;
        address otherToken = borrowedToken0 ? token1 : token0;

        // Compute repayment on the Uniswap factory pair
        address[] memory repayPath = new address[](2);
        repayPath[0] = otherToken;
        repayPath[1] = borrowedToken;
        uint256 amountToRepay = UniswapV2Library.getAmountsIn(factory, amountBorrowed, repayPath)[0];

        // Swap the borrowed tokens on altRouter into the other token to repay the pair
        IERC20(borrowedToken).approve(address(altRouter), amountBorrowed);
        address[] memory swapPath = new address[](2);
        swapPath[0] = borrowedToken;
        swapPath[1] = otherToken;
        uint256 deadline = block.timestamp + 1 hours;
        uint256[] memory amounts =
            altRouter.swapExactTokensForTokens(amountBorrowed, amountToRepay, swapPath, address(this), deadline);
        uint256 amountOut = amounts[1];
        require(amountOut >= amountToRepay, "insufficient out");

        // Repay the pair in the other token
        IERC20(otherToken).transfer(msg.sender, amountToRepay);

        // Send profit to receiver
        uint256 profit = amountOut - amountToRepay;
        require(profit >= params.minProfit, "min profit not met");
        if (profit > 0) {
            IERC20(otherToken).transfer(params.profitReceiver, profit);
        }
    }
}
