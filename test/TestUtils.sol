// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../src/CraftSettlementRenderer.sol";

contract ERC721TokenReceiverMock is ERC721TokenReceiver {
    uint256 public lastTokenId;

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        lastTokenId = tokenId;
        return this.onERC721Received.selector;
    }
}

contract CraftSettlementRendererMock {
    using Strings for uint256;

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        bytes memory dataURI = abi.encodePacked("{", '"tokenId": "', tokenId.toString(), '"', "}");

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }
}

library Utils {
    function logTerrain(CraftSettlementRenderer.Terrain[576] memory terrain, uint8 rowSize) public {
        string memory output = "";
        for (uint256 i = 0; i < terrain.length / rowSize; i++) {
            for (uint256 j = 0; j < rowSize; j++) {
                output = string(abi.encodePacked(output, Strings.toString(uint256(terrain[(i * rowSize) + j]))));
            }
            output = string(abi.encodePacked(output, "\n"));
        }

        console.log(output);
        require(false, "logTerrain");
    }

    function makeSignature(Vm vm, uint248 pkey, bytes32 digest) public returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey, ECDSA.toEthSignedMessageHash(digest));

        return abi.encodePacked(r, s, v);
    }
}
