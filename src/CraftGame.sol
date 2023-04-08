// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IResource {
    function id() external view returns (uint16);
    function tokenURI(uint256) external view returns (string memory);
    function mint(address, uint256, bytes calldata) external;
}

contract CraftGame is ERC721, Owned {
    using Counters for Counters.Counter;

    mapping(uint16 => IResource) internal _resourcesById;
    mapping(uint256 => uint16) internal _resourceIdByTokenId;
    // Settlement internal settlement;

    Counters.Counter internal tokenIdCounter;

    constructor() Owned(msg.sender) ERC721("craft.game", "CRAFT") {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return IResource(_resourcesById[_resourceIdByTokenId[tokenId]]).tokenURI(tokenId);
    }

    function mintResource(address to, uint16 resourceId, bytes calldata resourceData) external {
        uint256 tokenId = nextTokenId();
        _resourceIdByTokenId[tokenId] = resourceId;

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _balanceOf[to]++;
        }
        _ownerOf[tokenId] = to;

        _resourcesById[resourceId].mint(to, tokenId, resourceData);
    }

    function addResource(address resource) external onlyOwner {
        IResource inst = IResource(resource);
        _resourcesById[inst.id()] = inst;
    }

    // Mint a soulbound ERC721 representing gather resource chances
    function settle() external {}

    function gather() external {}

    function nextTokenId() private returns (uint256) {
        tokenIdCounter.increment();
        return tokenIdCounter.current();
    }
}
