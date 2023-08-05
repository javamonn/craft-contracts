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
    string tokenURIOutputFixturePath =
        "./test/fixtures/CraftSettlementRenderer_tokenURI_output_0x446bfBb5185D79dBBFDb77F9CA81c51409C0480b.txt";

    function setUp() public {
        authority = new CraftAuthority();
        renderer = new CraftSettlementRenderer(authority);
    }

    function test_constructor() public {
        assertEq(renderer.getTerrainsLength(), 9);
    }

    // FIXME: regenerate with settlement idx + final generation algo
    function test_tokenURI(uint248 dungeonMasterPkey) private {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        renderer.setSettlement(settlement);
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.getHashForSettler(to));
        vm.prank(to);

        settlement.settle(sig, 0);

        assertEq(
            // Note: ensure file does not have 0x0a EOL byte
            vm.readFile(tokenURIOutputFixturePath),
            renderer.tokenURI(1)
        );
    }

    function test_tokenURI_equalsRender(uint248 dungeonMasterPkey, uint8 settlementIdx) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(settlementIdx < 240);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        renderer.setSettlement(settlement);
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.getHashForSettler(to));
        vm.prank(to);
        settlement.settle(sig, settlementIdx);

        uint16[240] memory terrains = settlement.generateTerrains(to);
        terrains[settlementIdx] = settlement.settlementTerrainIndex();

        assertEq(renderer.render(CraftSettlement.Metadata(terrains, to, settlementIdx)), renderer.tokenURI(1));
    }

    function test_setTerrain(uint16 terrainIdx, string memory terrainName) public {
        uint256 terrainsLength = renderer.getTerrainsLength();
        vm.assume(terrainIdx < terrainsLength);

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        renderer.setTerrain(terrainIdx, terrain);

        assertEq(renderer.getTerrainsLength(), terrainsLength);
        assertEq(renderer.getTerrain(terrainIdx).name, terrainName);
    }

    function test_setTerrain_whenAuthorized(uint16 terrainIdx, string memory terrainName, address sender) public {
        uint256 terrainsLength = renderer.getTerrainsLength();
        vm.assume(terrainIdx < terrainsLength);
        vm.assume(sender != address(0));

        // Auth sender for setTerrain
        authority.setRoleCapability(1, address(renderer), CraftSettlementRenderer.setTerrain.selector, true);
        authority.setUserRole(sender, 1, true);

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        vm.prank(sender);
        renderer.setTerrain(terrainIdx, terrain);

        assertEq(renderer.getTerrainsLength(), terrainsLength);
        assertEq(renderer.getTerrain(terrainIdx).name, terrainName);
    }

    function testFail_setTerrain_whenNotOwnerOrAuthorized(uint16 terrainIdx, string memory terrainName, address sender)
        public
    {
        uint256 terrainsLength = renderer.getTerrainsLength();
        vm.assume(terrainIdx < terrainsLength);
        vm.assume(sender != address(0));

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        vm.prank(sender);

        // requiresAuth reverts
        renderer.setTerrain(terrainIdx, terrain);
    }

    function test_addTerrain(string memory terrainName) public {
        uint256 terrainsLength = renderer.getTerrainsLength();

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        renderer.addTerrain(terrain);

        assertEq(renderer.getTerrainsLength(), terrainsLength + 1);
        assertEq(renderer.getTerrain(renderer.getTerrainsLength() - 1).name, terrainName);
    }

    function test_addTerrain_whenAuthorized(string memory terrainName, address sender) public {
        uint256 terrainsLength = renderer.getTerrainsLength();
        vm.assume(sender != address(0));

        // Auth sender for setTerrain
        authority.setRoleCapability(1, address(renderer), CraftSettlementRenderer.addTerrain.selector, true);
        authority.setUserRole(sender, 1, true);

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        vm.prank(sender);
        renderer.addTerrain(terrain);

        assertEq(renderer.getTerrainsLength(), terrainsLength + 1);
        assertEq(renderer.getTerrain(renderer.getTerrainsLength() - 1).name, terrainName);
    }

    function testFail_addTerrain_whenNotOwnerOrAuthorized(string memory terrainName, address sender) public {
        uint256 terrainsLength = renderer.getTerrainsLength();
        vm.assume(sender != address(0));

        // Create and set terrain
        CraftSettlementRenderer.Terrain memory terrain =
            CraftSettlementRenderer.Terrain(terrainName, new string[](1), "foo", true);
        vm.prank(sender);

        // requiresAuth reverts
        renderer.addTerrain(terrain);
    }
}
