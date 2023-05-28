pragma solidity ^0.8.13;

library CraftSettlementData {
    uint8 internal constant GRID_ROWS = 12;
    uint8 internal constant GRID_COLS = 20;

    struct Metadata {
        uint16[240] terrainIndexes;
        address settler;
    }

    struct Terrain {
        string name;
        string[] renderedCharacters;
        string styles;
    }

    // Derive 128 bit seed from owner address, only 120 bits will be used for terrain generation
    function getSeedForSettler(address settler) internal pure returns (bytes memory) {
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
}
