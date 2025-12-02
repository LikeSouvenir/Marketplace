// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC20/SimpleERC20.sol";
import "./ERC721/BaseNFT.sol";
import "./Marketplace.sol";
import {Test} from "forge-std/Test.sol"; 
import {stdStorage, StdStorage} from "forge-std/Test.sol"; 
import {stdError} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";

contract MarketPlaceTest is Test {
    struct TokenPrice {
        IERC20 payableToken; //bytes20
        bool isListed;       //bytes1
        uint256 price;
    }

    using stdStorage for StdStorage;
    address owner = vm.addr(1);
    address kate = vm.addr(2);
    address mix = vm.addr(3);
    address receiver = vm.addr(4);

    Marketplace marketContract;
    SimpleERC20 erc20Contract;
    BaseNFT erc721Contract;

    // multipleAdd
    uint[] tokensIds;
    address[] addressesToken;
    uint[] prices;
    function setUp() external {
        marketContract = new Marketplace(receiver);
        erc20Contract = new SimpleERC20("erc20", "E20");
        erc721Contract = new BaseNFT("erc721", "E721");

        erc721Contract.safeMint(owner, "QmXzZ7ZVwDRJ5acZzYbEdYbhZdgpFTcvCafXdis23XjB4W"); // tokenId = 0
        erc721Contract.safeMint(owner, "QmX553Mn6xpx1H8brBNPV6qcR2UBcFrC8LUYsVmctWk8xZ"); // tokenId = 1
        // erc721Contract.safeMint(kate, "QmSiK3Pg4tfYGKdHb4VjAm3NUDxTrtoCFfjRTLvfu8k5wn");  // tokenId = 2

        // multiple
        tokensIds = [0,1];
        addressesToken = [address(erc20Contract), address(erc20Contract)];
        prices = [99_000, 192_000];
    }
    // add
    function test_BadTokenAddress_add() public {
        vm.expectRevert();
        marketContract.add(address(erc20Contract), 1, address(erc20Contract), 100);
    }

    function test_NotHaveApproval_add() public {
        vm.expectRevert(bytes("must set approval or operator"));
        vm.prank(owner);
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
    }

    function test_GoodTokenAddress_add() public {
        vm.startPrank(owner);
        erc721Contract.setApprovalForAll(address(marketContract), true);
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);

        bytes32 key = keccak256(abi.encode(address(erc721Contract), 3));
        bytes32 keyToKey = keccak256(abi.encode(tokensIds[0], key));

        bytes32 slot1 = vm.load(address(marketContract), keyToKey);
        bytes32 slot2 = vm.load(address(marketContract), bytes32(uint256(keyToKey) + 1));

        address payableTokenFromSlot = address(uint160(uint256(slot1)));
        uint priceFromSlot = uint(slot2);

        vm.assertEq(priceFromSlot, prices[0]);
        vm.assertEq(payableTokenFromSlot, address(erc20Contract));

        (IERC20 payableToken,uint256 price) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
        vm.assertEq(price, prices[0]);
        vm.assertEq(address(payableToken), address(erc20Contract));
    }

    function test_BadTokenId_add() public {
        uint notExistsTokenId = 100;
        erc721Contract.setApprovalForAll(address(marketContract), true);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, notExistsTokenId));
        marketContract.add(address(erc721Contract), notExistsTokenId, addressesToken[0], prices[0]);
    }

    function test_GoodTokenId_add() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        (IERC20 payableToken,uint256 price) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
        vm.assertEq(price, prices[0]);
        vm.assertEq(address(payableToken), addressesToken[0]);
    }

    function test_NonOwnedTokenId_add() public {
        vm.startPrank(mix);
        erc721Contract.setApprovalForAll(address(marketContract), true);
        vm.expectRevert(bytes("permission denied"));
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
    }
    // change
    function test_Correct_change() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        (IERC20 payableTokenBefore,uint256 priceBefore) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
        
        address newErc20 = address(new SimpleERC20("new20", "N20"));
        vm.prank(owner);
        marketContract.change(address(erc721Contract), tokensIds[0], newErc20, prices[1]);

        (IERC20 payableTokenAfter,uint256 priceAfter) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);

        vm.assertNotEq(address(payableTokenBefore), address(payableTokenAfter));
        vm.assertNotEq(priceBefore, priceAfter);
    }

    function test_NotOwnedToken_change() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.startPrank(kate);
        address newErc20 = address(new SimpleERC20("new20", "N20"));
        uint newPrice = 100;

        vm.expectRevert(bytes("permission denied"));
        marketContract.change(address(erc721Contract), tokensIds[0], newErc20, newPrice);
    }

    function test_NotExistsToken_change() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        uint notExistsTokenId = 100;

        vm.expectRevert(bytes("token not listed or not dound"));
        marketContract.change(address(erc721Contract), notExistsTokenId, addressesToken[0], prices[0]);
    }

    function test_NotListedToken_change() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(owner);
        marketContract.cancel(address(erc721Contract), tokensIds[0]);

        vm.expectRevert(bytes("token not listed or not dound"));
        marketContract.change(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
    }
    // cancel
    function test_Correct_cancel() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(owner);
        marketContract.cancel(address(erc721Contract), tokensIds[0]);

        vm.expectRevert(bytes("token not listed or not dound"));
        marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
    }

    function test_NotExistsToken_cancel() public {
        vm.expectRevert(bytes("token not listed or not dound"));
        marketContract.cancel(address(erc721Contract), tokensIds[0]);
    }

    function test_NotListedToken_cancel() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(owner);
        marketContract.cancel(address(erc721Contract), tokensIds[0]);

        vm.expectRevert(bytes("token not listed or not dound"));
        marketContract.cancel(address(erc721Contract), tokensIds[0]);
    }
    // buy
    function test_correct_buy() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(address(marketContract));
        erc20Contract.mint(mix, 100 * 10 ** erc20Contract.decimals());
        uint balanceBefore = erc20Contract.balanceOf(mix);

        (,uint tokenPrice) = marketContract.getByAddressAndId(address(erc721Contract), tokensIds[0]);
        uint fee = marketContract.calculatePersent(tokenPrice);

        vm.startPrank(mix);
        erc20Contract.approve(address(marketContract), tokenPrice + fee);

        marketContract.buy(address(erc721Contract), tokensIds[0]);

        vm.assertEq(erc20Contract.balanceOf(mix), balanceBefore - tokenPrice);
        vm.assertEq(erc721Contract.ownerOf(tokensIds[0]), mix);
    }
    // setOffer
    function test_correct_offer() public {
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(address(marketContract));
        erc20Contract.mint(mix, 100 * 10 ** erc20Contract.decimals());
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        bytes32 key = keccak256(abi.encode(address(erc721Contract), 6));
        bytes32 keytoKey = keccak256(abi.encode(tokensIds[0], key));

        bytes32 arrayStart = keccak256(abi.encode(keytoKey));

        address from = address(uint160(uint256((vm.load(address(marketContract), arrayStart)))));
        uint amount = uint256(vm.load(address(marketContract), bytes32(uint256(arrayStart) + 1)));
        uint endOfferTime = uint256(vm.load(address(marketContract), bytes32(uint256(arrayStart) + 2)));

        vm.assertEq(from, mix);
        vm.assertEq(endOfferTime, endTime);
        vm.assertEq(amount, offer);
    }    

    function test_Correct_receiveOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();

        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        deal(address(erc20Contract), mix, 100 * 10 ** erc20Contract.decimals());
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        uint currentOfferId = marketContract.getOffers(address(erc721Contract), tokensIds[0]).length - 1;
        uint offerWithFee = marketContract.calculatePersent(offer) + offer;

        vm.prank(mix);
        erc20Contract.approve(address(marketContract), offerWithFee);

        vm.startPrank(owner);
        marketContract.receiveOffer(address(erc721Contract), tokensIds[0], currentOfferId);
        
        address tokenOwner = erc721Contract.ownerOf(tokensIds[0]);
        vm.assertEq(mix, tokenOwner);
    }
    // closeOffer
    function test_Owner_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        uint currentOfferId = marketContract.getOffers(address(erc721Contract), tokensIds[0]).length;

        vm.startPrank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        Marketplace.Offer memory offersBeforeClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0])[0];

        marketContract.closeOffer(address(erc721Contract), tokensIds[0], currentOfferId);

        Marketplace.Offer memory offersAfterClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0])[0];

        vm.assertNotEq(offersAfterClosed.from, offersBeforeClosed.from);
    }
    
    function test_NotOwner_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        uint currentOfferId = marketContract.getOffers(address(erc721Contract), tokensIds[0]).length - 1;

        vm.expectRevert(bytes("permission denied"));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], currentOfferId);
    }

    function test_NotOwnerTimeExpired_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        uint currentOfferId = marketContract.getOffers(address(erc721Contract), tokensIds[0]).length - 1;
        Marketplace.Offer memory offersBeforeClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0])[currentOfferId];

        vm.warp(17646703560);
        vm.prank(vm.addr(100000));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], currentOfferId);

        Marketplace.Offer memory offersAfterClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0])[currentOfferId];

        vm.assertNotEq(offersBeforeClosed.from, offersAfterClosed.from);
    }
    
    function test_NotOwnerTimeNotExpired_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        uint currentOfferId = marketContract.getOffers(address(erc721Contract), tokensIds[0]).length - 1;

        vm.expectRevert(bytes("permission denied"));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], currentOfferId);
    }
    // setFeePersent
    function test_Zero_setFeePersent() external {
        vm.expectRevert(bytes("min % is 0,01"));
        marketContract.setFeePersent(0);
    }

    function test_Correct_setFeePersent() external {
        uint fiveteenPersent = 5000;
        marketContract.setFeePersent(fiveteenPersent);

        uint newFeeBps = marketContract.getFeeBPS();
        vm.assertEq(newFeeBps, fiveteenPersent); // 50%
    }
    // setFeeReceiver
    function test_NotOwner_setFeeReceiver() external {
        vm.prank(mix);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, mix));
        marketContract.setFeeReceiver(mix);
    }

    function test_Correct_setFeeReceiver() external {
        marketContract.setFeeReceiver(mix);

        address currentReciever = marketContract.getReceiver();
        vm.assertEq(currentReciever, mix);
    }
    // getFeeBPS
    function test_NotOwner_getFeeBPS() external view {
        uint defaultFeeBps = marketContract.getFeeBPS();
        vm.assertEq(defaultFeeBps, 200); // 2%
    }
    // getReceiver 
    function test_getReceiver() external view {
        address currentReciever = marketContract.getReceiver();
        vm.assertEq(currentReciever, receiver);
    }
    // getAll
    function test_getAll() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        address[] memory allNfths = marketContract.getAll();
        vm.assertEq(allNfths[0], address(erc721Contract));
    }
    // getTokensId
    function test_getTokensId() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint[] memory allTokensIds = marketContract.getTokensId(address(erc721Contract));
        vm.assertEq(allTokensIds[0], tokensIds[0]);
        vm.assertEq(allTokensIds[1], tokensIds[1]);
    }
    // calculatePersent
    function test_Correct_calculatePersent() external view {
        uint correctPrice = 100;
        uint fee = marketContract.calculatePersent(correctPrice);
        vm.assertEq(fee, 2);
    }
    // support functions
    function _setOwnerApprovalAndAddTwoDefaultNft() internal {
        vm.startPrank(owner);
        erc721Contract.setApprovalForAll(address(marketContract), true);
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
        marketContract.add(address(erc721Contract), tokensIds[1], addressesToken[1], prices[1]);
        vm.stopPrank();
    }
}