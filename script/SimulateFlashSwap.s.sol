// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {FlashLoaner} from "../src/FlashLoaner.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockUniswapV2Router} from "../test/mocks/MockUniswapV2Router.sol";
import {MockUniswapV2Pair} from "../test/mocks/MockUniswapV2Pair.sol";
import {UniswapV2Library} from "../src/libraries/UniswapV2Library.sol";

contract SimulateFlashSwap is Script {
    function run() external {
        vm.startBroadcast();

        address factory = address(0xFEEF);
        MockERC20 tokenA = new MockERC20("TokenA", "TKA", 18);
        MockERC20 tokenB = new MockERC20("TokenB", "TKB", 18);
        MockUniswapV2Router router = new MockUniswapV2Router();
        FlashLoaner flashLoaner = new FlashLoaner(factory, address(router));

        address pair = UniswapV2Library.pairFor(factory, address(tokenA), address(tokenB));
        vm.etch(pair, type(MockUniswapV2Pair).runtimeCode);
        MockUniswapV2Pair(pair).initialize(factory, address(tokenA), address(tokenB));
        MockUniswapV2Pair(pair).updateReserves(1_000_000 ether, 1_000_000 ether);

        uint256 amountBorrowed = 10_000 ether;
        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(tokenA);
        uint256 repayment = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];
        uint256 profit = 500 ether;

        tokenB.mint(address(flashLoaner), amountBorrowed);
        tokenA.mint(address(router), repayment + profit);
        router.setAmountOut(address(tokenB), address(tokenA), repayment + profit);

        vm.prank(pair);
        flashLoaner.uniswapV2Call(msg.sender, 0, amountBorrowed, bytes("demo"));

        console2.log("Demo pair address", pair);
        console2.log("Repayment needed", repayment);
        console2.log("Profit captured", profit);

        vm.stopBroadcast();
    }
}
