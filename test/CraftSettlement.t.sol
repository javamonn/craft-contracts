// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "./TestUtils.sol";
import "../src/CraftSettlement.sol";
import "../src/CraftAuthority.sol";

contract CraftSettlementTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    CraftAuthority authority;
    CraftSettlementMockRenderer renderer;

    function setUp() public {
        authority = new CraftAuthority();
        renderer = new CraftSettlementMockRenderer();
    }

    function test_constructor(address dungeonMaster, address renderer) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            ICraftSettlementRenderer(renderer),
            authority
        );

        assertEq(settlement.dungeonMaster(), dungeonMaster);
        assertEq(address(settlement.renderer()), renderer);
        assertEq(settlement.getTerrainsLength(), 8);
    }

    function test_setRenderer(address renderer, address newRenderer, address dungeonMaster) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            ICraftSettlementRenderer(renderer),
            authority
        );
        settlement.setRenderer(newRenderer);

        assertEq(address(settlement.renderer()), newRenderer);
    }

    function testFail_setRenderer_whenNotOwnerOrAuthorized(
        address renderer,
        address newRenderer,
        address dungeonMaster,
        address notOwner
    ) public {
        vm.assume(notOwner != address(0));
        vm.assume(renderer != address(0));
        vm.assume(notOwner != address(this));

        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            ICraftSettlementRenderer(renderer),
            authority
        );

        vm.prank(notOwner);
        settlement.setRenderer(newRenderer);
    }

    function test_setDungeonMaster(address dungeonMaster, address newDungeonMaster) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            renderer,
            authority
        );
        settlement.setDungeonMaster(newDungeonMaster);

        assertEq(settlement.dungeonMaster(), newDungeonMaster);
    }

    function testFail_setDungeonMaster_whenNotOwnerOrAuthorized(
        address dungeonMaster,
        address newDungeonMaster,
        address notOwner
    ) public {
        vm.assume(notOwner != address(0));
        vm.assume(dungeonMaster != address(0));
        vm.assume(notOwner != address(this));

        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            renderer,
            authority
        );

        vm.prank(notOwner);
        settlement.setDungeonMaster(newDungeonMaster);
    }

    function test_settle(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        assertEq(settlement.balanceOf(address(receiverMock)), 1);
        assertEq(settlement.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
    }

    function test_settleRevert_ifInvalidSig(uint248 dungeonMasterPkey, uint248 spoofedDungeonMasterPkey, address sender)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(spoofedDungeonMasterPkey != 0);
        vm.assume(spoofedDungeonMasterPkey != dungeonMasterPkey);
        vm.assume(sender != address(0));

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, spoofedDungeonMasterPkey, settlement.settleHash(sender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_settleRevert_ifValidSigOfWrongSender(uint248 dungeonMasterPkey, address spoofedSender, address sender)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(spoofedSender != address(0));
        vm.assume(spoofedSender != sender);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(spoofedSender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_settleRevert_ifAlreadySettled(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.startPrank(address(receiverMock));
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.HasSettled.selector);
        settlement.settle(sig);
        vm.stopPrank();
    }

    function test_approveRevert(uint248 dungeonMasterPkey, address operator) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.approve(operator, lastTokenId);
    }

    function test_setApprovalForAllRevert(uint248 dungeonMasterPkey, address operator, address sender, bool approved)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(operator != address(0));
        assumeNoPrecompiles(operator);
        assumeNoPrecompiles(sender);
        assumePayable(sender);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        vm.assume(sender != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(sender));
        vm.prank(sender);
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(sender));
        settlement.setApprovalForAll(operator, approved);
    }

    function test_transferFromRevert(uint248 dungeonMasterPkey, address to) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.transferFrom(address(receiverMock), to, lastTokenId);
    }

    function test_tokenURI(uint248 dungeonMasterPkey, address to) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));
        assumePayable(to);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        vm.assume(to != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        assertEq(renderer.tokenURI(address(settlement), 1), settlement.tokenURI(1));
    }

    function test_getMetadataByTokenId(uint248 dungeonMasterPkey, address to) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));
        assumeNoPrecompiles(to);
        assumePayable(to);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        vm.assume(to != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        assertEq(settlement.getMetadataByTokenId(1).settler, to);
    }

    function test_getTerrainsLength(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );

        assertEq(settlement.getTerrainsLength(), 8);
    }

    function test_getTerrain(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        assertEq(settlement.getTerrain(0).name, "Grasslands");
    }

    function test_setMetadataTerrainIndex(uint248 dungeonMasterPkey, address to, uint8 terrainIndex) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));
        vm.assume(terrainIndex < 240);
        assumeNoPrecompiles(to);
        assumePayable(to);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        vm.assume(to != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        uint16 currentTerrainIndex = settlement.getMetadataByTokenId(1).terrainIndexes[terrainIndex];
        uint16 newTerrainIndex = (currentTerrainIndex + 1) % 8;
        settlement.setMetadataTerrainIndex(1, terrainIndex, newTerrainIndex);

        assertEq(settlement.getMetadataByTokenId(1).terrainIndexes[terrainIndex], newTerrainIndex);
    }

    function testFail_setMetadataTerrainIndex_whenNotOwnerOrAuthorized(
        uint248 dungeonMasterPkey,
        address to,
        uint8 terrainIndex
    ) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));
        vm.assume(terrainIndex < 240);
        vm.assume(to != address(this));
        assumeNoPrecompiles(to);
        assumePayable(to);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        vm.assume(to != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        uint16 currentTerrainIndex = settlement.getMetadataByTokenId(1).terrainIndexes[terrainIndex];
        uint16 newTerrainIndex = (currentTerrainIndex + 1) % 8;

        vm.prank(to);
        settlement.setMetadataTerrainIndex(1, terrainIndex, newTerrainIndex);
    }

    function test_setTerrain(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        CraftSettlementData.Terrain memory terrain = CraftSettlementData.Terrain("Desert", new string[](1), "foo");
        terrain.renderedCharacters[0] = "bar";

        // Push terrain
        settlement.setTerrain(8, terrain);
        assertEq(settlement.getTerrain(8).name, terrain.name);
        assertEq(settlement.getTerrain(8).renderedCharacters[0], terrain.renderedCharacters[0]);

        // Overwrite existing terrain
        settlement.setTerrain(0, terrain);
        assertEq(settlement.getTerrain(0).name, terrain.name);
        assertEq(settlement.getTerrain(0).renderedCharacters[0], terrain.renderedCharacters[0]);
    }

    function test_setTerrain_whenAuthorized(uint248 dungeonMasterPkey, address sender) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != address(0));

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        CraftSettlementData.Terrain memory terrain = CraftSettlementData.Terrain("Desert", new string[](1), "foo");
        terrain.renderedCharacters[0] = "bar";
        authority.setRoleCapability(1, address(settlement), CraftSettlement.setTerrain.selector, true);
        authority.setUserRole(sender, 1, true);

        vm.prank(sender);
        settlement.setTerrain(8, terrain);
        assertEq(settlement.getTerrain(8).name, terrain.name);
        assertEq(settlement.getTerrain(8).renderedCharacters[0], terrain.renderedCharacters[0]);
    }

    function testFail_setTerrain_whenNotOwnerOrAuthorized(uint248 dungeonMasterPkey, address sender) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != vm.addr(dungeonMasterPkey));
        vm.assume(sender != address(this));

        CraftSettlement settlement = new CraftSettlement(
            vm.addr(dungeonMasterPkey),
            renderer,
            authority
        );
        CraftSettlementData.Terrain memory terrain = CraftSettlementData.Terrain("Desert", new string[](1), "foo");
        terrain.renderedCharacters[0] = "bar";

        vm.prank(sender);
        settlement.setTerrain(8, terrain);
    }
}
