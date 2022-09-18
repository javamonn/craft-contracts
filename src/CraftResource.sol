// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";

interface IResource {
    function id() external view returns (uint16);
}

contract CraftResource is ERC721, Owned {
    mapping(uint16 => IResource) internal _resources;
    mapping(uint256 => uint16) internal _tokenResourceId;

    function addResource(address resource) external onlyOwner {
        IResource resource = IResource(resource);
        _resources[resource.id()] = resource;
    }
}
