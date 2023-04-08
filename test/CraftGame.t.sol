// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CraftGame.sol";

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "solmate/tokens/ERC721.sol";

contract ResourceMock is ERC721 {
    using Strings for uint256;
    using Strings for uint16;

    uint16 public id;

    constructor(uint16 resourceId_) ERC721("ResourceMock", "MOCK") {
        id = resourceId_;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        bytes memory dataURI =
            abi.encodePacked("{", '"tokenId": "', tokenId.toString(), '"', '"resourceId": "', id.toString(), '"', "}");

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(dataURI)));
    }

    function mint(address to, uint256 tokenId, bytes calldata) external {
        _safeMint(to, tokenId);
    }
}

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

contract CraftGameTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function test_AddResourceAsOwner(uint16 resourceId) public {
        vm.assume(resourceId != 0);

        CraftGame craftGame = new CraftGame();
        ResourceMock resourceMock = new ResourceMock(resourceId);
        craftGame.addResource(address(resourceMock));
    }

    function testFail_AddResourceNotAsOwner(uint16 resourceId) public {
        vm.assume(resourceId != 0);
        vm.prank(address(0));

        CraftGame craftGame = new CraftGame();
        ResourceMock resourceMock = new ResourceMock(resourceId);
        craftGame.addResource(address(resourceMock));
    }

    function test_MintResource(uint16 resourceId) public {
        vm.assume(resourceId != 0);

        CraftGame craftGame = new CraftGame();
        ResourceMock resourceMock = new ResourceMock(resourceId);
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        craftGame.addResource(address(resourceMock));

        vm.expectEmit(true, true, false, false);
        emit Transfer(address(0), address(receiverMock), 0);
        craftGame.mintResource(address(receiverMock), resourceMock.id(), "");

        assertEq(craftGame.balanceOf(address(receiverMock)), 1);
        assertEq(resourceMock.balanceOf(address(receiverMock)), 1);
        assertEq(craftGame.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
        assertEq(resourceMock.ownerOf(receiverMock.lastTokenId()), address(receiverMock));
    }

    function test_TokenURI(uint16 resourceId) public {
        vm.assume(resourceId != 0);

        CraftGame craftGame = new CraftGame();
        ResourceMock resourceMock = new ResourceMock(resourceId);
        ERC721TokenReceiverMock receiverMock = new ERC721TokenReceiverMock();
        craftGame.addResource(address(resourceMock));
        craftGame.mintResource(address(receiverMock), resourceMock.id(), "");

        string memory resourceTokenUri = resourceMock.tokenURI(receiverMock.lastTokenId());
        string memory gameTokenUri = craftGame.tokenURI(receiverMock.lastTokenId());
        assertEq(resourceTokenUri, gameTokenUri);
    }
}
