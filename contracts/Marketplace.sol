// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title NFT Marketplace with ERC20/ERC721 Support
/// @author GitHub.com/LikeSouvenir
/// @notice A decentralized marketplace for buying, selling, and making offers on NFTs.
/// @notice Supports listing NFTs for sale, accepting offers, and collecting platform fees.
/// @notice Uses ReentrancyGuard for security and supports both ERC20 and ERC721 standards.
/// @notice Platform fee is configurable and sent to a specified recipient.
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

    event ItemListed(address indexed addressNFT, uint indexed tokenId, bool isListed);
    event ItemUpdated(address indexed addressNFT, uint indexed tokenId, address addressERC20, uint cost); 
    event ItemSold(address indexed addressNFT, uint indexed tokenId, uint cost); 

    event OfferCreated(address indexed addressNFT, uint indexed tokenId, address indexed from, uint endTime, uint amount); 
    event OfferCanceled(address indexed addressNFT, uint indexed tokenId, address indexed from);

    event UpdatePlatformFee(uint indexed fee); 
    event UpdatePlatformFeeRecipient(address indexed recipient);

    constructor(address feeReceiver) Ownable(msg.sender) {
        _feeReceiver = feeReceiver;
    }

    modifier supportIERC721(address addressNFT) {
        require(IERC165(addressNFT).supportsInterface(type(IERC721).interfaceId), "not support ERC721");
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

    modifier notZeroAddress(address addr) {
        require(addr != address(0), "zero address");
        _;
    }

    modifier haveRules(address addressNFT, uint tokenId) {
        IERC721 nft = IERC721(addressNFT);
        address tokenOwner = nft.ownerOf(tokenId);
        require(tokenOwner == msg.sender || nft.isApprovedForAll(tokenOwner, msg.sender) || nft.getApproved(tokenId) == msg.sender, "must use approval or operator, or be owner");
        _;
    }
    /// @notice Adds a new NFT to the marketplace for sale
    /// @dev Requires approval for the marketplace to transfer the NFT. Emit ItemListed event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT to list
    /// @param addressToken Address of the ERC20 token to accept as payment
    /// @param price Price of the NFT in the specified ERC20 token
    function add(address addressNFT, uint tokenId, address addressToken, uint price) public supportIERC721(addressNFT) notListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) notZeroAddress(addressToken) {
        require(price > 0, "must be > 0");
        require(IERC721(addressNFT).isApprovedForAll(msg.sender, address(this)) || IERC721(addressNFT).getApproved(tokenId) == address(this), "must set operator or approval");
        
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];

        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
        tokenInfo.isListed = true;
        tokenInfo.isOffered = true;

        emit ItemListed(addressNFT, tokenId, true);
    }

    /// @notice Updates the price and payment token for a listed NFT
    /// @dev Only callable by the NFT owner or approved operator. Emit ItemUpdated event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT to update
    /// @param addressToken Address of the new ERC20 token to accept as payment
    /// @param price New price of the NFT
    function change(address addressNFT, uint tokenId, address addressToken, uint price) external  {
        _change(addressNFT, tokenId, addressToken, price);
    }

    function _change(address addressNFT, uint tokenId, address addressToken, uint price) internal isListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) notZeroAddress(addressToken) {
        require(price > 0, "must be > 0");

        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
        
        emit ItemUpdated(addressNFT, tokenId, addressToken, price); 
    }
    
    /// @notice Cancels the listing of an NFT
    /// @dev Only callable by the NFT owner or approved operator. Emit ItemListed event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT to cancel
    function cancel(address addressNFT, uint tokenId) external isListed(addressNFT, tokenId) haveRules(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isListed = false;

        emit ItemListed(addressNFT, tokenId, false);
    }

    /// @notice Buys a listed NFT at its current price
    /// @dev Transfers the NFT to the buyer and pays the seller, minus platform fee. Emit ItemSold event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT to buy
    function buy(address addressNFT, uint tokenId) external {
        _send(addressNFT, tokenId, 0, address(0));
    }

    /// @notice Disables offers for a listed NFT
    /// @dev Only callable by the NFT owner or approved operator
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    function offOffers(address addressNFT, uint tokenId) external haveRules(addressNFT, tokenId) isOffered(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isOffered = false;
    }

    /// @notice Enables offers for a listed NFT
    /// @dev Only callable by the NFT owner or approved operator
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    function onOffers(address addressNFT, uint tokenId) external haveRules(addressNFT, tokenId) notOffered(addressNFT, tokenId) {
        _nftInfoMap[addressNFT][tokenId].isOffered = true;
    }

    /// @notice Places an offer on a listed NFT
    /// @dev Offer is valid until endTime. Emit OfferCreated event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @param offer Amount of the offer in the NFT's payment token
    /// @param endTime Timestamp when the offer expires
    function setOffer(address addressNFT, uint tokenId, uint offer, uint endTime) external isListed(addressNFT, tokenId) isOffered(addressNFT, tokenId) {
        require(block.timestamp < endTime, "incorrect end time");
        require(offer > 0, "offer must be > 0");
        _offers[addressNFT][tokenId][msg.sender] = Offer(endTime, offer);
        
        emit OfferCreated(addressNFT, tokenId, msg.sender, endTime, offer); 
    }

    /// @notice Cancels an existing offer on an NFT
    /// @dev Can be called by the offerer or after the offer expires. Emit OfferCanceled event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @param from Address of the offerer
    function closeOffer(address addressNFT, uint tokenId, address from) external {
        uint endTime = _offers[addressNFT][tokenId][from].endTime;

        if (endTime < block.timestamp || from == msg.sender) {
            delete _offers[addressNFT][tokenId][from];
        } else {
            revert("permission denied");
        }
        
        emit OfferCanceled(addressNFT, tokenId, from);
    }

    /// @notice Accepts an offer on a listed NFT
    /// @dev Transfers the NFT to the offerer and pays the seller, minus platform fee. Emit ItemSold and OfferCanceled event
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @param from Address of the offerer
    function receiveOffer(address addressNFT, uint tokenId, address from) external haveRules(addressNFT, tokenId) {
        Offer storage offer = _offers[addressNFT][tokenId][from];

        require(offer.endTime >= block.timestamp, "offer is closed");

        _send(addressNFT, tokenId, offer.amount, from);

        delete _offers[addressNFT][tokenId][from];
        
        emit OfferCanceled(addressNFT, tokenId, from);
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

    /// @notice Returns the offer details for a specific NFT and offerer
    /// @dev Returns zero values if no offer exists
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @param from Address of the offerer
    /// @return Offer details (endTime, amount)
    function getOffers(address addressNFT, uint tokenId, address from) external view returns(Offer memory) {
        return _offers[addressNFT][tokenId][from];
    }

    /// @notice Sets the platform fee percentage (in basis points)
    /// @dev Only callable by the contract owner. Emit UpdatePlatformFee event
    /// @param feeBPS New fee percentage in basis points (e.g., 200 = 2%)
    function setFeePersent(uint feeBPS) external onlyOwner{
        require(feeBPS >= 1, "min % is 0,01");
        _feeBPS = feeBPS;
        
        emit UpdatePlatformFee(feeBPS); 
    }

    /// @notice Calculates the platform fee for a given price.
    /// @dev Uses the current fee percentage
    /// @param price Price to calculate fee for
    /// @return fee amount
    function calculatePersent(uint price) public view returns(uint fee) {
        fee = price.mulDiv(_feeBPS, _FEE_DENUMENATOR_BPS);
    }

    /// @notice Returns the current platform fee percentage
    /// @dev In basis points (e.g., 200 = 2%)
    /// @return Current fee percentage
    function getFeeBPS() external view returns(uint) { 
        return _feeBPS;
    }

    /// @notice Sets the address to receive platform fees
    /// @dev Only callable by the contract owner. Emit UpdatePlatformFeeRecipient event
    /// @param feeReceiver Address to receive fees
    function setFeeReceiver(address feeReceiver) external  notZeroAddress(feeReceiver) onlyOwner{ 
        _feeReceiver = feeReceiver;
        
        emit UpdatePlatformFeeRecipient(feeReceiver);
    }

    /// @notice Returns the current fee recipient address
    /// @dev Address where platform fees are sent
    /// @return Current fee recipient
    function getReceiver() external view returns(address) {
        return _feeReceiver;
    }

    /// @notice Returns the payment token and price for a listed NFT
    /// @dev Reverts if the NFT is not listed
    /// @param addressNFT Address of the NFT contract
    /// @param tokenId ID of the NFT
    /// @return payableToken Payment token contract
    /// @return price Payment token contract, price
    function getByAddressAndId (
        address addressNFT, uint tokenId
    ) external view isListed(addressNFT, tokenId) returns(IERC20 payableToken, uint256 price) {
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        return (tokenInfo.payableToken, tokenInfo.price);
    }
}
