// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

contract Marketplace is Ownable, ReentrancyGuard{
    using Math for uint256;

    uint constant _FEE_DENUMENATOR_BPS = 10_000;
    uint _feeBPS = 200;
    address _feeReceiver; 

    struct TokenPrice {
        IERC20 payableToken; //bytes20
        bool isListed;       //bytes1
        bool isOffered;      //bytes1
        uint256 price;
    }
    struct Offer {
        uint endTime;
        uint amount;
    }
    mapping(address NFT => mapping(uint tokenId => TokenPrice)) private _nftInfoMap;
    mapping(address NFT => mapping(uint tokenId => mapping(address from => Offer))) _offers;

    event ItemListed(address indexed addressNFT, uint indexed tokenId, uint cost);
    event ItemUpdated(address indexed addressNFT, uint indexed tokenId, address addressERC20, uint cost); 
    event ItemSold(address indexed addressNFT, uint indexed tokenId, uint cost); 

    event OfferCreated(address indexed addressNFT, uint indexed tokenId, address indexed from, uint endTime, uint amount); 
    event OfferCanceled(address indexed addressNFT, uint indexed tokenId);

    event UpdatePlatformFee(uint indexed fee); 
    event UpdatePlatformFeeRecipient(address indexed recipient);

    constructor(address feeReceiver) Ownable(msg.sender) {
        _feeReceiver = feeReceiver;
    }

    modifier supportIERC721(address addressNFT) {
        require(IERC165(addressNFT).supportsInterface(type(IERC721).interfaceId), "not support ERC165");
        _;
    }

    modifier notListed(address addressNFT, uint tokenId) {
        require(!_nftInfoMap[addressNFT][tokenId].isListed, "token is listed");
        _;
    }
    
    modifier isListed(address addressNFT, uint tokenId) {
        require(_nftInfoMap[addressNFT][tokenId].isListed, "token not listed or not dound");
        _;
    }

    modifier notOffered(address addressNFT, uint tokenId) {
        require(!_nftInfoMap[addressNFT][tokenId].isOffered, "token is offered");
        _;
    }

    modifier isOffered(address addressNFT, uint tokenId) {
        require(_nftInfoMap[addressNFT][tokenId].isOffered, "token not offered");
        _;
    }

    modifier haveRules(address addressNFT, uint tokenId) {
        IERC721 nft = IERC721(addressNFT);
        address tokenOwner = nft.ownerOf(tokenId);
        require(tokenOwner == msg.sender || nft.isApprovedForAll(tokenOwner, msg.sender) || nft.getApproved(tokenId) == msg.sender, "must use approval or operator, or be owner");
        _;
    }

    function add(address addressNFT, uint tokenId, address addressToken, uint price) external supportIERC721(addressNFT) {
        _add(addressNFT, tokenId, addressToken, price);
    }

    function _add(address addressNFT, uint tokenId, address addressToken, uint price) internal notListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) {
        require(addressToken != address(0), "zero address");
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];

        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
        tokenInfo.isListed = true;
        tokenInfo.isOffered = true;

        emit ItemListed(addressNFT, tokenId, price);
    }

    function change(address addressNFT, uint tokenId, address addressToken, uint price) external  {
        _change(addressNFT, tokenId, addressToken, price);
    }

    function _change(address addressNFT, uint tokenId, address addressToken, uint price) internal isListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) {
        require(addressToken != address(0), "zero address");

        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
        
        emit ItemUpdated(addressNFT, tokenId, addressToken, price); 
    }
    
    function cancel(address addressNFT, uint tokenId) external isListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isListed = false;
    }

    function buy(address addressNFT, uint tokenId) external {
        _send(addressNFT, tokenId, 0, address(0));
    }

    function offOffers(address addressNFT, uint tokenId) external haveRules(addressNFT, tokenId) isOffered(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isOffered = false;
    }

    function onOffers(address addressNFT, uint tokenId) external haveRules(addressNFT, tokenId) notOffered(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isOffered = true;
    }

    function setOffer(address addressNFT, uint tokenId, uint offer, uint endTime) external isListed(addressNFT, tokenId) isOffered(addressNFT, tokenId) {
        require(block.timestamp < endTime, "incorrect end time");
        _offers[addressNFT][tokenId][msg.sender] = Offer(endTime, offer);
        
        emit OfferCreated(addressNFT, tokenId, msg.sender, endTime, offer); 
    }

    function closeOffer(address addressNFT, uint tokenId, address from) external {
        uint endTime = _offers[addressNFT][tokenId][from].endTime;

        if (endTime < block.timestamp || from == msg.sender) {
            delete _offers[addressNFT][tokenId][from];
        } else {
            revert("permission denied");
        }
        
        emit OfferCanceled(addressNFT, tokenId);
    }

    function receiveOffer(address addressNFT, uint tokenId, address from) external haveRules(addressNFT, tokenId) {
        Offer storage offer = _offers[addressNFT][tokenId][from];

        require(offer.endTime >= block.timestamp, "offer is closed");

        _send(addressNFT, tokenId, offer.amount, from);

        delete _offers[addressNFT][tokenId][from];
        
        emit OfferCanceled(addressNFT, tokenId);
    }

    function _send(address addressNFT, uint tokenId, uint price, address to) internal isListed(addressNFT, tokenId) nonReentrant {
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        if (price == 0)
            price = tokenInfo.price;
        if (to == address(0))
            to = msg.sender;
        uint fee = calculatePersent(price);

        require(tokenInfo.payableToken.allowance(to, address(this)) >= price + fee, "must be approve price + fee");
        address tokenOwner = IERC721(addressNFT).ownerOf(tokenId);
        
        tokenInfo.isListed = false;
        tokenInfo.isOffered = false;
        
        tokenInfo.payableToken.transferFrom(to, _feeReceiver, fee);
        tokenInfo.payableToken.transferFrom(to, tokenOwner, price - fee);
        
        IERC721(addressNFT).safeTransferFrom(tokenOwner, to, tokenId);

        emit ItemSold(addressNFT, tokenId, price); 
    }

    function getOffers(address addressNFT, uint tokenId, address from) external view returns(Offer memory) {
        return _offers[addressNFT][tokenId][from];
    }

    function setFeePersent(uint feeBPS) external onlyOwner{
        require(feeBPS >= 1, "min % is 0,01");
        _feeBPS = feeBPS;
        
        emit UpdatePlatformFee(feeBPS); 
    }

    function calculatePersent(uint price) public view returns(uint fee) {
        fee = price.mulDiv(_feeBPS, _FEE_DENUMENATOR_BPS);
    }

    function getFeeBPS() external view returns(uint) { 
        return _feeBPS;
    }

    function setFeeReceiver(address feeReceiver) external onlyOwner{ 
        require(feeReceiver != address(0), "zero address");
        _feeReceiver = feeReceiver;
        
        emit UpdatePlatformFeeRecipient(feeReceiver);
    }

    function getReceiver() external view returns(address) {
        return _feeReceiver;
    }

    function getByAddressAndId (
        address addressNFT, uint tokenId
    ) external view isListed(addressNFT, tokenId) returns(IERC20 payableToken, uint256 price) {
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        return (tokenInfo.payableToken, tokenInfo.price);
    }
}
