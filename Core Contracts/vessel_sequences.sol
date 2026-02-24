// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";


interface IVesselToken {
    function blockEvents(uint _index) external view returns (uint);
}

interface IRenderer {
    function uri(uint _tokenId) external view returns (string memory);
}

contract THE_VESSEL_sequences is ERC1155, Ownable, ReentrancyGuard {

    IVesselToken public vessel = IVesselToken(0xECb92Cc7112b80A2234936315BbB493fb48d1463);

    struct token {
        string artist;
        address artistAddress;
        uint maxSupply;
        uint price;
        uint minted;
        bool locked;
        uint eventNumStart;
        uint eventNumEnd;
    }

    struct UriDatum {
        bool    usesRenderer;
        string  uri;
        address renderer;
    }

    mapping (uint => token) public       tokens;
    mapping (uint => UriDatum) public    uriData;

    error Locked();
    error NotArtist();
    error OutsideOfMintPeriod();
    error BadRenderer();

    modifier onlyArtist(uint _tokenId) {
        if (msg.sender != tokens[_tokenId].artistAddress) revert NotArtist();
        _;
    }

    modifier whenActive(uint _editionNum) {
        uint start = vessel.blockEvents(tokens[_editionNum].eventNumStart);
        uint end   = vessel.blockEvents(tokens[_editionNum].eventNumEnd);

        if (block.number < start || block.number > end) revert OutsideOfMintPeriod();
        _;
    }

    constructor() 
        ERC1155("")
        Ownable(msg.sender)
    {

    }

    function setToken (
        uint _tokenId,
        string memory _artist,
        address _artistAddress,
        uint _supply,
        uint _price,
        uint _startEvent,
        uint _endEvent
    ) public onlyOwner {

        if (tokens[_tokenId].locked) revert Locked();
        require(_endEvent >= _startEvent, "Bad event range");

        tokens[_tokenId].artist = _artist;
        tokens[_tokenId].artistAddress = _artistAddress;
        tokens[_tokenId].maxSupply = _supply;
        tokens[_tokenId].price = _price;
        tokens[_tokenId].eventNumStart = _startEvent;
        tokens[_tokenId].eventNumEnd = _endEvent;

    }

    function setArtData (
        uint _tokenId,
        string memory _uriString,
        bool _usesRenderer,
        address _renderer
    ) public onlyArtist(_tokenId) {

        if (tokens[_tokenId].locked) revert Locked();

        uriData[_tokenId].uri           = _uriString;
        uriData[_tokenId].usesRenderer  = _usesRenderer;
        uriData[_tokenId].renderer      = _renderer;

    }

    function uri(uint256 id) public view override returns (string memory) {
        UriDatum memory u = uriData[id];

        if (u.usesRenderer) {
            address r = u.renderer;
            if (r == address(0)) revert BadRenderer();
            return IRenderer(r).uri(id);
        }

        // If a per-id URI was set, return it
        if (bytes(u.uri).length != 0) return u.uri;

        // Else fallback to base URI behavior (often ".../{id}.json")
        return super.uri(id);
    }

    function mint(uint _editionNum, address _to, uint _amount) public payable nonReentrant whenActive(_editionNum) {
        require (msg.value == tokens[_editionNum].price * 0.001 ether * _amount, "Price incorrect");

        uint256 newTotal = tokens[_editionNum].minted + _amount;
        require(newTotal <= tokens[_editionNum].maxSupply, "Supply exceeded");
        tokens[_editionNum].minted = newTotal;
        
        _mint(_to, _editionNum, _amount, "");
    }
        
    function adminMint(uint _editionNum, address _to, uint _amount) public onlyOwner {

        if (tokens[_editionNum].locked) revert Locked();

        uint256 newTotal = tokens[_editionNum].minted + _amount;
        require(newTotal <= tokens[_editionNum].maxSupply, "Sold out");
        tokens[_editionNum].minted = newTotal;
        
        _mint(_to, _editionNum, _amount, "");
    }

    function lockToken(uint _tokenId) public onlyOwner {
        tokens[_tokenId].locked = true;
    }

    function setVesselContract(address _a) public onlyOwner {
        vessel = IVesselToken(_a);
    }

    function withdraw() external onlyOwner{
        uint256 bal = address(this).balance;
        (bool ok, ) = payable(owner()).call{value: bal}("");
        require(ok, "ETH transfer failed");
    }

    function readBlockEvents(uint _e) public view returns (uint) {
        return vessel.blockEvents(_e);
    }

}

