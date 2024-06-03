// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "src/OPOutputLookup.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        OPOutputLookup opOutputLookup = new OPOutputLookup{salt: bytes32(0)}();

        vm.stopBroadcast();

        console.log("Contract deployed at:", address(opOutputLookup));
    }
}
