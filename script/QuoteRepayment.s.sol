// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {UniswapV2Library} from "../src/libraries/UniswapV2Library.sol";

contract QuoteRepayment is Script {
    function run() external view {
        address pair = vm.envAddress("PAIR_ADDRESS");
        uint256 amountBorrowed = vm.envUint("AMOUNT_BORROWED");
        bool borrowToken0 = vm.envBool("BORROW_TOKEN0");

        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);

        address token0 = pairContract.token0();
        address token1 = pairContract.token1();
        address borrowedToken = borrowToken0 ? token0 : token1;
        address repaymentToken = borrowToken0 ? token1 : token0;

        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        console2.log("Pair reserves", reserve0, reserve1);

        address[] memory path = new address[](2);
        path[0] = borrowedToken;
        path[1] = repaymentToken;

        uint256 amountRequired =
            UniswapV2Library.getAmountsIn(pairContract.factory(), amountBorrowed, path)[0];

        console2.log("Borrowing token", borrowedToken);
        console2.log("Repayment token", repaymentToken);
        console2.log("Amount borrowed", amountBorrowed);
        console2.log("Amount required for repayment", amountRequired);
    }
}
