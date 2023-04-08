// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "ds-test/test.sol";
import "../src/CraftSettlement.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC721TokenReceiverMock is ERC721TokenReceiver {
    uint256 public lastTokenId;

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        lastTokenId = tokenId;
        return this.onERC721Received.selector;
    }
}

contract CraftSettlementTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function makeSignature(uint248 pkey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey, ECDSA.toEthSignedMessageHash(digest));
        return abi.encodePacked(r, s, v);
    }

    function test_SetMintArbiter(address newMintArbiter) public {
        CraftSettlement settlement = new CraftSettlement(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84
        );
        settlement.setMintArbiter(newMintArbiter);

        assertEq(settlement.mintArbiter(), newMintArbiter);
    }

    function testFail_SetMintArbiterWhenNotOwner(address newMintArbiter) public {
        vm.prank(address(0));

        CraftSettlement settlement = new CraftSettlement(
            0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84
        );
        settlement.setMintArbiter(newMintArbiter);
    }

    function test_Settle(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));

        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        assertEq(settlement.balanceOf(address(receiverMock)), 1);
        assertEq(settlement.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
    }

    function test_SettleRevert_IfInvalidSig(uint248 mintArbiterPkey, uint248 spoofedMintArbiterPkey, address sender) public {
        vm.assume(mintArbiterPkey != 0);
        vm.assume(spoofedMintArbiterPkey != 0);
        vm.assume(spoofedMintArbiterPkey != mintArbiterPkey);
        vm.assume(sender != address(0));

        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
        bytes memory sig = makeSignature(spoofedMintArbiterPkey, settlement.settleHash(sender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfValidSigOfWrongSender(uint248 mintArbiterPkey, address spoofedSender, address sender) public {
        vm.assume(mintArbiterPkey != 0);
        vm.assume(sender != address(0));
        vm.assume(spoofedSender != address(0));
        vm.assume(spoofedSender != sender);

        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(spoofedSender));

        vm.expectRevert(CraftSettlement.InvalidSignature.selector);
        vm.prank(sender);
        settlement.settle(sig);
    }

    function test_SettleRevert_IfAlreadySettled(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));

        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        vm.startPrank(address(receiverMock));
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.HasSettled.selector);
        settlement.settle(sig);
        vm.stopPrank();
    }

    function test_ApproveRevert(uint248 mintArbiterPkey, address operator) public {
        vm.assume(mintArbiterPkey != 0);
        
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);    
        vm.prank(address(receiverMock));
        settlement.approve(operator, lastTokenId);
    }

    function test_SetApprovalForAllRevert(uint248 mintArbiterPkey, address operator, address sender, bool approved) public {
        vm.assume(mintArbiterPkey != 0);
        
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(sender));
        vm.prank(sender);
        settlement.settle(sig);

        vm.expectRevert(CraftSettlement.Soulbound.selector);    
        vm.prank(address(sender));
        settlement.setApprovalForAll(operator, approved);
    }

    function test_TransferFromRevert(uint248 mintArbiterPkey, address to) public {
        vm.assume(mintArbiterPkey != 0);
        
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey));
        bytes memory sig = makeSignature(mintArbiterPkey, settlement.settleHash(address(receiverMock)));
        vm.prank(address(receiverMock));
        settlement.settle(sig);

        uint256 lastTokenId = receiverMock.lastTokenId();
        vm.expectRevert(CraftSettlement.Soulbound.selector);    
        vm.prank(address(receiverMock));
        settlement.transferFrom(address(receiverMock), to, lastTokenId);
    }
}
