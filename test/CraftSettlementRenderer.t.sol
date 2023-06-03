// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "./TestUtils.sol";
import "../src/CraftSettlement.sol";
import "../src/CraftAuthority.sol";
import "../src/CraftSettlementRenderer.sol";
import "../src/CraftSettlementData.sol";

contract CraftSettlementRendererTest is Test {

    CraftSettlementRenderer renderer;
    CraftAuthority authority;

    address to = 0x446bfBb5185D79dBBFDb77F9CA81c51409C0480b;
    string tokenURIOutputFixturePath = "./test/fixtures/CraftSettlementRenderer_tokenURI_output_0x446bfBb5185D79dBBFDb77F9CA81c51409C0480b.txt";
    
    function setUp() public {
        authority = new CraftAuthority();
        renderer = new CraftSettlementRenderer();
    }

    function test_tokenURI(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));
        vm.prank(to);
        settlement.settle(sig);

        assertEq(
            // Note: ensure file does not have 0x0a EOL byte
            vm.readFile(tokenURIOutputFixturePath),
            renderer.tokenURI(address(settlement), 1)
        );
    }

    function test_tokenURI_equalsRender(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));
        vm.prank(to);
        settlement.settle(sig);

        uint16[240] memory terrains = settlement.generateTerrains(to);

        assertEq(
            renderer.render(
                settlement,
                CraftSettlementData.Metadata(terrains, to)
            ),
            renderer.tokenURI(address(settlement), 1)
        );
    }
}
