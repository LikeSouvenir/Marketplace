// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BaseNFT is ERC721URIStorage, Ownable {
    uint nextId;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

    function safeMint(address to,string memory _tokenURI) external onlyOwner returns(uint){
        _safeMint(to, nextId);
        _setTokenURI(nextId, _tokenURI);
        return nextId++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }
}