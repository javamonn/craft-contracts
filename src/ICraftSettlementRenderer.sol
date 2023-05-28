pragma solidity ^0.8.13;

interface ICraftSettlementRenderer {
    function tokenURI(address, uint256) external view returns (string memory);
}
