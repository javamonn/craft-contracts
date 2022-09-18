// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CraftResource.sol";

contract CraftResourceTest is Test {
    CraftResource public craftResource;

    function setUp() public {
        counter = new CraftResource("craft.game resource", "CRAFTR");
    }
}
