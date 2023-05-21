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
        SWAMP,
        UNKNOWN
    }

    uint8 constant GRID_ROWS = 12;
    uint8 constant GRID_COLS = 20;

    string constant SVG_STYLES_GRID = string(
        abi.encodePacked(
            "@font-face{font-family:Unifont;src:url('https://raw.githubusercontent.com/fontsource/font-files/main/fonts/other/unifont/files/unifont-latin-400-normal.woff');}",
            ".a{width:208px;height:208px;background-color:black;box-sizing:border-box;font-size:16px;font-family:Unifont;display:flex;flex-direction:column;justify-content:center;align-items:center;}",
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
            "<svg version='2.0' encoding='utf-8' viewBox='0 0 208 208' preserveAspectRatio='xMidYMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
            "<style>",
            SVG_STYLES_GRID,
            SVG_STYLES_COLOR,
            "</style>",
            "<foreignObject x='0' y='0' width='208' height='208'>",
            "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>"
        )
    );
    string constant SVG_FOOTER = string(abi.encodePacked("</div>", "</foreignObject>", "</svg>"));

    // Terrain to HTML-rendered character options
    mapping(Terrain => string[]) TERRAIN_CHARS;

    // Address to generated terrains
    mapping(address => Terrain[240]) terrainsByOwner;

    constructor() Owned(msg.sender) {
        TERRAIN_CHARS[Terrain.GRASSLAND] = [renderChar(unicode"ⱱ", "g t"), renderChar(unicode"ⱳ", "g t")];
        TERRAIN_CHARS[Terrain.PLAINS] = [renderChar(unicode"ᵥ", "p t"), renderChar(unicode"⩊", "p t")];
        TERRAIN_CHARS[Terrain.HILLS] = [renderChar(unicode"⌒", "h t"), renderChar(unicode"∩", "h t")];
        TERRAIN_CHARS[Terrain.MOUNTAINS] = [renderChar(unicode"⋀", "m t"), renderChar(unicode"∆", "m t")];
        TERRAIN_CHARS[Terrain.OCEAN] = [renderChar(unicode"≈", "o t"), renderChar(unicode"≋", "o t")];
        TERRAIN_CHARS[Terrain.WOODS] = [renderChar(unicode"ᛉ", "w t"), renderChar(unicode"↟", "w t")];
        TERRAIN_CHARS[Terrain.RAINFOREST] = [renderChar(unicode"ᛉ", "r t"), renderChar(unicode"↟", "r t")];
        TERRAIN_CHARS[Terrain.SWAMP] = [renderChar(unicode"„", "s t"), renderChar(unicode"⩫", "s t")];
    }

    function renderChar(string memory char, string memory className) internal pure returns (string memory) {
        return string.concat("<div class='", className, "'>", char, "</div>");
    }

    // Generate 120 bit seed from address
    function getSeed(address owner) internal pure returns (bytes memory) {
        bytes32[4] memory hashes;
        for (uint8 i; i < 4;) {
            if (i == 0) {
                hashes[i] = keccak256(abi.encodePacked(owner));
            } else {
                hashes[i] = keccak256(bytes.concat(hashes[i - 1]));
            }

            unchecked {
                ++i;
            }
        }

        bytes memory output = bytes.concat(
            hashes[0],
            hashes[1],
            hashes[2],
            hashes[3]
        );

        return output;
    }

    function generateTerrains(address owner) public {
        bytes memory seed = getSeed(owner);

        // Map of possible terrains. Derived from seed, may be biased - certain terrain types 
        // may be weighted more heavily and others not at all.
        Terrain[16] memory sourceTerrains;
        for (uint8 i = 0; i < 16;) {
            sourceTerrains[i] = Terrain(uint8(seed[i]) % (uint8(type(Terrain).max)));

            unchecked {
                ++i;
            }
        }

        Terrain[240] memory terrains;
        for (uint16 i = 0; i < 120;) {
            bytes1 b = seed[i];

            terrains[i * 2] = sourceTerrains[uint8(b >> 4)];
            terrains[i * 2 + 1] = sourceTerrains[uint8(b & 0x0F)];

            unchecked {
                ++i;
            }
        }

        // Build an array of Shuffled terrain indices so that we don't smoothe in order
        uint16[240] memory terrainIndicies;
        for (uint16 i = 0; i < 240;) {
            terrainIndicies[i] = i;

            unchecked {
                ++i;
            }
        }
        bytes32 temp;
        assembly {
            temp := mload(add(seed, 32))
        }
        uint256 offsetSeed = uint256(temp);
        for (uint16 i = 0; i < 240;) {
            uint16 n = uint16(i + offsetSeed % (240 - i));
            uint16 temp = terrainIndicies[n];
            terrainIndicies[n] = terrainIndicies[i];
            terrainIndicies[i] = temp;

            unchecked {
                ++i;
            }
        }

        // Smoothe terrains according to neigbors
        for (uint16 i = 0; i < 240;) {
            uint16 idx = terrainIndicies[i];
            uint8[9] memory neighborTerrainCounts;
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

        terrainsByOwner[owner] = terrains;
    }

    function getImage(address owner) public view returns (string memory) {
        bytes memory seed = getSeed(owner);
        Terrain[240] memory terrains = terrainsByOwner[owner];
        string[240] memory renderedTerrains;

        // 1 bit per character, 4 bits per terrain
        for (uint16 i = 0; i < 120;) {
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
            for (uint16 j = 0; j < 3;) {
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
                } else if (j == 2) {
                    output = string.concat(
                        output,
                        renderedTerrains[i * GRID_COLS + j * 8],
                        renderedTerrains[i * GRID_COLS + j * 8 + 1],
                        renderedTerrains[i * GRID_COLS + j * 8 + 2],
                        renderedTerrains[i * GRID_COLS + j * 8 + 3],
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
