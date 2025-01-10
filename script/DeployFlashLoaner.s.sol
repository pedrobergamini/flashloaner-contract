// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {FlashLoaner} from "../src/FlashLoaner.sol";

contract DeployFlashLoaner is Script {
    function run() external {
        address factory = vm.envAddress("UNISWAP_V2_FACTORY");
        address router = vm.envAddress("UNISWAP_V2_ROUTER");

        vm.startBroadcast();
        FlashLoaner flashLoaner = new FlashLoaner(factory, router);
        vm.stopBroadcast();

        console2.log("FlashLoaner deployed to", address(flashLoaner));
    }
}
