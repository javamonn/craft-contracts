// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./TestUtils.sol";
import "../src/CraftSettlement.sol";

contract CraftSettlementTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function test_SetDungeonMaster(address dungeonMaster, address newMintArbiter) public {
        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster
        );
        settlement.setDungeonMaster(newMintArbiter);

        assertEq(settlement.dungeonMaster(), newMintArbiter);
    }

    function testFail_SetDungeonMasterWhenNotOwner(address dungeonMaster, address newMintArbiter, address notOwner)
        public
    {
        vm.assume(notOwner != address(0));
        vm.assume(dungeonMaster != address(0));

        CraftSettlement settlement = new CraftSettlement(
            dungeonMaster
        );

        vm.prank(notOwner);
        settlement.setDungeonMaster(newMintArbiter);
    }

    function test_Settle(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));

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

        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
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

        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(spoofedSender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfAlreadySettled(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.startPrank(address(receiverMock));
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.HasSettled.selector);
        settlement.settle(sig);
        vm.stopPrank();
    }

    function test_TokenURI(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));

        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        string memory settlementTokenUri = settlement.tokenURI(receiverMock.lastTokenId());

        // FIXME
        //assertEq(settlementTokenUri, rendererTokenUri);
    }

    function test_ApproveRevert(uint248 dungeonMasterPkey, address operator) public {
        vm.assume(dungeonMasterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
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

        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
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

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.transferFrom(address(receiverMock), to, lastTokenId);
    }

    function test_renderImage(uint248 dungeonMasterPkey) public {
        vm.assume(dungeonMasterPkey != 0);
        address to = 0x446bfBb5185D79dBBFDb77F9CA81c51409C0480b;

        CraftSettlement settlement = new CraftSettlement(vm.addr(dungeonMasterPkey));
        bytes memory sig = Utils.makeSignature(vm, dungeonMasterPkey, settlement.settleHash(to));

        vm.prank(to);
        settlement.settle(sig);

        string memory image = settlement.renderImage(1);
        console.log(image);
        require(false, "revert");
    }
}
