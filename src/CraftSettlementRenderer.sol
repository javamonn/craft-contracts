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

    uint8 constant GRID_ROWS = 24;
    uint8 constant GRID_COLS = 40;
    string constant SVG_STYLES_GRID = string(
        abi.encodePacked(
            "@font-face{font-family:Unifont;src:url('https://raw.githubusercontent.com/fontsource/fontsource/main/fonts/other/unifont/files/unifont-latin-400-normal.woff');}",
            ".a{width:416px;height:416px;background-color:black;box-sizing:border-box;font-size:16px;font-family:Unifont;display:flex;flex-direction:column;justify-content:center;align-items:center;}",
            "svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
            ".row{height:1rem;}",
            ".t{width:.6rem;display:inline-block;height:1rem;}",
            ".i{font-style:italic;}"
        )
    );
    string constant SVG_STYLES_COLOR = string(
        abi.encodePacked(
            ".g{color:#6c0;}",
            ".p{color:#993;}",
            ".h{color:#630;}",
            ".m{color:#ccc;}",
            ".o{color:#00f;}",
            ".w{color:#060;}",
            ".r{color:#9c3;}",
            ".s{color:#3c9;}"
        )
    );

    string constant SVG_HEADER = string(
        abi.encodePacked(
            "<svg version='2.0' encoding='utf-8' viewBox='0 0 416 416' preserveAspectRatio='xMidYMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
            "<style>",
            SVG_STYLES_GRID,
            SVG_STYLES_COLOR,
            "</style>",
            "<foreignObject x='0' y='0' width='416' height='416'>",
            "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>"
        )
    );
    string constant SVG_FOOTER = string(abi.encodePacked("</div>", "</foreignObject>", "</svg>"));

    mapping(Terrain => string[]) TERRAIN_CHARS;

    constructor() Owned(msg.sender) {
        // Characters for rendered terrains
        TERRAIN_CHARS[Terrain.GRASSLAND] = [renderChar(unicode'ⱱ', "g t"), renderChar(unicode"ⱳ", "g t")];
        TERRAIN_CHARS[Terrain.PLAINS] = [renderChar(unicode"ᵥ", "p t"), renderChar(unicode'⩊', "p t")];
        TERRAIN_CHARS[Terrain.HILLS] = [renderChar(unicode"⌒", "h t"), renderChar(unicode"∩", "h t")];
        TERRAIN_CHARS[Terrain.MOUNTAINS] = [renderChar(unicode"⋀", "m t"), renderChar(unicode"∆", "m t")];
        TERRAIN_CHARS[Terrain.OCEAN] = [renderChar(unicode"≈", "o t"), renderChar(unicode"≋", "o t")];
        TERRAIN_CHARS[Terrain.WOODS] = [renderChar(unicode"ᛉ", "w t"), renderChar(unicode"↟", "w t")];
        TERRAIN_CHARS[Terrain.RAINFOREST] = [renderChar(unicode"ᛉ", "r t"), renderChar(unicode"↟", "r t")];
        TERRAIN_CHARS[Terrain.SWAMP] = [renderChar(unicode'„', "s t"), renderChar(unicode"⩫", "s t")];
    }

    function renderChar(string memory char, string memory className) internal pure returns (string memory) {
        return string.concat("<div class='", className, "'>", char, "</div>");
    }

    function getSeed(address owner) internal pure returns (bytes memory) {
        bytes32[15] memory hashes;

        for (uint8 i; i < 15;) {
            if (i == 0) {
                hashes[i] = keccak256(abi.encodePacked(owner));
            } else {
                hashes[i] = keccak256(bytes.concat(hashes[i - 1]));
            }

            unchecked {
                ++i;
            }
        }

        bytes memory output;
        for (uint8 i; i < 3;) {
            output = bytes.concat(
                output,
                hashes[i * 5],
                hashes[i * 5 + 1],
                hashes[i * 5 + 2],
                hashes[i * 5 + 3],
                hashes[i * 5 + 4]
            );

            unchecked {
                ++i;
            }
        }

        return output;
    }

    function getTerrains(bytes memory seed) public pure returns (Terrain[960] memory) {

        // 4 bits per terrain, 480 byte input
        Terrain[960] memory terrains;
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
                idx < (GRID_COLS + 1) || (idx % GRID_COLS) == 0
                    ? Terrain.UNKNOWN
                    : terrains[idx - (GRID_COLS + 1)],
                // Top
                idx < GRID_COLS ? Terrain.UNKNOWN : terrains[idx - GRID_COLS],
                // Top Right
                idx < (GRID_COLS - 1) || (idx % GRID_COLS) == GRID_COLS - 1
                    ? Terrain.UNKNOWN
                    : terrains[idx - (GRID_COLS - 1)],
                // Left
                idx < 1 || (idx % GRID_COLS) == 0 ? Terrain.UNKNOWN : terrains[idx - 1],
                // Right
                idx + 1 > (terrains.length - 1) || (idx % GRID_COLS) == GRID_COLS - 1
                    ? Terrain.UNKNOWN
                    : terrains[idx + 1],
                // Bottom Left
                idx + (GRID_COLS - 1) > (terrains.length - 1) || (idx % GRID_COLS) == 0
                    ? Terrain.UNKNOWN
                    : terrains[idx + (GRID_COLS - 1)],
                // Bottom
                idx + GRID_COLS > (terrains.length - 1)
                    ? Terrain.UNKNOWN
                    : terrains[idx + GRID_COLS],
                // Bottom Right
                idx + GRID_COLS + 1 > (terrains.length - 1) || (idx % GRID_COLS) == (GRID_COLS - 1)
                    ? Terrain.UNKNOWN
                    : terrains[idx + GRID_COLS + 1]
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
        bytes memory seed = getSeed(owner);
        Terrain[960] memory terrains = getTerrains(seed);
        string[960] memory renderedTerrains;

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
                renderedTerrains[(i * 2) + j] = TERRAIN_CHARS[terrain][bits[0 + (j * 4)] ? 1 : 0];

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        string memory output = SVG_HEADER;
        for (uint16 i = 0; i < GRID_ROWS;) {
            for (uint16 j = 0; j < 5;) {
                if (j == 0) {
                    output = string.concat(
                        output,
                        "<div class='row'>",
                        renderedTerrains[i * GRID_COLS + j * 8],
                        renderedTerrains[i * GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * GRID_COLS + j * 8 + 3],
                        renderedTerrains[i * GRID_COLS + j * 8 + 4],
                        renderedTerrains[i * GRID_COLS + j * 8 + 5],
                        renderedTerrains[i * GRID_COLS + j * 8 + 6],
                        renderedTerrains[i * GRID_COLS + j * 8 + 7]
                    );
                } else if (j == 4) {
                    output = string.concat(
                        output,
                        renderedTerrains[i * GRID_COLS + j * 8],
                        renderedTerrains[i * GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * GRID_COLS + j * 8 + 3],
                        renderedTerrains[i * GRID_COLS + j * 8 + 4],
                        renderedTerrains[i * GRID_COLS + j * 8 + 5],
                        renderedTerrains[i * GRID_COLS + j * 8 + 6],
                        renderedTerrains[i * GRID_COLS + j * 8 + 7],
                        "</div>"
                    );
                } else {
                    output = string.concat(
                        output,
                        renderedTerrains[i * GRID_COLS + j * 8],
                        renderedTerrains[i * GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * GRID_COLS + j * 8 + 3],
                        renderedTerrains[i * GRID_COLS + j * 8 + 4],
                        renderedTerrains[i * GRID_COLS + j * 8 + 5],
                        renderedTerrains[i * GRID_COLS + j * 8 + 6],
                        renderedTerrains[i * GRID_COLS + j * 8 + 7]
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
