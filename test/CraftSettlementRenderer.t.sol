// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/CraftSettlementRenderer.sol";

library Utils {
    function logTerrain(CraftSettlementRenderer.Terrain[64] memory terrain, uint8 rowSize) public {
        string memory output = "";
        for (uint256 i = 0; i < terrain.length / rowSize; i++) {
            for (uint256 j = 0; j < rowSize; j++) {
                output = string(abi.encodePacked(output, Strings.toString(uint256(terrain[(i * rowSize) + j]))));
            }
            output = string(abi.encodePacked(output, "\n"));
        }

        console.log(output);
        require(false, "logTerrain");
    }
}

contract CraftSettlementRendererTest is Test {
/**
 * function test_Explore(uint248 mintArbiterPkey) public {
 * vm.assume(mintArbiterPkey != 0);
 *
 * ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
 * CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
 * bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
 * vm.prank(address(receiverMock));
 * settlement.settle(sig);
 *
 * uint256 lastTokenId = receiverMock.lastTokenId();
 *
 * CraftSettlement.Terrain[64] memory terrain =
 * settlement.explore(lastTokenId, settlement.settleHash(address(receiverMock)));
 *
 * Utils.logTerrain(terrain, 8);
 * }
 *
 */
}
