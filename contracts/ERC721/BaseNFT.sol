// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC-721 URIStorage with auto increment IDs
/// @author GitHub.com/LikeSouvenir
/// @notice A simple NFT contract with URIStorage and auto increment IDs
contract BaseNFT is ERC721URIStorage, Ownable {
    // auto increment IDs
    uint nextId;

    ///@dev Initializes the contract by msg.sender the contract owner, setting a `name` and a `symbol` to the token collection.
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    /// @notice Create new NFT token by setting a `to` and a `tokenURI` to the token. can call only contract owner
    /// @dev Returns token ID 
    /// @param to New token owner
    /// @param tokenURI CID from IPFS by default
    function safeMint(address to, string memory tokenURI) external onlyOwner returns(uint){
        _safeMint(to, nextId);
        _setTokenURI(nextId, tokenURI);
        return nextId++;
    }

    /// @dev Returns IPFS:// by default
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }
}