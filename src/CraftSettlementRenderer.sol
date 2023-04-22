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


    mapping(Terrain => string[]) RENDERED_TERRAIN;
    uint8 constant GRID_SIZE = 24;
    string constant SVG_STYLES = string(abi.encodePacked(
        ".a{width:576px;height:576px;background-color:black;}",
        ".b{box-sizing:border-box;width:576px;height:576px;padding:24px;display:grid;grid-template-columns:repeat(24, 1fr);grid-template-rows:repeat(24, 1fr);grid-gap: 0px;justify-content:space-between;font-family:monospace;}",
        "body,svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
        ".b>div{aspect-ratio:1/1;display:flex;justify-content:center;align-items:center;line-height:100%;}",
        ".g{color:#556832;}",
        ".p{color:#808000;}",
        ".h{color:#755A57;}",
        ".m{color:#C0C0C0;}",
        ".o{color:#207DF1;}",
        ".w{color:#556832;}",
        ".r{color:#9ACD32;}",
        ".s{color:#2E8B57;}"
    ));
    string constant SVG_HEADER = string(abi.encodePacked(
        "<svg version='2.0' encoding='utf-8' viewBox='0 0 576 576' preserveAspecRatio='xMidyMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
        "<style>",
        SVG_STYLES,
        "</style>",
        "<foreignObject x='0' y='0' width='576' height='576'>",
        "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>",
        "<div class='b'>"
    ));
    string constant SVG_FOOTER = string(abi.encodePacked("</div>", "</div>", "</foreignObject>", "</svg>"));

    constructor() Owned(msg.sender) {
        RENDERED_TERRAIN[Terrain.GRASSLAND] = [
            renderTerrain(unicode'"⌠"⌠', "g"),
            renderTerrain(unicode'⌠', "g"),
            renderTerrain(unicode'ⁿ', "g")
        ];
        RENDERED_TERRAIN[Terrain.PLAINS] = [
            renderTerrain('=', 'p'),
            renderTerrain('_ ', 'p')
        ];
        RENDERED_TERRAIN[Terrain.HILLS] = [
            renderTerrain(unicode'◠', 'h'),
            renderTerrain(unicode'∩', 'h')
        ];
        RENDERED_TERRAIN[Terrain.MOUNTAINS] = [
            renderTerrain(unicode'⛰', 'm'),
            renderTerrain(unicode'🏔','m')
        ];
        RENDERED_TERRAIN[Terrain.OCEAN] = [
            renderTerrain(unicode'≈', 'o'),
            renderTerrain(unicode'≋', 'o')
        ];
        RENDERED_TERRAIN[Terrain.WOODS] = [
            renderTerrain(unicode'🌲', 'w'),
            renderTerrain(unicode'🌳', 'w')
        ];
        RENDERED_TERRAIN[Terrain.RAINFOREST] = [
            renderTerrain(unicode'🌴', 'r'),
            renderTerrain(unicode'🌳', 'r')
        ];
        RENDERED_TERRAIN[Terrain.SWAMP] = [
            renderTerrain(unicode'░', "s"),
            renderTerrain(unicode'▒', "s"),
            renderTerrain(unicode'▓', "s")
        ];
    }

    function getTerrains(address owner) public pure returns (Terrain[576] memory) {
        // Build
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
        // 9xbytes32 = 288 bytes total
        bytes memory hash = bytes.concat(
            hashes[0], hashes[1], hashes[2], hashes[3], hashes[4], hashes[5], hashes[6], hashes[7], hashes[8]
        );

        // 4 bits per terrain, 288 byte input
        Terrain[576] memory terrains;
        uint256 hashLength = hash.length;
        uint16 unknownTerrainCount;
        for (uint16 i = 0; i < hashLength;) {
            bytes1 b = hash[i];

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
        uint256 offsetHash = uint256(keccak256(abi.encodePacked(owner)));
        for (uint16 i = 0; i < unknownTerrainCount;) {
            uint16 n = uint16(i + offsetHash % (unknownTerrainCount - i));
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

    function renderTerrain(string memory char, string memory className) private pure returns (string memory) {
        return string.concat(
            "<div class='",
            className,
            "'>",
            char,
            "</div>"
        );
    }

    function getRenderedTerrainIdx(uint16 terrainIdx, uint256 len, uint16 seed) private pure returns (uint8) {
        return uint8((terrainIdx + seed) % len);
    }

    function getRenderedTerrains(address owner) private view returns (string[576] memory) {
        Terrain[576] memory terrains = getTerrains(owner);

        uint256 renderSeed = uint256(keccak256(abi.encodePacked(owner)));
        string[576] memory renderedTerrains;
        for (uint16 i; i < 576;) {
            Terrain terrain = terrains[i];
            renderedTerrains[i] = RENDERED_TERRAIN[terrain][i + renderSeed % (RENDERED_TERRAIN[terrain].length - i)];
            unchecked {
                ++i;
            }
        }

        return renderedTerrains;
    }


    function getImage(address owner) public view returns (string memory) {
        // https://etherscan.deth.net/address/0x49957ca2f1e314c2cf70701816bf6283b7215811#code
        // https://etherscan.deth.net/address/0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2#code

        Terrain[576] memory terrains = getTerrains(owner);

        uint16 renderSeed = uint16(uint256(keccak256(abi.encodePacked(owner))));
        string[576] memory renderedTerrains;
        for (uint256 i = 0; i < 576;) {
            Terrain terrain = terrains[i];
            renderedTerrains[i] = RENDERED_TERRAIN[terrain][(i + renderSeed) % RENDERED_TERRAIN[terrain].length];
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
