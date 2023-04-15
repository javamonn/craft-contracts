// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CraftSettlementRenderer is Owned {
    using Strings for uint256;

    enum Terrain {
        GRASSLAND,
        PLAINS,
        HILLS,
        MOUNTAINS,
        OCEAN,
        WOODS,
        RAINFOREST,
        MARSH,
        UNKNOWN
    }

    constructor() Owned(msg.sender) {}

    function getTerrains(address owner) external returns (Terrain[64] memory) {
        bytes32 hash = keccak256(abi.encodePacked(owner));

        // 4 bits per terrain, 32 byte input
        Terrain[64] memory terrains;
        for (uint8 i = 0; i < 32;) {
            bytes1 b = bytes1(hash << 8 * i);

            // We only need 4 bits per terrain
            uint8 upper = uint8(b >> 4);
            uint8 lower = uint8(b & 0x0F);

            // UNKNOWN is weighted heavier, truncate down for valid enum value
            if (upper > 8) upper = 8;
            if (lower > 8) lower = 8;

            uint8 terrainIdx = i * 2;
            terrains[terrainIdx] = Terrain(upper);
            terrains[terrainIdx + 1] = Terrain(lower);

            unchecked {
                i++;
            }
        }

        return terrains;
    }

    function getImage(address owner) public view returns (string memory) {
        // https://etherscan.deth.net/address/0x49957ca2f1e314c2cf70701816bf6283b7215811#code
        // https://etherscan.deth.net/address/0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2#code
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        address owner = IERC721(msg.sender).ownerOf(tokenId);

        string image = getImage(owner);
        bytes memory dataURI = abi.encodePacked('{"image": "', owner, '"}');

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }
}
