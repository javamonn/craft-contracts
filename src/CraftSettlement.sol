// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Auth.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./ICraftSettlementRenderer.sol";
import "./CraftSettlementData.sol";

contract CraftSettlement is ERC721, Auth {
    using Counters for Counters.Counter;

    error InvalidSignature();
    error HasSettled();
    error Soulbound();

    event SetMetadataTerrain(uint256 indexed tokenId, uint8 terrainIndexesIdx, uint16 newTerrainIndex);

    // Dungeon Master used to authenticate mints
    address public dungeonMaster;

    // Renderer used for tokenURI
    ICraftSettlementRenderer public renderer;

    // Renderable terrains, keyed in metadata by index.
    // Range 0 - 7 inclusive are generated at time of settlement, further terrains
    // are set by event and decision.
    CraftSettlementData.Terrain[] internal terrains;

    // Token ID to metadata
    mapping(uint256 => CraftSettlementData.Metadata) internal metadataByTokenId;

    Counters.Counter internal tokenIdCounter;

    uint8 constant SETTLEABLE_TERRAIN_MAX_INDEX = 7;

    constructor(address _dungeonMaster, ICraftSettlementRenderer _renderer, Authority _authority)
        ERC721("craft.game settlement", "SETTLEMENT")
        Auth(msg.sender, _authority)
    {
        dungeonMaster = _dungeonMaster;
        renderer = _renderer;

        terrains.push(CraftSettlementData.Terrain("Grasslands", new string[](0), ".g{color:#6c0;}"));
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱱ", "g t"));
        terrains[0].renderedCharacters.push(renderChar(unicode"ⱳ", "g t"));

        terrains.push(CraftSettlementData.Terrain("Plains", new string[](0), ".p{color:#993;}"));
        terrains[1].renderedCharacters.push(renderChar(unicode"ᵥ", "p t"));
        terrains[1].renderedCharacters.push(renderChar(unicode"⩊", "p t"));

        terrains.push(CraftSettlementData.Terrain("Hills", new string[](0), ".h{color:#630;}"));
        terrains[2].renderedCharacters.push(renderChar(unicode"⌒", "h t"));
        terrains[2].renderedCharacters.push(renderChar(unicode"∩", "h t"));

        terrains.push(CraftSettlementData.Terrain("Mountains", new string[](0), ".m{color:#ccc;}"));
        terrains[3].renderedCharacters.push(renderChar(unicode"⋀", "m t"));
        terrains[3].renderedCharacters.push(renderChar(unicode"∆", "m t"));

        terrains.push(CraftSettlementData.Terrain("Oceans", new string[](0), ".o{color:#00f;}"));
        terrains[4].renderedCharacters.push(renderChar(unicode"≈", "o t"));
        terrains[4].renderedCharacters.push(renderChar(unicode"≋", "o t"));

        terrains.push(CraftSettlementData.Terrain("Woods", new string[](0), ".w{color:#060;}"));
        terrains[5].renderedCharacters.push(renderChar(unicode"ᛉ", "w t"));
        terrains[5].renderedCharacters.push(renderChar(unicode"↟", "w t"));

        terrains.push(CraftSettlementData.Terrain("Rainforests", new string[](0), ".r{color:#9c3;}"));
        terrains[6].renderedCharacters.push(renderChar(unicode"ᛉ", "r t"));
        terrains[6].renderedCharacters.push(renderChar(unicode"↟", "r t"));

        terrains.push(CraftSettlementData.Terrain("Swamps", new string[](0), ".s{color:#3c9;}"));
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

    function generateTerrains(address settler) public pure returns (uint16[240] memory) {
        bytes memory seed = CraftSettlementData.getSeedForSettler(settler);

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
            if (idx >= (CraftSettlementData.GRID_COLS + 1) && (idx % CraftSettlementData.GRID_COLS) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (CraftSettlementData.GRID_COLS + 1)])];
            }

            // Top
            if (idx >= CraftSettlementData.GRID_COLS) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - CraftSettlementData.GRID_COLS])];
            }

            // Top Right
            if (
                idx >= (CraftSettlementData.GRID_COLS - 1)
                    && (idx % CraftSettlementData.GRID_COLS) != CraftSettlementData.GRID_COLS - 1
            ) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (CraftSettlementData.GRID_COLS - 1)])];
            }

            // Left
            if (idx >= 1 && (idx % CraftSettlementData.GRID_COLS) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - 1])];
            }

            // Right
            if (
                idx + 1 <= (terrainIndexes.length - 1)
                    && (idx % CraftSettlementData.GRID_COLS) != CraftSettlementData.GRID_COLS - 1
            ) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + 1])];
            }

            // Bottom Left
            if (
                idx + (CraftSettlementData.GRID_COLS - 1) <= (terrainIndexes.length - 1)
                    && (idx % CraftSettlementData.GRID_COLS) != 0
            ) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + (CraftSettlementData.GRID_COLS - 1)])];
            }

            // Bottom
            if (idx + CraftSettlementData.GRID_COLS <= (terrainIndexes.length - 1)) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + CraftSettlementData.GRID_COLS])];
            }

            // Bottom Right
            if (
                idx + CraftSettlementData.GRID_COLS + 1 <= (terrainIndexes.length - 1)
                    && (idx % CraftSettlementData.GRID_COLS) != (CraftSettlementData.GRID_COLS - 1)
            ) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + CraftSettlementData.GRID_COLS + 1])];
            }

            uint16 mostNeighborTerrain = 0;
            for (uint8 j = 0; j < neighborTerrainCounts.length;) {
                if (neighborTerrainCounts[j] > neighborTerrainCounts[uint8(mostNeighborTerrain)]) {
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

        return terrainIndexes;
    }

    function settle(bytes calldata sig) external hasNotSettled(msg.sender) hasSignature(msg.sender, sig) {
        uint256 tokenId = nextTokenId();
        uint16[240] memory terrainIndexes = generateTerrains(msg.sender);
        metadataByTokenId[tokenId] = CraftSettlementData.Metadata(terrainIndexes, msg.sender);
        _safeMint(msg.sender, tokenId);
    }

    function setRenderer(address _renderer) external requiresAuth {
        renderer = ICraftSettlementRenderer(_renderer);
    }

    function setDungeonMaster(address _dungeonMaster) external requiresAuth {
        dungeonMaster = _dungeonMaster;
    }

    function setTerrain(uint16 idx, CraftSettlementData.Terrain memory terrain) external requiresAuth {
        if (idx < terrains.length) {
            terrains[idx] = terrain;
        } else {
            terrains.push(terrain);
        }
    }

    function setMetadataTerrainIndex(uint256 tokenId, uint8 terrainIndexesIdx, uint16 newTerrainIndex)
        external
        requiresAuth
    {
        require(terrainIndexesIdx < 240, "terrainIndexesIdx is out of bounds.");
        require(newTerrainIndex < terrains.length, "newTerrainIndex is out of bounds");

        metadataByTokenId[tokenId].terrainIndexes[terrainIndexesIdx] = newTerrainIndex;
        emit SetMetadataTerrain(tokenId, terrainIndexesIdx, newTerrainIndex);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return renderer.tokenURI(address(this), tokenId);
    }

    function getMetadataByTokenId(uint256 tokenId) external view returns (CraftSettlementData.Metadata memory) {
        return metadataByTokenId[tokenId];
    }

    function getTerrainsLength() external view returns (uint256) {
        return terrains.length;
    }

    function getTerrain(uint256 idx) external view returns (CraftSettlementData.Terrain memory) {
        return terrains[idx];
    }

    function settleHash(address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(to));
    }

    function nextTokenId() private returns (uint256) {
        tokenIdCounter.increment();
        return tokenIdCounter.current();
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
