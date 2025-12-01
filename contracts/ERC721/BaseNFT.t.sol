// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./BaseNFT.sol";
import {Test} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";
 
contract EmptyContract {}

contract BaseNFTTest is Test {
    using stdStorage for StdStorage;
    
    BaseNFT erc721Contract;

    address owner = vm.addr(1);
    address kate = vm.addr(2);
    address mix = vm.addr(3);
    
    string name = "erc721";
    string symbol = "E721";
    uint[] allTokenIds;
    
    function setUp() public {
        erc721Contract = new BaseNFT(name, symbol);
        uint toeknId0 = erc721Contract.safeMint(owner, "QmXzZ7ZVwDRJ5acZzYbEdYbhZdgpFTcvCafXdis23XjB4W"); // tokenId = 0
        uint toeknId1 = erc721Contract.safeMint(owner, "QmX553Mn6xpx1H8brBNPV6qcR2UBcFrC8LUYsVmctWk8xZ"); // tokenId = 1
        uint toeknId2 = erc721Contract.safeMint(kate, "QmSiK3Pg4tfYGKdHb4VjAm3NUDxTrtoCFfjRTLvfu8k5wn");  // tokenId = 2
        allTokenIds.push(toeknId0);
        allTokenIds.push(toeknId1);
        allTokenIds.push(toeknId2);
    }
    function test_supportsInterface() public view{
        bool res = erc721Contract.supportsInterface(type(IERC721).interfaceId);
        vm.assertEq(res, true);
    }

    function test_balanceOf() public{
        uint newBalace = 2;
        address testUser = vm.addr(12);
        bytes32 key = keccak256(abi.encode(testUser, uint256(3)));
        bytes32 value = bytes32(uint256(2));
        vm.store(address(erc721Contract), key, value);

        uint balance = erc721Contract.balanceOf(testUser);
        vm.assertEq(balance, newBalace);
    }

    function test_ownerOf() external view{
        address checkOwner = erc721Contract.ownerOf(allTokenIds[0]);
        vm.assertEq(owner, checkOwner);
    }

    function test_name() public view{
        string memory checkName = erc721Contract.name();
        vm.assertEq(checkName, name);
    }

    function test_symbol() public view{
        string memory checkSymbol = erc721Contract.symbol();
        vm.assertEq(checkSymbol, symbol);
    }

    function test_tokenURI() public{
        string memory defaultURI = "ipfs://";
        string memory defaultIPFSHash = "QmSiK3Pg4tfYGKdHb4VjAm3NUDxTrtoCFfjRTLvfu8k5wn";

        uint newTokenId = erc721Contract.safeMint(mix, defaultIPFSHash);
        string memory newURI = erc721Contract.tokenURI(newTokenId);
        
        vm.assertEq(newURI, string.concat(defaultURI, defaultIPFSHash));
    }
    
    function test_approve() public{
        uint currentId = allTokenIds[1];
        vm.prank(owner);
        erc721Contract.approve(mix, currentId);

        bytes32 key = keccak256(abi.encode(currentId, uint256(4)));
        bytes32 value = vm.load(address(erc721Contract), key);

        vm.assertEq(address(uint160(uint256(value))), mix);
    }

    function test_getApproved() public{
        uint currentId = allTokenIds[1];
        vm.prank(owner);
        erc721Contract.approve(mix, currentId);

        address spender = erc721Contract.getApproved(currentId);
        
        vm.assertEq(mix, spender);
    }

    function test_setApprovalForAll() public{
        vm.prank(owner);
        erc721Contract.setApprovalForAll(mix, true);

        bytes32 key = keccak256(abi.encode(owner, 5));
        bytes32 keytoKey = keccak256(abi.encode(mix, key));

        bytes32 value = vm.load(address(erc721Contract), keytoKey);
        bool isApprovalForAll = (value != bytes32(0));

        vm.assertEq(isApprovalForAll, true);
    }

    function test_isApprovedForAll() public{
        vm.prank(owner);
        erc721Contract.setApprovalForAll(mix, true);

        bool isApprovalForAll = erc721Contract.isApprovedForAll(owner, mix);
        
        vm.assertEq(isApprovalForAll, true);
    }
    // transferFrom(address from, address to, uint256 tokenId) public 
    function test_Owner_safeTransferFrom() public{
        uint currentId = allTokenIds[1];
        vm.prank(owner);
        erc721Contract.safeTransferFrom(owner, mix, currentId);

        address checkOwner = erc721Contract.ownerOf(currentId);
        vm.assertEq(mix, checkOwner);
    }

    function test_Spender_safeTransferFrom() public{
        uint currentId = allTokenIds[1];
        vm.prank(owner);
        erc721Contract.setApprovalForAll(kate, true);
        vm.prank(kate);
        erc721Contract.safeTransferFrom(owner, mix, currentId);

        address checkOwner = erc721Contract.ownerOf(currentId);
        vm.assertEq(mix, checkOwner);
    }

    function test_UnSupportERC165_safeTransferFrom() public{
        address emptyContract = address(new EmptyContract());
        uint currentId = allTokenIds[1];
        vm.prank(owner);
        erc721Contract.setApprovalForAll(kate, true);
        vm.prank(kate);
        vm.expectRevert();
        erc721Contract.safeTransferFrom(owner, emptyContract, currentId);
    }
}