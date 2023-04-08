// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract CraftSettlement is ERC721, Owned {
    using Counters for Counters.Counter;
    using Strings for uint256;

    address public mintArbiter;

    Counters.Counter internal tokenIdCounter;

    error InvalidSignature();
    error HasSettled();
    error Soulbound();

    constructor(address _mintArbiter) Owned(msg.sender) ERC721("craft.game settlement", "CRAFT_SETTLEMENT") {
        mintArbiter = _mintArbiter;
    }

    function setMintArbiter(address _mintArbiter) external onlyOwner {
        mintArbiter = _mintArbiter;
    }

    modifier hasSignature(address to, bytes memory sig) {
        (address signingAddress,) = ECDSA.tryRecover(ECDSA.toEthSignedMessageHash(settleHash(to)), sig);

        if (signingAddress != mintArbiter) {
            revert InvalidSignature();
        }

        _;
    }

    modifier hasNotSettled(address to) {
        if (_balanceOf[to] > 0) {
            revert HasSettled();
        }

        _;
    }

    function settleHash(address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(to));
    }

    function nextTokenId() private returns (uint256) {
        tokenIdCounter.increment();
        return tokenIdCounter.current();
    }

    function settle(bytes memory sig)
        external
        hasNotSettled(msg.sender)
        hasSignature(msg.sender, sig)
    {
        uint256 tokenId = nextTokenId();
        _safeMint(msg.sender, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        bytes memory dataURI = abi.encodePacked("{", '"tokenId": "', tokenId.toString(), '"', "}");

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

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
