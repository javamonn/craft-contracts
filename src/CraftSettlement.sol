// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "solmate/auth/Owned.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ICraftSettlementRenderer.sol";

contract CraftSettlement is ERC721, Owned {
    using Counters for Counters.Counter;

    address public mintArbiter;
    address public renderer;

    Counters.Counter internal tokenIdCounter;

    error InvalidSignature();
    error HasSettled();
    error Soulbound();

    constructor(address _mintArbiter, address _renderer)
        Owned(msg.sender)
        ERC721("craft.game settlement", "CRAFT_SETTLEMENT")
    {
        mintArbiter = _mintArbiter;
        renderer = _renderer;
    }

    modifier hasNotSettled(address to) {
        if (_balanceOf[to] > 0) {
            revert HasSettled();
        }

        _;
    }

    modifier hasSignature(address to, bytes calldata sig) {
        (address signingAddress,) = ECDSA.tryRecover(ECDSA.toEthSignedMessageHash(settleHash(to)), sig);
        if (signingAddress != mintArbiter) {
            revert InvalidSignature();
        }

        _;
    }

    function setMintArbiter(address _mintArbiter) external onlyOwner {
        mintArbiter = _mintArbiter;
    }

    function setRenderer(address _renderer) external onlyOwner {
        renderer = _renderer;
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

        _safeMint(msg.sender, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return ICraftSettlementRenderer(renderer).tokenURI(tokenId);
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
