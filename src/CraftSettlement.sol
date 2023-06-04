// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Auth.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./ICraftSettlementRenderer.sol";

contract CraftSettlement is ERC721, Auth {
    using Counters for Counters.Counter;

    struct Metadata {
        uint16[240] terrains;
        address settler;
        uint8 settlementIdx;
    }

    error InvalidSignature();
    error HasSettled();
    error Soulbound();
    error SettlementOutOfBounds();

    event SetMetadataTerrain(uint256 indexed tokenId, uint8 terrainIndex, uint16 newTerrain);

    uint8 public constant gridRows = 12;
    uint8 public constant gridCols = 20;
    uint8 internal constant settleableTerrainMaxIndex = 7;

    // Dungeon Master used to authenticate mints
    address public dungeonMaster;

    // Renderer used for tokenURI
    ICraftSettlementRenderer public renderer;

    // Token ID to metadata
    mapping(uint256 => Metadata) internal metadataByTokenId;

    Counters.Counter internal tokenIdCounter;

    constructor(address _dungeonMaster, ICraftSettlementRenderer _renderer, Authority _authority)
        ERC721("craft.game settlement", "SETTLEMENT")
        Auth(msg.sender, _authority)
    {
        dungeonMaster = _dungeonMaster;
        renderer = _renderer;
    }

    modifier hasNotSettled(address to) {
        if (_balanceOf[to] > 0) {
            revert HasSettled();
        }

        _;
    }

    modifier hasSignature(address to, bytes calldata sig) {
        (address signingAddress,) = ECDSA.tryRecover(ECDSA.toEthSignedMessageHash(getHashForSettler(to)), sig);
        if (signingAddress != dungeonMaster) {
            revert InvalidSignature();
        }

        _;
    }

    function generateTerrains(address settler, uint8 settlementIdx) public pure returns (uint16[240] memory) {
        bytes memory seed = getSeedForSettler(settler);

        // Map of possible terrains. Derived from seed, may be biased - certain
        // terrain types may be weighted more heavily and others not at all.
        uint8[16] memory sourceTerrains;
        for (uint8 i = 0; i < 16;) {
            sourceTerrains[i] = uint8(seed[i]) % (settleableTerrainMaxIndex + 1);

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
            if (idx >= (gridCols + 1) && (idx % gridCols) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (gridCols + 1)])];
            }

            // Top
            if (idx >= gridCols) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - gridCols])];
            }

            // Top Right
            if (idx >= (gridCols - 1) && (idx % gridCols) != gridCols - 1) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - (gridCols - 1)])];
            }

            // Left
            if (idx >= 1 && (idx % gridCols) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx - 1])];
            }

            // Right
            if (idx + 1 <= (terrainIndexes.length - 1) && (idx % gridCols) != gridCols - 1) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + 1])];
            }

            // Bottom Left
            if (idx + (gridCols - 1) <= (terrainIndexes.length - 1) && (idx % gridCols) != 0) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + (gridCols - 1)])];
            }

            // Bottom
            if (idx + gridCols <= (terrainIndexes.length - 1)) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + gridCols])];
            }

            // Bottom Right
            if (idx + gridCols + 1 <= (terrainIndexes.length - 1) && (idx % gridCols) != (gridCols - 1)) {
                ++neighborTerrainCounts[uint8(terrainIndexes[idx + gridCols + 1])];
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

        // The settlement terrain is index 8
        terrainIndexes[settlementIdx] = 8;

        return terrainIndexes;
    }

    function settle(bytes calldata sig, uint8 settlementIdx)
        external
        hasNotSettled(msg.sender)
        hasSignature(msg.sender, sig)
    {
        if (settlementIdx >= 240) {
            revert SettlementOutOfBounds();
        }

        uint256 tokenId = nextTokenId();
        uint16[240] memory terrains = generateTerrains(msg.sender, settlementIdx);
        metadataByTokenId[tokenId] = Metadata({terrains: terrains, settler: msg.sender, settlementIdx: settlementIdx});
        _safeMint(msg.sender, tokenId);
    }

    function setRenderer(address _renderer) external requiresAuth {
        renderer = ICraftSettlementRenderer(_renderer);
    }

    function setDungeonMaster(address _dungeonMaster) external requiresAuth {
        dungeonMaster = _dungeonMaster;
    }

    function setMetadataTerrain(uint256 tokenId, uint8 terrainIndex, uint16 newTerrain) external requiresAuth {
        require(terrainIndex < 240, "terrainIndexesIdx is out of bounds.");
        require(newTerrain < renderer.getTerrainsLength(), "newTerrainIndex is out of bounds");

        metadataByTokenId[tokenId].terrains[terrainIndex] = newTerrain;
        emit SetMetadataTerrain(tokenId, terrainIndex, newTerrain);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return renderer.tokenURI(tokenId);
    }

    function getMetadataByTokenId(uint256 tokenId) external view returns (Metadata memory) {
        return metadataByTokenId[tokenId];
    }

    // Derive 128 bit seed from owner address, only 120 bits will be used for
    // terrain generation
    function getSeedForSettler(address settler) public pure returns (bytes memory) {
        bytes32[4] memory hashes;
        for (uint8 i; i < 4;) {
            if (i == 0) {
                hashes[i] = keccak256(abi.encodePacked(settler));
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

    function getHashForSettler(address settler) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(settler));
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
