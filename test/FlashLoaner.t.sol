// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FlashLoaner} from "../src/FlashLoaner.sol";
import {UniswapV2Library} from "../src/libraries/UniswapV2Library.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Router} from "./mocks/MockUniswapV2Router.sol";
import {MockUniswapV2Pair} from "./mocks/MockUniswapV2Pair.sol";

contract FlashLoanerTest is Test {
    FlashLoaner private flashLoaner;
    MockERC20 private tokenA;
    MockERC20 private tokenB;
    MockUniswapV2Router private router;
    address private factory;
    address private pair;

    address private borrower = makeAddr("borrower");

    function setUp() public {
        tokenA = new MockERC20("TokenA", "TKA", 18);
        tokenB = new MockERC20("TokenB", "TKB", 18);
        router = new MockUniswapV2Router();
        factory = makeAddr("factory");

        flashLoaner = new FlashLoaner(factory, address(router));

        pair = UniswapV2Library.pairFor(factory, address(tokenA), address(tokenB));
        vm.etch(pair, type(MockUniswapV2Pair).runtimeCode);
        MockUniswapV2Pair(pair).initialize(factory, address(tokenA), address(tokenB));
    }

    function testUniswapCallbackRepaysAndSendsProfit() public {
        uint256 amountBorrowed = 1_000 ether;
        uint112 reserveA = 5_000_000 ether;
        uint112 reserveB = 10_000_000 ether;
        MockUniswapV2Pair(pair).updateReserves(reserveA, reserveB);

        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(tokenA);
        uint256 requiredRepayment = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];
        uint256 profit = 20 ether;

        tokenA.mint(address(router), requiredRepayment + profit);
        tokenB.mint(address(flashLoaner), amountBorrowed);

        router.setAmountOut(address(tokenB), address(tokenA), requiredRepayment + profit);

        vm.prank(pair);
        flashLoaner.uniswapV2Call(borrower, 0, amountBorrowed, bytes("demo"));

        assertEq(IERC20(address(tokenA)).balanceOf(pair), requiredRepayment, "pair repaid");
        assertEq(tokenA.balanceOf(borrower), profit, "borrower profits");
        assertEq(tokenA.balanceOf(address(flashLoaner)), 0, "flashLoaner cleared");
        assertEq(tokenB.balanceOf(address(flashLoaner)), 0, "borrowed token spent");
    }

    function testRevertsWhenBothAmountsProvided() public {
        vm.expectRevert(FlashLoaner.InvalidAmounts.selector);
        vm.prank(pair);
        flashLoaner.uniswapV2Call(borrower, 1 ether, 1 ether, bytes("invalid"));
    }

    function testRevertsForUnauthorizedPair() public {
        uint256 fakeBorrow = 1_000 ether;
        MockUniswapV2Pair roguePair = new MockUniswapV2Pair();
        roguePair.initialize(makeAddr("rogueFactory"), address(tokenA), address(tokenB));

        vm.expectRevert(
            abi.encodeWithSelector(FlashLoaner.UnauthorizedPair.selector, address(roguePair))
        );
        vm.prank(address(roguePair));
        flashLoaner.uniswapV2Call(borrower, fakeBorrow, 0, bytes("invalid"));
    }

    function testRevertsWhenSwapDoesNotMeetRepayment() public {
        uint256 amountBorrowed = 500 ether;
        MockUniswapV2Pair(pair).updateReserves(2_000_000 ether, 5_000_000 ether);

        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(tokenA);
        uint256 requiredRepayment = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];

        router.setEnforceSlippage(false);
        router.setAmountOut(address(tokenB), address(tokenA), requiredRepayment - 1);
        tokenB.mint(address(flashLoaner), amountBorrowed);
        tokenA.mint(address(router), requiredRepayment);

        vm.expectRevert(
            abi.encodeWithSelector(
                FlashLoaner.InsufficientProceeds.selector, requiredRepayment - 1, requiredRepayment
            )
        );
        vm.prank(pair);
        flashLoaner.uniswapV2Call(borrower, 0, amountBorrowed, bytes("shortfall"));
    }

    function testFuzzUniswapCallbackSettlesLoan(
        uint112 reserve0,
        uint112 reserve1,
        uint96 borrowRaw,
        uint96 profitRaw,
        bool borrowToken1
    ) public {
        reserve0 = uint112(bound(reserve0, 2_000_000 ether, type(uint112).max - 1));
        reserve1 = uint112(bound(reserve1, 2_000_000 ether, type(uint112).max - 1));

        MockUniswapV2Pair(pair).updateReserves(reserve0, reserve1);

        address borrowedToken = borrowToken1 ? address(tokenB) : address(tokenA);
        address repaymentToken = borrowToken1 ? address(tokenA) : address(tokenB);

        uint112 availableLiquidity = borrowToken1 ? reserve1 : reserve0;
        vm.assume(availableLiquidity > 1);

        uint256 amountBorrowed = bound(uint256(borrowRaw), 1, availableLiquidity - 1);

        address[] memory path = new address[](2);
        path[0] = borrowedToken;
        path[1] = repaymentToken;

        uint256 amountRequired = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];
        vm.assume(amountRequired > 0);

        uint256 profit = bound(uint256(profitRaw), 1, (type(uint256).max - amountRequired) / 2);
        uint256 configuredOut = amountRequired + profit;

        MockERC20(borrowedToken).mint(address(flashLoaner), amountBorrowed);
        MockERC20(repaymentToken).mint(address(router), configuredOut);

        router.setAmountOut(borrowedToken, repaymentToken, configuredOut);

        vm.expectEmit(true, true, true, true);
        emit FlashLoaner.LoanExecuted(
            pair, borrower, borrowedToken, repaymentToken, amountBorrowed, amountRequired, profit
        );

        vm.prank(pair);
        flashLoaner.uniswapV2Call(
            borrower,
            borrowToken1 ? 0 : amountBorrowed,
            borrowToken1 ? amountBorrowed : 0,
            bytes("fuzzed")
        );

        assertEq(IERC20(repaymentToken).balanceOf(pair), amountRequired, "repayment sent to pair");
        assertEq(IERC20(repaymentToken).balanceOf(borrower), profit, "profit forwarded to borrower");
        assertEq(IERC20(repaymentToken).balanceOf(address(flashLoaner)), 0, "no repayment dust");
        assertEq(IERC20(borrowedToken).balanceOf(address(flashLoaner)), 0, "borrowed tokens spent");
    }

    function testFuzzRevertsWhenSwapOutputTooLow(
        uint112 reserve0,
        uint112 reserve1,
        uint96 borrowRaw,
        uint96 shortfallRaw,
        bool borrowToken1
    ) public {
        reserve0 = uint112(bound(reserve0, 2_000_000 ether, type(uint112).max - 1));
        reserve1 = uint112(bound(reserve1, 2_000_000 ether, type(uint112).max - 1));

        MockUniswapV2Pair(pair).updateReserves(reserve0, reserve1);

        address borrowedToken = borrowToken1 ? address(tokenB) : address(tokenA);
        address repaymentToken = borrowToken1 ? address(tokenA) : address(tokenB);

        uint112 availableLiquidity = borrowToken1 ? reserve1 : reserve0;
        vm.assume(availableLiquidity > 1);

        uint256 amountBorrowed = bound(uint256(borrowRaw), 1, availableLiquidity - 1);

        address[] memory path = new address[](2);
        path[0] = borrowedToken;
        path[1] = repaymentToken;

        uint256 amountRequired = UniswapV2Library.getAmountsIn(factory, amountBorrowed, path)[0];
        vm.assume(amountRequired > 0);

        uint256 shortfall = bound(uint256(shortfallRaw), 1, amountRequired);
        uint256 configuredOut = amountRequired - shortfall;

        MockERC20(borrowedToken).mint(address(flashLoaner), amountBorrowed);
        MockERC20(repaymentToken).mint(address(router), configuredOut);

        router.setEnforceSlippage(false);
        router.setAmountOut(borrowedToken, repaymentToken, configuredOut);

        vm.expectRevert(
            abi.encodeWithSelector(
                FlashLoaner.InsufficientProceeds.selector, configuredOut, amountRequired
            )
        );
        vm.prank(pair);
        flashLoaner.uniswapV2Call(
            borrower,
            borrowToken1 ? 0 : amountBorrowed,
            borrowToken1 ? amountBorrowed : 0,
            bytes("shortfall fuzz")
        );
    }
}
