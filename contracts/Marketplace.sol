// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20/SimpleERC20.sol";
import "./ERC721/BaseNFT.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

contract Marketplace is Ownable{
    using Math for uint256;

    uint constant _FEE_DENUMENATOR_BPS = 10_000;
    uint _feeBPS = 200;
    address _feeReceiver; 

    struct TokenPrice {
        IERC20 payableToken; //bytes20
        bool isListed;       //bytes1
        uint256 price;
    }
    struct Offer {
        address from;
        uint endTime;
        uint amount;
    }
    mapping(address NFT => mapping(uint tokenId => TokenPrice)) private _nftInfoMap;
    mapping(address NFT => uint[]) private _nftAddressToTokenIdMap;
    address[] private _allNFTs;

    mapping(address NFT => mapping(uint tokenId => Offer[])) _offers;

    constructor(address feeReceiver) Ownable(msg.sender) {
        _feeReceiver = feeReceiver;
    }

    modifier supportERC165(address addressNFT) {
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

    function _haveRules(IERC721 addressNFT, uint tokenId) internal view {
        address tokenOwner = addressNFT.ownerOf(tokenId);
        require(tokenOwner == msg.sender || addressNFT.isApprovedForAll(tokenOwner, msg.sender) || addressNFT.getApproved(tokenId) == msg.sender, "permission denied");
    }

    function add(address addressNFT, uint tokenId, address addressToken, uint price) external supportERC165(addressNFT) {
        IERC721 contractNFT = IERC721(addressNFT);

        require(
            contractNFT.isApprovedForAll(msg.sender, address(this)) || 
            contractNFT.getApproved(tokenId) == address(this),
            "must set approval or operator"
        );

        _add(addressNFT, tokenId, addressToken, price);
    }

    function multipleAdd(address addressNFT, uint[] calldata tokenIds, address[] calldata addressesToken, uint[] calldata prices) external supportERC165(addressNFT) {
        require(IERC721(addressNFT).isApprovedForAll(msg.sender, address(this)), "must set operator");
        
        for (uint i = 0; i < tokenIds.length; i++) {
            _add(addressNFT, tokenIds[i], addressesToken[i], prices[i]);
        }
    }

    function _add(address addressNFT, uint tokenId, address addressToken, uint price) internal notListed(addressNFT, tokenId) {
        _haveRules(IERC721(addressNFT), tokenId);

        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];

        if (address(tokenInfo.payableToken) == address(0)) { // токен ранее не выставлялся
            if (_nftAddressToTokenIdMap[addressNFT].length == 0)  // адрес контракта фигурирует в первый раз
                _allNFTs.push(addressNFT);
            _nftAddressToTokenIdMap[addressNFT].push(tokenId);

        }

        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
        tokenInfo.isListed = true;
    }

    function change(address addressNFT, uint tokenId, address addressToken, uint price) external  {
        _change(addressNFT, tokenId, addressToken, price);
    }

    function multipleChange(address addressNFT, uint[] calldata tokenIds, address[] calldata addressesToken, uint[] calldata prices) external  {
        for (uint i = 0; i < tokenIds.length; i++) {
            _change(addressNFT, tokenIds[i], addressesToken[i], prices[i]);
        }
    }

    function _change(address addressNFT, uint tokenId, address addressToken, uint price) internal isListed(addressNFT, tokenId) {
        _haveRules(IERC721(addressNFT), tokenId);

        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        tokenInfo.payableToken = IERC20(addressToken);
        tokenInfo.price = price;
    }
    
    function cancel(address addressNFT, uint tokenId) external isListed(addressNFT, tokenId) {
        _haveRules(IERC721(addressNFT), tokenId);
        _nftInfoMap[addressNFT][tokenId].isListed = false;
    }

    function buy(address addressNFT, uint tokenId) external {
        _send(addressNFT, tokenId, 0, address(0));
    }

    function multiBuy(address addressNFT, uint[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            _send(addressNFT, tokenIds[i], 0, address(0));
        }
    }

    function setOffer(address addressNFT, uint tokenId, uint offer, uint endTime) external isListed(addressNFT, tokenId) {
        require(block.timestamp < endTime, "incorrect end time");
        _offers[addressNFT][tokenId].push(Offer(msg.sender, offer, endTime));
    }

    function receiveOffer(address addressNFT, uint tokenId, uint offerIdx) external{
        _haveRules(IERC721(addressNFT), tokenId);

        Offer storage offer = _offers[addressNFT][tokenId][offerIdx];

        require(offer.endTime >= block.timestamp, "offer is closed");

        _send(addressNFT, tokenId, offer.amount, offer.from);

        delete _offers[addressNFT][tokenId][offerIdx];
    }

    function _send(address addressNFT, uint tokenId, uint price, address to) internal isListed(addressNFT, tokenId) {
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        if (price == 0)
            price = tokenInfo.price;
        if (to == address(0))
            to = msg.sender;
        uint fee = calculatePersent(price);

        require(tokenInfo.payableToken.allowance(to, address(this)) >= price + fee, "must be approve price + fee");
        address tokenOwner = IERC721(addressNFT).ownerOf(tokenId);
        
        tokenInfo.payableToken.transferFrom(to, _feeReceiver, fee);
        tokenInfo.payableToken.transferFrom(to, tokenOwner, price - fee);
        
        IERC721(addressNFT).safeTransferFrom(tokenOwner, to, tokenId);
        
        tokenInfo.isListed = false;
    }

    function getOffers(address addressNFT, uint tokenId) external view returns(Offer[] memory) {
        return _offers[addressNFT][tokenId];
    }

    function setFeePersent(uint feeBPS) external onlyOwner{
        require(feeBPS >= 1, "min % is 0,01");
        require(feeBPS <= _FEE_DENUMENATOR_BPS, "max % is 100");
        _feeBPS = feeBPS;
    }

    function calculatePersent(uint price) public view returns(uint fee) {
        fee = price.mulDiv(_feeBPS, _FEE_DENUMENATOR_BPS);
    }

    function getFeeBPS() external view returns(uint) { 
        return _feeBPS;
    }

    function setFeeReceiver(address feeReceiver) external onlyOwner{ 
        _feeReceiver = feeReceiver;
    }

    function getReceiver() external view returns(address) {
        return _feeReceiver;
    }

    function getAll() external view returns(address[] memory) {
        return _allNFTs;
    }

    function getTokensId(address addressNFT) external view returns(uint[] memory nfts) {
        nfts = _nftAddressToTokenIdMap[addressNFT];
    }

    function getByAddressAndId(
        address addressNFT, uint tokenId
    )external view isListed(addressNFT, tokenId) returns(IERC20 payableToken, bool checkListed, uint256 price) {
        TokenPrice storage tokenInfo = _nftInfoMap[addressNFT][tokenId];
        return (tokenInfo.payableToken, tokenInfo.isListed, tokenInfo.price);
    }
}
