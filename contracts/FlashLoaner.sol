pragma solidity 0.8.9;

import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

contract FlashLoaner {
    address immutable factory;
    IUniswapV2Router02 immutable sushiRouter;

    constructor(address _factory, address _sushiRouter) {
        factory = _factory;
        sushiRouter = IUniswapV2Router02(_sushiRouter);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata
    ) external {
        address[] memory path = new address[](2);
        uint256 amountToken = _amount0 == 0 ? _amount1 : _amount0;

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        require(
            msg.sender == UniswapV2Library.pairFor(factory, token0, token1),
            "Unauthorized"
        );
        require(_amount0 == 0 || _amount1 == 0);
        path[0] = _amount0 == 0 ? token1 : token0;
        path[1] = _amount0 == 0 ? token0 : token1;
        IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);
        uint256 deadline = block.timestamp + 1 hours;
        token.approve(address(sushiRouter), amountToken);

        // no need for require() check, if amount required is not sent sushiRouter will revert
        uint256 amountRequired = UniswapV2Library.getAmountsIn(
            factory,
            amountToken,
            path
        )[0];
        uint256 amountReceived = sushiRouter.swapExactTokensForTokens(
            amountToken,
            amountRequired,
            path,
            msg.sender,
            deadline
        )[1];

        // YEAHH PROFIT
        token.transfer(_sender, amountReceived - amountRequired);
    }
}
