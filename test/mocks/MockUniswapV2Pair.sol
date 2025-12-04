// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockUniswapV2Pair {
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    function initialize(address factory_, address token0_, address token1_) external {
        require(factory == address(0), "MockPair: already initialized");
        factory = factory_;
        token0 = token0_;
        token1 = token1_;
    }

    function updateReserves(uint112 reserve0_, uint112 reserve1_) external {
        reserve0 = reserve0_;
        reserve1 = reserve1_;
    }

    function getReserves()
        external
        view
        returns (uint112 _reserve0, uint112 _reserve1, uint32 blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }
}
