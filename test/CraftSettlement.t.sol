// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./TestUtils.sol";
import "../src/CraftSettlement.sol";

contract CraftSettlementTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function test_constructor(address dungeonMaster, address renderer) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            renderer
        );

        assertEq(settlement.dungeonMaster(), dungeonMaster);
        assertEq(address(settlement.renderer()), renderer);
        assertEq(settlement.getTerrainsLength(), 8);
    }

    function test_setRenderer(address renderer, address newRenderer, address dungeonMaster) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            renderer
        );
        settlement.setRenderer(newRenderer);

        assertEq(address(settlement.renderer()), newRenderer);
    }

    function testFail_SetRendererWhenNotOwner(
        address renderer,
        address newRenderer,
        address dungeonMaster,
        address notOwner
    ) public {
        vm.assume(notOwner != address(0));
        vm.assume(renderer != address(0));

        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            renderer
        );

        vm.prank(notOwner);
        settlement.setRenderer(newRenderer);
    }

    function test_SetDungeonMaster(address dungeonMaster, address newDungeonMaster) public {
        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            address(renderer)
        );
        settlement.setDungeonMaster(newDungeonMaster);

        assertEq(settlement.dungeonMaster(), newDungeonMaster);
    }

    function testFail_SetDungeonMasterWhenNotOwner(address dungeonMaster, address newDungeonMaster, address notOwner)
        public
    {
        vm.assume(notOwner != address(0));
        vm.assume(dungeonMaster != address(0));

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster,
            address(renderer)
        );

        vm.prank(notOwner);
        settlement.setDungeonMaster(newDungeonMaster);
    }

    function test_Settle(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        assertEq(settlement.balanceOf(address(receiverMock)), 1);
        assertEq(settlement.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
    }

    function test_SettleRevert_IfInvalidSig(uint248 dungeonMasterPkey, uint248 spoofedDungeonMasterPkey, address sender)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(spoofedDungeonMasterPkey != 0);
        vm.assume(spoofedDungeonMasterPkey != dungeonMasterPkey);
        vm.assume(sender != address(0));

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, spoofedDungeonMasterPkey, settlement.settleHash(sender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfValidSigOfWrongSender(uint248 dungeonMasterPkey, address spoofedSender, address sender)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(spoofedSender != address(0));
        vm.assume(spoofedSender != sender);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(spoofedSender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfAlreadySettled(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.startPrank(address(receiverMock));
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.HasSettled.selector);
        settlement.settle(sig);
        vm.stopPrank();
    }

    function test_ApproveRevert(uint248 dungeonMasterPkey, address operator) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        console.log("settling");
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        console.log("settled");
        console.log(lastTokenId);
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.approve(operator, lastTokenId);
    }

    function test_SetApprovalForAllRevert(uint248 dungeonMasterPkey, address operator, address sender, bool approved)
        public
    {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(operator != address(0));
        assumeNoPrecompiles(operator);
        assumeNoPrecompiles(sender);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        vm.assume(sender != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(sender));
        vm.prank(sender);
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(sender));
        settlement.setApprovalForAll(operator, approved);
    }

    function test_TransferFromRevert(uint248 dungeonMasterPkey, address to) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
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
        assumeNoPrecompiles(to);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        assertEq(renderer.tokenURI(address(settlement), 1), settlement.tokenURI(1));
    }

    function test_getMetadataByTokenId(uint248 dungeonMasterPkey, address to) public {
        vm.assume(dungeonMasterPkey != 0);
        vm.assume(to != address(0));
        assumeNoPrecompiles(to);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        assertEq(settlement.getMetadataByTokenId(1).settler, to);
    }

    function test_getTerrainsLength(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));

        assertEq(settlement.getTerrainsLength(), 8);
    }

    function test_getTerrain(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        CraftSettlementMockRenderer renderer = new CraftSettlementMockRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey), address(renderer));
        assertEq(settlement.getTerrain(0).name, "Grasslands");
    }
}
