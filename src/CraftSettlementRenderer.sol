// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "forge-std/Test.sol";

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
        SWAMP,
        UNKNOWN
    }

    uint8 constant GRID_SIZE = 24;
    string constant SVG_STYLES_GRID = string(
        abi.encodePacked(
            ".a{width:576px;height:576px;background-color:black;}",
            ".b{box-sizing:border-box;width:576px;height:576px;padding:24px;display:grid;grid-template-columns:repeat(24, 1fr);grid-template-rows:repeat(24, 1fr);grid-gap: 0px;justify-content:space-between;font-family:monospace;}",
            "body,svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
            ".t4{display:inline-grid;grid-template-rows:repeat(2,1fr);grid-template-columns:repeat(2,1fr);font-size:0.6rem;}",
            ".t1{font-size:1.1rem;line-height:100%;}",
            "span{aspect-ratio:1/1;display:flex;justify-content:center;align-items:center;}"
        )
    );
    string constant SVG_STYLES_COLOR = string(
        abi.encodePacked(
            ".fb{font-weight:bold;}",
            ".g{color:#556832;}",
            ".p{color:#808000;}",
            ".h{color:#755A57;}",
            ".m{color:#C0C0C0;}",
            ".o{color:#207DF1;}",
            ".w{color:#556832;}",
            ".r{color:#9ACD32;}",
            ".s{color:#2E8B57;}"
        )
    );

    string constant SVG_HEADER = string(
        abi.encodePacked(
            "<svg version='2.0' encoding='utf-8' viewBox='0 0 576 576' preserveAspecRatio='xMidyMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
            "<style>",
            SVG_STYLES_GRID,
            SVG_STYLES_COLOR,
            "</style>",
            "<foreignObject x='0' y='0' width='576' height='576'>",
            "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>",
            "<div class='b'>"
        )
    );
    string constant SVG_FOOTER = string(abi.encodePacked("</div>", "</div>", "</foreignObject>", "</svg>"));

    mapping(Terrain => string[]) TERRAIN_CHARS;
    mapping(Terrain => string) TERRAIN_CLASS;

    constructor() Owned(msg.sender) {
        // Characters for rendered terrains
        TERRAIN_CHARS[Terrain.GRASSLAND] = [renderSpan(unicode'ⁿ'), renderSpan(".")];
        TERRAIN_CHARS[Terrain.PLAINS] = [renderSpan(unicode"ⁿ"), renderSpan('"')];
        TERRAIN_CHARS[Terrain.HILLS] = [renderSpan("n"), renderSpan(unicode"∩")];
        TERRAIN_CHARS[Terrain.MOUNTAINS] = [renderSpan(unicode"▲"), renderSpan(unicode"⌂")];
        TERRAIN_CHARS[Terrain.OCEAN] = [renderSpan(unicode"≈"), renderSpan(unicode"≋")];
        TERRAIN_CHARS[Terrain.WOODS] = [renderSpan(unicode"♠"), renderSpan(unicode"♣")];
        TERRAIN_CHARS[Terrain.RAINFOREST] = [renderSpan(unicode"♠"), renderSpan(unicode"Γ")];
        TERRAIN_CHARS[Terrain.SWAMP] = [renderSpan(unicode'"'), renderSpan(unicode"⌠")];

        TERRAIN_CLASS[Terrain.GRASSLAND] = "g fb";
        TERRAIN_CLASS[Terrain.PLAINS] = "p fb";
        TERRAIN_CLASS[Terrain.HILLS] = "h fb";
        TERRAIN_CLASS[Terrain.MOUNTAINS] = "m";
        TERRAIN_CLASS[Terrain.OCEAN] = "o fb";
        TERRAIN_CLASS[Terrain.WOODS] = "w fb";
        TERRAIN_CLASS[Terrain.RAINFOREST] = "r fb";
        TERRAIN_CLASS[Terrain.SWAMP] = "s";
    }

    function renderSpan(string memory char) internal pure returns (string memory) {
        return string.concat("<span>", char, "</span>");
    }

    function getSeed(address owner) internal pure returns (bytes memory) {
        bytes32[9] memory hashes;
        for (uint8 i; i < 9;) {
            if (i == 0) {
                hashes[i] = keccak256(abi.encodePacked(owner));
            } else {
                hashes[i] = keccak256(bytes.concat(hashes[i - 1]));
            }

            unchecked {
                ++i;
            }
        }
        // 9 x bytes32 = 288 bytes total
        bytes memory hash = bytes.concat(
            hashes[0], hashes[1], hashes[2], hashes[3], hashes[4], hashes[5], hashes[6], hashes[7], hashes[8]
        );

        return hash;
    }

    function getTerrains(bytes memory seed) public pure returns (Terrain[576] memory) {
        // 4 bits per terrain, 288 byte input
        Terrain[576] memory terrains;
        uint256 seedLength = seed.length;
        uint16 unknownTerrainCount;
        for (uint16 i = 0; i < seedLength;) {
            bytes1 b = seed[i];

            // We only need 4 bits per terrain
            uint8 upper = uint8(b >> 4);
            uint8 lower = uint8(b & 0x0F);

            // UNKNOWN is weighted heavier, truncate down for valid enum value
            if (upper > 8) upper = 8;
            if (lower > 8) lower = 8;

            Terrain tUpper = Terrain(upper);
            Terrain tLower = Terrain(lower);

            uint16 terrainIdx = i * 2;
            terrains[terrainIdx] = tUpper;
            terrains[terrainIdx + 1] = tLower;

            if (tUpper == Terrain.UNKNOWN) {
                ++unknownTerrainCount;
            }
            if (tLower == Terrain.UNKNOWN) {
                ++unknownTerrainCount;
            }

            unchecked {
                ++i;
            }
        }

        // Build up arr of unknown terrain indices
        uint16[] memory unknownTerrainIdxs = new uint16[](unknownTerrainCount);
        uint16 unknownTerrainIdxsIdx = 0;
        uint256 terrainsLength = terrains.length;
        for (uint16 i = 0; i < terrainsLength;) {
            if (terrains[i] == Terrain.UNKNOWN) {
                unknownTerrainIdxs[unknownTerrainIdxsIdx] = i;
                unchecked {
                    ++unknownTerrainIdxsIdx;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Shuffle unknown terrain idxs so that we don't resolve in order
        bytes32 temp;
        assembly {
            temp := mload(add(seed, 32))
        }

        uint256 offsetSeed = uint256(temp);
        for (uint16 i = 0; i < unknownTerrainCount;) {
            uint16 n = uint16(i + offsetSeed % (unknownTerrainCount - i));
            uint16 temp = unknownTerrainIdxs[n];
            unknownTerrainIdxs[n] = unknownTerrainIdxs[i];
            unknownTerrainIdxs[i] = temp;

            unchecked {
                ++i;
            }
        }

        // Resolve UNKNOWN terrains according to neighbors
        for (uint16 i = 0; i < unknownTerrainCount;) {
            uint16 idx = unknownTerrainIdxs[i];
            uint16[9] memory neighborTerrainCounts;

            Terrain[8] memory neighbors = [
                // Top Left
                idx < (GRID_SIZE + 1) || (idx % GRID_SIZE) == 0
                    ? Terrain.UNKNOWN
                    : terrains[idx - (GRID_SIZE + 1)],
                // Top
                idx < GRID_SIZE ? Terrain.UNKNOWN : terrains[idx - GRID_SIZE],
                // Top Right
                idx < (GRID_SIZE - 1) || (idx % GRID_SIZE) == GRID_SIZE - 1
                    ? Terrain.UNKNOWN
                    : terrains[idx - (GRID_SIZE - 1)],
                // Left
                idx < 1 || (idx % GRID_SIZE) == 0 ? Terrain.UNKNOWN : terrains[idx - 1],
                // Right
                idx + 1 > (terrains.length - 1) || (idx % GRID_SIZE) == GRID_SIZE - 1
                    ? Terrain.UNKNOWN
                    : terrains[idx + 1],
                // Bottom Left
                idx + (GRID_SIZE - 1) > (terrains.length - 1) || (idx % GRID_SIZE) == 0
                    ? Terrain.UNKNOWN
                    : terrains[idx + (GRID_SIZE - 1)],
                // Bottom
                idx + GRID_SIZE > (terrains.length - 1)
                    ? Terrain.UNKNOWN
                    : terrains[idx + GRID_SIZE],
                // Bottom Right
                idx + GRID_SIZE + 1 > (terrains.length - 1) || (idx % GRID_SIZE) == (GRID_SIZE - 1)
                    ? Terrain.UNKNOWN
                    : terrains[idx + GRID_SIZE + 1]
            ];

            for (uint8 j = 0; j < 8;) {
                ++neighborTerrainCounts[uint8(neighbors[j])];
                unchecked {
                    ++j;
                }
            }

            // Find the terrain type with the highest neighbor count, ignoring UNKNOWN
            Terrain mostNeighborTerrain = Terrain.UNKNOWN;
            for (uint8 j = 0; j < 8;) {
                if (
                    mostNeighborTerrain == Terrain.UNKNOWN
                        || neighborTerrainCounts[j] > neighborTerrainCounts[uint8(mostNeighborTerrain)]
                ) {
                    mostNeighborTerrain = Terrain(j);
                }

                unchecked {
                    ++j;
                }
            }

            terrains[idx] = mostNeighborTerrain;

            unchecked {
                ++i;
            }
        }

        return terrains;
    }

    function getImage(address owner) public view returns (string memory) {
        // https://etherscan.deth.net/address/0x49957ca2f1e314c2cf70701816bf6283b7215811#code
        // https://etherscan.deth.net/address/0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2#code

        bytes memory seed = getSeed(owner);
        Terrain[576] memory terrains = getTerrains(seed);
        string[576] memory renderedTerrains;

        // 1 bit per character, 4 bits per terrain
        uint256 seedLength = seed.length;
        for (uint16 i = 0; i < seedLength;) {
            bool[8] memory bits;
            for (uint8 j = 0; j < 8;) {
                bits[j] = (seed[i] & bytes1(uint8(1) << j)) != 0;

                unchecked {
                    ++j;
                }
            }

            for (uint8 j = 0; j < 2;) {
                Terrain terrain = terrains[(i * 2) + j];

                if (/**terrain == Terrain.GRASSLAND || terrain == Terrain.PLAINS || terrain == Terrain.OCEAN || terrain == Terrain.SWAMP**/ false) {
                    renderedTerrains[(i * 2) + j] = string.concat(
                        "<div class='",
                        TERRAIN_CLASS[terrain],
                        " t4'>",
                        TERRAIN_CHARS[terrain][bits[0 + (j * 4)] ? 1 : 0],
                        TERRAIN_CHARS[terrain][bits[1 + (j * 4)] ? 1 : 0],
                        TERRAIN_CHARS[terrain][bits[2 + (j * 4)] ? 1 : 0],
                        TERRAIN_CHARS[terrain][bits[3 + (j * 4)] ? 1 : 0],
                        "</div>"
                    );
                } else {
                    renderedTerrains[(i * 2) + j] = string.concat(
                        "<div class='",
                        TERRAIN_CLASS[terrain],
                        " t1'>",
                        TERRAIN_CHARS[terrain][bits[0 + (j * 4)] ? 1 : 0],
                        "</div>"
                    );
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        string memory output = SVG_HEADER;
        for (uint16 i = 0; i < 72;) {
            output = string.concat(
                output,
                renderedTerrains[i * 8],
                renderedTerrains[i * 8 + 1],
                renderedTerrains[i * 8 + 2],
                renderedTerrains[i * 8 + 3],
                renderedTerrains[i * 8 + 4],
                renderedTerrains[i * 8 + 5],
                renderedTerrains[i * 8 + 6],
                renderedTerrains[i * 8 + 7]
            );

            unchecked {
                ++i;
            }
        }

        output = string.concat(output, SVG_FOOTER);

        return output;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        address owner = IERC721(msg.sender).ownerOf(tokenId);

        string memory image = getImage(owner);
        bytes memory dataURI = abi.encodePacked('{"image": "', owner, '"}');

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }
}
