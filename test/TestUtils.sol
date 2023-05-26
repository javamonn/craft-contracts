// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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

library Utils {
    function makeSignature(Vm vm, uint248 pkey, bytes32 digest) public returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkey, ECDSA.toEthSignedMessageHash(digest));

        return abi.encodePacked(r, s, v);
    }
}
