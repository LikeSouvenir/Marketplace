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
        vm.expectRevert(bytes("must set operator or approval"));
        vm.prank(owner);
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
    }

    function test_GoodTokenAddress_add() public {
        _setOwnerApprovalAndAddTwoDefaultNft();

        bytes32 key = keccak256(abi.encode(address(erc721Contract), 4));
        bytes32 keyToKey = keccak256(abi.encode(tokensIds[0], key));

        bytes32 slot1 = vm.load(address(marketContract), keyToKey);
        bytes32 slot2 = vm.load(address(marketContract), bytes32(uint256(keyToKey) + 1));

        address payableTokenFromSlot = address(uint160(uint256(slot1)));
        uint priceFromSlot = uint(slot2);

        vm.assertEq(payableTokenFromSlot, address(erc20Contract));
        vm.assertEq(priceFromSlot, prices[0]);

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
        vm.expectRevert(bytes("must use approval or operator, or be owner"));
        marketContract.add(address(erc721Contract), tokensIds[0], addressesToken[0], prices[0]);
    }
    // change
    function test_correct_change() public {
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

        vm.expectRevert(bytes("must use approval or operator, or be owner"));
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
    function test_correct_cancel() public {
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
    // haveRules(addressNFT, tokenId) isOffered(addressNFT, tokenId)
    function test_correct_offOffers() external {
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(owner);
        marketContract.offOffers(address(erc721Contract), tokensIds[0]);

        vm.prank(mix);
        vm.expectRevert(bytes("token not offered"));
        marketContract.setOffer(address(erc721Contract), tokensIds[0], 100, 100);
    }

    function test_bad_onOffers() external{
        _setOwnerApprovalAndAddTwoDefaultNft();
        vm.prank(owner);
        vm.expectRevert(bytes("token is offered"));
        marketContract.onOffers(address(erc721Contract), tokensIds[0]);
    }

    function test_correct_onOffers() external{
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(owner);
        marketContract.offOffers(address(erc721Contract), tokensIds[0]);

        vm.prank(owner);
        marketContract.onOffers(address(erc721Contract), tokensIds[0]);
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], 100, 100);
    }
    // setOffer
    function test_correct_setOffer() public {
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        _setOwnerApprovalAndAddTwoDefaultNft();

        vm.prank(address(marketContract));
        erc20Contract.mint(mix, 100 * 10 ** erc20Contract.decimals());
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);
        // mapping(address NFT => mapping(uint tokenId => mapping(address from => Offer))) _offers;

        bytes32 keyNFT = keccak256(abi.encode(address(erc721Contract), 5));
        bytes32 keyTokenId = keccak256(abi.encode(tokensIds[0], keyNFT));
        bytes32 keyAddressFrom = keccak256(abi.encode(mix, keyTokenId));

        uint endOfferTime = uint256(vm.load(address(marketContract), keyAddressFrom));
        uint amount = uint256(vm.load(address(marketContract), bytes32(uint256(keyAddressFrom) + 1)));

        vm.assertEq(endOfferTime, endTime);
        vm.assertEq(amount, offer);
    }    

    function test_correct_receiveOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();

        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        deal(address(erc20Contract), mix, 100 * 10 ** erc20Contract.decimals());
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        uint offerWithFee = marketContract.calculatePersent(offer) + offer;

        vm.prank(mix);
        erc20Contract.approve(address(marketContract), offerWithFee);

        vm.startPrank(owner);
        marketContract.receiveOffer(address(erc721Contract), tokensIds[0], mix);
        
        address tokenOwner = erc721Contract.ownerOf(tokensIds[0]);
        vm.assertEq(mix, tokenOwner);
    }
    // closeOffer
    function test_Owner_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        

        vm.startPrank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        marketContract.closeOffer(address(erc721Contract), tokensIds[0], mix);

        Marketplace.Offer memory offersAfterClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0], mix);

        vm.assertEq(offersAfterClosed.endTime, 0);
        vm.assertEq(offersAfterClosed.amount, 0);
    }
    
    function test_NotOwner_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        vm.expectRevert(bytes("permission denied"));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], mix);
    }

    function test_NotOwnerTimeExpired_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        vm.warp(type(uint56).max);
        vm.prank(vm.addr(100000));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], mix);

        Marketplace.Offer memory offersAfterClosed = marketContract.getOffers(address(erc721Contract), tokensIds[0], mix);
        vm.assertEq(offersAfterClosed.endTime, 0);
        vm.assertEq(offersAfterClosed.amount, 0);
    }
    
    function test_NotOwnerTimeNotExpired_closeOffer() external {
        _setOwnerApprovalAndAddTwoDefaultNft();
        uint offer = 100_000;
        uint endTime = block.timestamp + 10;
        
        vm.prank(mix);
        marketContract.setOffer(address(erc721Contract), tokensIds[0], offer, endTime);

        vm.expectRevert(bytes("permission denied"));
        marketContract.closeOffer(address(erc721Contract), tokensIds[0], mix);
    }
    // setFeePersent
    function test_Zero_setFeePersent() external {
        vm.expectRevert(bytes("min % is 0,01"));
        marketContract.setFeePersent(0);
    }

    function test_correct_setFeePersent() external {
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

    function test_correct_setFeeReceiver() external {
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
    // calculatePersent
    function test_correct_calculatePersent() external view {
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