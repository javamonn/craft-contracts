// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./TestUtils.sol";
import "../src/CraftSettlement.sol";

contract CraftSettlementTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function test_SetMintArbiter(address mintArbiter, address newMintArbiter) public {
        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(
            mintArbiter,
            address(rendererMock)
        );
        settlement.setMintArbiter(newMintArbiter);

        assertEq(settlement.mintArbiter(), newMintArbiter);
    }

    function testFail_SetMintArbiterWhenNotOwner(address mintArbiter, address newMintArbiter, address notOwner)
        public
    {
        vm.assume(notOwner != address(0));
        vm.assume(mintArbiter != address(0));

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();

        CraftSettlement settlement = new CraftSettlement(
            mintArbiter,
            address(rendererMock)
        );

        vm.prank(notOwner);
        settlement.setMintArbiter(newMintArbiter);
    }

    function test_SetRenderer(address renderer, address newRenderer, address mintArbiter) public {
        CraftSettlement settlement = new CraftSettlement(
            mintArbiter,
            renderer 
        );
        settlement.setRenderer(newRenderer);

        assertEq(settlement.renderer(), newRenderer);
    }

    function testFail_SetRendererWhenNotOwner(
        address renderer,
        address newRenderer,
        address mintArbiter,
        address notOwner
    )
        public
    {
        vm.assume(notOwner != address(0));
        vm.assume(mintArbiter != address(0));
        vm.assume(newRenderer != address(0));

        CraftSettlement settlement = new CraftSettlement(
            mintArbiter,
            renderer
        );

        vm.prank(notOwner);
        settlement.setRenderer(newRenderer);
    }

    function test_Settle(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));

        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        assertEq(settlement.balanceOf(address(receiverMock)), 1);
        assertEq(settlement.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
    }

    function test_SettleRevert_IfInvalidSig(uint248 mintArbiterPkey, uint248 spoofedMintArbiterPkey, address sender)
        public
    {
        vm.assume(mintArbiterPkey != 0);
        vm.assume(spoofedMintArbiterPkey != 0);
        vm.assume(spoofedMintArbiterPkey != mintArbiterPkey);
        vm.assume(sender != address(0));

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));
        bytes memory sig = Utils.makeSignature(vm, spoofedMintArbiterPkey, settlement.settleHash(sender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfValidSigOfWrongSender(uint248 mintArbiterPkey, address spoofedSender, address sender)
        public
    {
        vm.assume(mintArbiterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(spoofedSender != address(0));
        vm.assume(spoofedSender != sender);

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));
        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(spoofedSender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfAlreadySettled(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));

        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.startPrank(address(receiverMock));
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.HasSettled.selector);
        settlement.settle(sig);
        vm.stopPrank();
    }

    function test_TokenURI(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));

        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        string memory settlementTokenUri = settlement.tokenURI(receiverMock.lastTokenId());
        string memory rendererTokenUri = rendererMock.tokenURI(receiverMock.lastTokenId());

        assertEq(settlementTokenUri, rendererTokenUri);
    }

    function test_ApproveRevert(uint248 mintArbiterPkey, address operator) public {
        vm.assume(mintArbiterPkey != 0);

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));
        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.approve(operator, lastTokenId);
    }

    function test_SetApprovalForAllRevert(uint248 mintArbiterPkey, address operator, address sender, bool approved)
        public
    {
        vm.assume(mintArbiterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(operator != address(0));

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));
        vm.assume(sender != address(rendererMock));
        vm.assume(sender != address(settlement));

        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(sender));
        vm.prank(sender);
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(sender));
        settlement.setApprovalForAll(operator, approved);
    }

    function test_TransferFromRevert(uint248 mintArbiterPkey, address to) public {
        vm.assume(mintArbiterPkey != 0);

        CraftSettlementRendererMock rendererMock = new CraftSettlementRendererMock();
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(rendererMock));
        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);
        vm.prank(address(receiverMock));
        settlement.transferFrom(address(receiverMock), to, lastTokenId);
    }
}
