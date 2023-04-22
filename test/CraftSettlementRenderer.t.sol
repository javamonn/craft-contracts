// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./TestUtils.sol";
import "../src/CraftSettlementRenderer.sol";
import "../src/CraftSettlement.sol";

contract CraftSettlementRendererTest is Test {
    function test_getImage(uint248 mintArbiterPkey) public {
        vm.assume(mintArbiterPkey != 0);

        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        CraftSettlementRenderer renderer = new CraftSettlementRenderer();
        CraftSettlement settlement = new CraftSettlement(vm.addr(mintArbiterPkey), address(renderer));
        bytes memory sig = Utils.makeSignature(vm, mintArbiterPkey, settlement.settleHash(address(receiverMock)));

        vm.prank(address(receiverMock));
        settlement.settle(sig);

        string memory image = renderer.getImage(address(receiverMock));
        console.log(image);
        require(false, "revert");
    }
}
