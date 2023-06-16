// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/CraftAuthority.sol";
import "../src/CraftSettlement.sol";
import "../src/CraftSettlementRenderer.sol";

contract CraftSettlementScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        CraftAuthority authority = new CraftAuthority();
        CraftSettlementRenderer renderer = new CraftSettlementRenderer(authority);
        CraftSettlement settlement = new CraftSettlement(vm.addr(deployerPrivateKey), renderer, authority);
        renderer.setSettlement(settlement);

        vm.stopBroadcast();
    }
}
