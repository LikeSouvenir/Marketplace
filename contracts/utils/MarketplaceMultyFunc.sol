// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Marketplace.sol";
// import "../ERC721/BaseNFT.sol";
// import "../ERC20/SimpleERC20.sol";
// import "@openzeppelin/contracts/interfaces/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// import "@openzeppelin/contracts/utils/math/Math.sol";

contract MarketplaceMultyFunc is Marketplace{
    constructor(address feeReceiver) Marketplace(feeReceiver) {}

    function multipleAdd(address addressNFT, uint[] calldata tokenIds, address[] calldata addressesToken, uint[] calldata prices) external {
        require(IERC721(addressNFT).isApprovedForAll(msg.sender, address(this)), "must set operator");
        
        for (uint i = 0; i < tokenIds.length; i++) {
            add(addressNFT, tokenIds[i], addressesToken[i], prices[i]);
        }
    }

    function multipleChange(address addressNFT, uint[] calldata tokenIds, address[] calldata addressesToken, uint[] calldata prices) external  {
        for (uint i = 0; i < tokenIds.length; i++) {
            _change(addressNFT, tokenIds[i], addressesToken[i], prices[i]);
        }
    }

    function multiBuy(address addressNFT, uint[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            _send(addressNFT, tokenIds[i], 0, address(0));
        }
    }
    
    function multipleCancel(address[] calldata addressNFTs, uint[] calldata tokenIds) external {
        // for (uint i = 0; i < tokenIds.length; i++) {
        //     cancel(addressNFTs[i], tokenIds[i]);
        // }
    }
    
    function multipleOffOffers(address addressNFT, uint tokenId)  external {}
    
    function multipleOnOffers(address addressNFT, uint tokenId) external {}
    
    function multipleSetOffer(address addressNFT, uint tokenId, uint offer, uint endTime) external {}
    
    function multipleCloseOffer(address addressNFT, uint tokenId, uint offerIdx) external {}
    
    function multipleReceiveOffer(address addressNFT, uint tokenId, uint offerIdx) external {}


}
