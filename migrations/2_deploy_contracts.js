const FlashLoaner = artifacts.require("FlashLoaner");
const SafeMath = artifacts.require("@openzeppelin/contracts/math/SafeMath.sol");
const UniswapV2Library = artifacts.require("UniswapV2Library");

module.exports = function (deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, UniswapV2Library);
  deployer.deploy(UniswapV2Library);
  deployer.link(UniswapV2Library, FlashLoaner);
  deployer.deploy(FlashLoaner, '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', '0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F');  
};


