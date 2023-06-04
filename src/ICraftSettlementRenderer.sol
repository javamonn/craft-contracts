// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ICraftSettlementRenderer {
    function tokenURI(uint256) external view returns (string memory);
    function getTerrainsLength() external view returns (uint256);
}
