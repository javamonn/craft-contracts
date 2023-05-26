// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "forge-std/Test.sol";

contract CraftSettlement is ERC721, Owned {
    using Counters for Counters.Counter;
    using Strings for uint256;

    error InvalidSignature();
    error HasSettled();
    error Soulbound();

    struct Metadata {
        uint16[240] terrainIndexes;
        address settler;
    }

    struct Terrain {
        string id;
        string[] renderedCharacters;
        string styles;
    }

    // Dungeon Master used to authenticate mints
    address public dungeonMaster;

    // Renderable terrains, keyed in metadata by index.
    // Range 0 - 7 inclusive are generated at time of settlement, further terrains
    // are set by event and decision.
    Terrain[] terrains;

    // Token ID to metadata
    mapping(uint256 => Metadata) metadataByTokenId;

    Counters.Counter internal tokenIdCounter;

    uint8 constant GRID_ROWS = 12;
    uint8 constant GRID_COLS = 20;
    uint8 constant SETTLEABLE_TERRAIN_MAX_INDEX = 7;
    string constant BASE_STYLES = string(
        abi.encodePacked(
            "@font-face{font-family:Unifont;src:url('https://raw.githubusercontent.com/fontsource/font-files/main/fonts/other/unifont/files/unifont-latin-400-normal.woff');}",
            ".a{width:208px;height:208px;background-color:black;box-sizing:border-box;font-size:16px;font-family:Unifont;display:flex;flex-direction:column;justify-content:center;align-items:center;}",
            "svg{overflow-x:hidden;overflow-y:hidden;margin:0;padding:0;}",
            ".row{height:1rem;}",
            ".t{width:.6rem;display:inline-block;height:1rem;}",
            ".i{font-style:italic;}"
        )
    );
    string constant SVG_FOOTER = string(abi.encodePacked("</div>", "</foreignObject>", "</svg>"));

    constructor(address _dungeonMaster) Owned(msg.sender) ERC721("craft.game settlement", "CRAFT_SETTLEMENT") {
        dungeonMaster = _dungeonMaster;

        terrains.push(Terrain("GRASSLAND", new string[](0), ".g{color:#6c0;}"));
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱱ", "g t"));
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱳ", "g t"));

        terrains.push(Terrain("PLAIN", new string[](0), ".p{color:#993;}"));
        terrains[1].renderedCharacters.push(renderChar(unicode"ᵥ", "p t"));
        terrains[1].renderedCharacters.push(renderChar(unicode"⩊", "p t"));

        terrains.push(Terrain("HILL", new string[](0), ".h{color:#630;}"));
        terrains[2].renderedCharacters.push(renderChar(unicode"⌒", "h t"));
        terrains[2].renderedCharacters.push(renderChar(unicode"∩", "h t"));

        terrains.push(Terrain("MOUNTAIN", new string[](0), ".m{color:#ccc;}"));
        terrains[3].renderedCharacters.push(renderChar(unicode"⋀", "m t"));
        terrains[3].renderedCharacters.push(renderChar(unicode"∆", "m t"));

        terrains.push(Terrain("OCEAN", new string[](0), ".o{color:#00f;}"));
        terrains[4].renderedCharacters.push(renderChar(unicode"≈", "o t"));
        terrains[4].renderedCharacters.push(renderChar(unicode"≋", "o t"));

        terrains.push(Terrain("WOODS", new string[](0), ".w{color:#060;}"));
        terrains[5].renderedCharacters.push(renderChar(unicode"ᛉ", "w t"));
        terrains[5].renderedCharacters.push(renderChar(unicode"↟", "w t"));

        terrains.push(Terrain("RAINFOREST", new string[](0), ".r{color:#9c3;}"));
        terrains[6].renderedCharacters.push(renderChar(unicode"ᛉ", "r t"));
        terrains[6].renderedCharacters.push(renderChar(unicode"↟", "r t"));

        terrains.push(Terrain("SWAMP", new string[](0), ".s{color:#3c9;}"));
        terrains[7].renderedCharacters.push(renderChar(unicode"„", "s t"));
        terrains[7].renderedCharacters.push(renderChar(unicode"⩫", "s t"));
    }

    modifier hasNotSettled(address to) {
        if (_balanceOf[to] > 0) {
            revert HasSettled();
        }

        _;
    }

    modifier hasSignature(address to, bytes calldata sig) {
        (address signingAddress,) = ECDSA.tryRecover(ECDSA.toEthSignedMessageHash(settleHash(to)), sig);
        if (signingAddress != dungeonMaster) {
            revert InvalidSignature();
        }

        _;
    }

    // Render a terrain char into HTML as a classed div
    function renderChar(string memory char, string memory className) internal pure returns (string memory) {
        return string.concat("<div class='", className, "'>", char, "</div>");
    }

    function renderImage(uint256 tokenId) public view returns (string memory) {
        Metadata memory metadata = metadataByTokenId[tokenId];
        bytes memory seed = getSeed(metadata.settler);
        string[240] memory renderedTerrains;

        // terrain idx => occurance count within rendered terrains
        uint16[] memory terrainIdxCount = new uint16[](terrains.length);

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
                uint16 terrainIdx = metadata.terrainIndexes[(i * 2) + j];
                ++terrainIdxCount[terrainIdx];
                renderedTerrains[(i * 2) + j] = terrains[terrainIdx].renderedCharacters[bits[0 + (j * 4)] ? 1 : 0];

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        string memory outputStyles = BASE_STYLES;
        for (uint16 terrainIdx = 0; terrainIdx < terrainIdxCount.length;) {
            if (terrainIdxCount[terrainIdx] > 0) {
                outputStyles = string.concat(outputStyles, terrains[terrainIdx].styles);
            }
            unchecked {
                ++terrainIdx;
            }
        }

        string memory output = string.concat(
            "<svg version='2.0' encoding='utf-8' viewBox='0 0 208 208' preserveAspectRatio='xMidYMid' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg'>",
            "<style>",
            outputStyles,
            "</style>",
            "<foreignObject x='0' y='0' width='208' height='208'>",
            "<div class='a' xmlns='http://www.w3.org/1999/xhtml'>"
        );

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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory image = renderImage(tokenId);
        bytes memory dataURI = abi.encodePacked('{"image": "', owner, '"}');

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    // Derive 128 bit seed from owner address, only 120 bits will be used for terrain generation
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

        bytes memory output = bytes.concat(hashes[0], hashes[1], hashes[2], hashes[3]);

        return output;
    }

    function generateTerrains(address settler, uint256 tokenId) internal {
        bytes memory seed = getSeed(settler);

        // Map of possible terrains. Derived from seed, may be biased - certain 
        // terrain types may be weighted more heavily and others not at all.
        uint8[16] memory sourceTerrains;
        for (uint8 i = 0; i < 16;) {
            sourceTerrains[i] = uint8(seed[i]) % (SETTLEABLE_TERRAIN_MAX_INDEX + 1);

            unchecked {
                ++i;
            }
        }

        uint16[240] memory terrainIndexes;
        for (uint16 i = 0; i < 120;) {
            bytes1 b = seed[i];

            terrainIndexes[i * 2] = sourceTerrains[uint8(b >> 4)];
            terrainIndexes[i * 2 + 1] = sourceTerrains[uint8(b & 0x0F)];

            unchecked {
                ++i;
            }
        }

        // Build an array of shuffled terrain indices so that we don't smoothe in order
        uint16[240] memory shuffledTerrainIndexes;
        for (uint16 i = 0; i < 240;) {
            shuffledTerrainIndexes[i] = i;

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
            uint16 temp = shuffledTerrainIndexes[n];
            shuffledTerrainIndexes[n] = shuffledTerrainIndexes[i];
            shuffledTerrainIndexes[i] = temp;

            unchecked {
                ++i;
            }
        }

        // Smoothe terrains according to neigbors
        for (uint16 i = 0; i < 240;) {
            uint16 idx = shuffledTerrainIndexes[i];
            uint8[8] memory neighborTerrainCounts;

            // Top Left
            if (idx >= (GRID_COLS + 1) && (idx % GRID_COLS) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (GRID_COLS + 1)])];
            }

            // Top
            if (idx >= GRID_COLS) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - GRID_COLS])];
            }

            // Top Right
            if (idx >= (GRID_COLS - 1) && (idx % GRID_COLS) != GRID_COLS - 1) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (GRID_COLS - 1)])];
            }

            // Left
            if (idx >= 1 && (idx % GRID_COLS) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - 1])];
            }

            // Right
            if (idx + 1 <= (terrainIndexes.length - 1) && (idx % GRID_COLS) != GRID_COLS - 1) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + 1])];
            }

            // Bottom Left
            if (idx + (GRID_COLS - 1) <= (terrainIndexes.length - 1) && (idx % GRID_COLS) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + (GRID_COLS - 1)])];
            }

            // Bottom
            if (idx + GRID_COLS <= (terrainIndexes.length - 1)) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + GRID_COLS])];
            }

            // Bottom Right
            if (idx + GRID_COLS + 1 <= (terrainIndexes.length - 1) && (idx % GRID_COLS) != (GRID_COLS - 1)) {

                ++neighborTerrainCounts[uint8(terrainIndexes[idx + GRID_COLS + 1])];
            }

            uint16 mostNeighborTerrain = 0;
            for (uint8 j = 0; j < neighborTerrainCounts.length;) {
                if (
                    neighborTerrainCounts[j] > neighborTerrainCounts[uint8(mostNeighborTerrain)]
                ) {
                    mostNeighborTerrain = j;
                }

                unchecked {
                    ++j;
                }
            }

            terrainIndexes[idx] = mostNeighborTerrain;

            unchecked {
                ++i;
            }
        }

        metadataByTokenId[tokenId] = Metadata(terrainIndexes, settler);
    }

    function setDungeonMaster(address _dungeonMaster) external onlyOwner {
        dungeonMaster = _dungeonMaster;
    }

    function settleHash(address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(to));
    }

    function nextTokenId() private returns (uint256) {
        tokenIdCounter.increment();
        return tokenIdCounter.current();
    }

    function settle(bytes calldata sig) external hasNotSettled(msg.sender) hasSignature(msg.sender, sig) {
        uint256 tokenId = nextTokenId();
        generateTerrains(msg.sender, tokenId);
        _safeMint(msg.sender, tokenId);
    }

    /**
     * Settlements are soulbound - disable ERC721 functionality relating to transfer.
     */

    function approve(address, uint256) public override {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) public override {
        revert Soulbound();
    }

    function transferFrom(address, address, uint256) public override {
        revert Soulbound();
    }
}
