// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";

interface IResource {
    function id() external view returns (uint16);
    function tokenURI(uint256) external view returns (string memory);
    function mint(uint256,bytes) external view;
}

contract CraftGame is ERC721, Owned {
    mapping(uint16 => IResource) internal _resourcesById;
    mapping(uint256 => uint16) internal _resourceIdByTokenId;

    Counters.Counter internal tokenIdCounter;

    constructor() Owned(msg.sender) ERC721("craft.game", "CRAFT") {}

    function addResource(address resource) external onlyOwner {
        IResource inst = IResource(resource);
        _resourcesById[inst.id()] = inst;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return IResource(_resourcesById[_resourceIdByTokenId[tokenId]]).tokenURI(tokenId);
    }

    function mintResource(uint16 resourceId, bytes memory resourceData) public {
        _resourceIdByTokenId = resourceId;
        IResource(_resourcesById[resourceId]).mint(nextTokenId(), resourceData);
    }

    function nextTokenId() private returns (uint256) {
        tokenIdCounter.increment();
        return tokenIdCounter.current();
    }
}
