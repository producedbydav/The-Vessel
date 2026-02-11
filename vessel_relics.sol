// SPDX-License-Identifier: MIT
import "./base64.sol";
import "./LibString.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

pragma solidity ^0.8.20;

contract THE_VESSEL_relics is Ownable {

    struct token {
        string kind;
        bytes data;
        bool isMachine;
        bool isVault;
        address machine;
    }

    mapping (uint => token) public RELICS;
    uint[] public relicIds;

    constructor()  Ownable(msg.sender) {}

    function addRelic(uint _tokenId, bytes memory _bytes, string memory _kind) public onlyOwner {
        require (_bytes.length <= _tokenId);
        RELICS[_tokenId].data = _bytes;
        RELICS[_tokenId].kind = _kind;
        if (indexOf(relicIds, _tokenId) == -1) {
            relicIds.push(_tokenId);
        }
    }

    function relicToPayload(uint _tokenId) external view returns (bytes memory) {
        token memory t = RELICS[_tokenId];
        if (t.isMachine) {
            return IMachine(t.machine).craftToPayload(_tokenId);
        } else
        return RELICS[_tokenId].data;
    }

    function getTokenKind(uint _tokenId) external view returns (string memory) {
        return RELICS[_tokenId].kind;
    }

    function isRelic(uint _tokenId) public view returns (bool) {
        return indexOf(relicIds, _tokenId) != -1;
    }

    function readAllRelics() public view returns(bool[10001] memory relicList) {
        relicList[0] = false;
        for (uint i = 1; i <= 10000; i++) {
            relicList[i] = isRelic(i);
        }
    }

    function indexOf(uint[] memory arr, uint value) internal pure returns (int) {
        for (uint i = 0; i < arr.length; i++) {
            if (arr[i] == value) {
                return int(i); // found at index i
            }
        }
        return -1; // not found
    }

}
