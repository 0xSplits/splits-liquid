// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {LiquidSplitFactory} from "src/LiquidSplitFactory.sol";

contract LiquidSplitFactoryScript is Script {
    function run() external {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);

        new LiquidSplitFactory{salt: keccak256("0xSplits.liquid.v1")}(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
        /* new LiquidSplitFactory(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE); */

        vm.stopBroadcast();
    }
}
