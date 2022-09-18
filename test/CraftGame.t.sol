// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CraftResource.sol";

contract ResourceMock {
    function id() external pure returns (uint16) {
        return 1;
    }
    
    function tokenURI(uint256 /*tokenId*/) external pure returns (string memory) {
        return "data://";
    }
}

contract CraftGameTest is Test {
    CraftResource public craftResource;
    ResourceMock public resourceMock;

    function setUp() public {
        craftResource = new CraftResource();
        resourceMock = new ResourceMock();
    }

    function testAddResourceAsOwner() public {
        craftResource.addResource(address(resourceMock));
    }

    function testFailAddResourceNotAsOwner() public {
        vm.prank(address(0));
        craftResource.addResource(address(resourceMock));
    }
}
