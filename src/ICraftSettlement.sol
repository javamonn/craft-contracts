pragma solidity ^0.8.13;

import "./CraftSettlementData.sol";

interface ICraftSettlement {
    function getMetadataByTokenId(uint256) external view returns (CraftSettlementData.Metadata memory);
    function getTerrain(uint256) external view returns (CraftSettlementData.Terrain memory);
    function getTerrainsLength() external view returns (uint256);
}
