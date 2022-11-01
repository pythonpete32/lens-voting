// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "../src/LensVotingSetup.sol";

contract Setup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LensVotingSetup setup = new LensVotingSetup();

        vm.stopBroadcast();
    }
}
