// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../ERC20/SimpleERC20.sol";
import "../ERC721/BaseNFT.sol";
import "./MarketplaceMultyFunc.sol";
import {Test} from "forge-std/Test.sol"; 
import {stdStorage, StdStorage} from "forge-std/Test.sol"; 
import {stdError} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";

contract MarketplaceMultyFuncTest is Test {

    // // multipleAdd
    // function test_BadTokenAddress_multipleAdd() public {
    //     vm.expectRevert();
    //     marketContract.multipleAdd(address(erc20Contract), tokensIds, addressesToken, prices);
    // }

    // function test_NotHaveApproval_multipleAdd() public {
    //     vm.prank(owner);
    //     vm.expectRevert(bytes("must set operator"));
    //     marketContract.multipleAdd(address(erc721Contract), tokensIds, addressesToken, prices);
    // }

    // function test_GoodTokenAddress_multipleAdd() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     bytes32 key = keccak256(abi.encode(address(erc721Contract), 3));
    //     bytes32 keyToKey = keccak256(abi.encode(tokensIds[0], key));

    //     bytes32 slot1 = vm.load(address(marketContract), keyToKey);
    //     bytes32 slot2 = vm.load(address(marketContract), bytes32(uint256(keyToKey) + 1));

    //     address payableTokenFromSlot = address(uint160(uint256(slot1)));
    //     uint priceFromSlot = uint(slot2);

    //     vm.assertEq(priceFromSlot, prices[0]);
    //     vm.assertEq(payableTokenFromSlot, address(erc20Contract));

    //     (IERC20 payableToken,,uint256 price) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
    //     vm.assertEq(price, prices[0]);
    //     vm.assertEq(address(payableToken), address(erc20Contract));
    // }

    // function test_BadTokenId_multipleAdd() public {
    //     uint[] memory badTokensIds = new uint[] (2);
    //     badTokensIds[0] = 112;
    //     badTokensIds[1] = 999;

    //     erc721Contract.setApprovalForAll(address(marketContract), true);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, badTokensIds[0]));
    //     marketContract.multipleAdd(address(erc721Contract), badTokensIds, addressesToken, prices);
    // }

    // function test_GoodTokenId_multipleAdd() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     (IERC20 payableToken,,uint256 price) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);

    //     vm.assertEq(price, prices[0]);
    //     vm.assertEq(address(payableToken), address(erc20Contract));
    // }

    // function test_NonOwnedTokenId_multipleAdd() public {
    //     vm.startPrank(mix);
    //     erc721Contract.setApprovalForAll(address(marketContract), true);
    //     vm.expectRevert(bytes("permission denied"));
    //     marketContract.multipleAdd(address(erc721Contract), tokensIds, addressesToken, prices);
    // }

    // multipleChange
    // function test_Correct_multipleChange() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     (IERC20 payableTokenBefore,,) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
        
    //     address newErc20 = address(new SimpleERC20("new20", "N20"));
    //     address[] memory badPayableToken = new address[] (2);
    //     badPayableToken[0] = newErc20;
    //     badPayableToken[1] = newErc20;

    //     vm.prank(owner);
    //     marketContract.multipleChange(address(erc721Contract), tokensIds, badPayableToken, prices);

    //     (IERC20 payableTokenAfter,,) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);

    //     vm.assertNotEq(address(payableTokenBefore), address(payableTokenAfter));
    // }

    // function test_NotOwnedToken_multipleChange() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     vm.startPrank(kate);

    //     vm.expectRevert(bytes("permission denied"));
    //     marketContract.multipleChange(address(erc721Contract), tokensIds, addressesToken, prices);
    // }

    // function test_NotExistsToken_multipleChange() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     uint[] memory notExistsTokenIds = new uint[](2);
    //     notExistsTokenIds[0] = 100;

    //     vm.expectRevert(bytes("token not listed or not dound"));
    //     marketContract.multipleChange(address(erc721Contract), notExistsTokenIds, addressesToken, prices);
    // }

    // function test_NotListedToken_multipleChange() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     vm.startPrank(owner);
    //     marketContract.cancel(address(erc721Contract), tokensIds[0]);

    //     vm.expectRevert(bytes("token not listed or not dound"));
    //     marketContract.multipleChange(address(erc721Contract), tokensIds, addressesToken, prices);
    // }

    //multiBuy
    // function test_correct_multiBuy() public {
    //     _setOwnerApprovalAndAddTwoDefaultNft();

    //     vm.prank(address(marketContract));
    //     erc20Contract.mint(mix, 100 * 10 ** erc20Contract.decimals());
    //     uint tokenPriceAmount;

    //     for (uint i = 0; i < tokensIds.length; i++) {
    //         (,,uint tokenPrice) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[i]);
    //         uint fee = marketContract.calculatePersent(tokenPrice);
    //         tokenPriceAmount += tokenPrice + fee;
    //     }
    //     vm.startPrank(mix);
    //     erc20Contract.approve(address(marketContract), tokenPriceAmount);

    //     marketContract.multiBuy(address(erc721Contract), tokensIds);

    //     vm.assertEq(erc721Contract.ownerOf(tokensIds[0]), mix);
    //     vm.assertEq(erc721Contract.ownerOf(tokensIds[1]), mix);
    // }
}