// SPDX-License-Identifier: MIT
import "./base64.sol";
import "./LibString.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

interface IVesselToken {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function craftToVaultStatus(uint _tokenId) external view returns (bool);
    function craftToRole(uint _tokenId) external view returns (role);
    function craftToMachine(uint _tokenId) external view returns (IMachine);
    function craftToColorMode(uint256 tokenId) external view returns (uint8);
    function craftToLockBlock(uint _tokenId) external view returns (uint);
    function craftToLocked(uint _tokenId) external view returns (bool);
    function craftToIteration(uint _tokenId) external view returns (uint);
    function craftToClaimBlock(uint _tokenId) external view returns (uint);
    function craftToClaimed(uint _tokenId) external view returns (bool);    
    function craftToMachineStatus(uint _tokenId) external view returns (bool);
    function craftToType(uint _tokenId) external view returns (string memory);
    function craftToChosenIteration(uint _tokenId) external view returns (uint);
    function lockStart() external view returns (uint);
    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }
}

pragma solidity ^0.8.20;

contract THE_VESSEL_relics is Ownable {

    IVesselToken vessel;

    struct token {
        string kind;
        bytes[] data;
        address machine;
    }

    mapping (uint => token) public RELICS;
    mapping(uint256 => bool) public isRelicId;
    
    uint[] public relicIds;

    constructor()  Ownable(msg.sender) {
        vessel =     IVesselToken    (0x711A2077705905205826f9127b270d3c0354971D);
    }

    function addRelic(uint _tokenId, bytes[] memory _bytes, string memory _kind) public onlyOwner {
        require (_bytes.length <= _tokenId);

        for (uint i = 0; i < _bytes.length; i++) {
            RELICS[_tokenId].data[i] = _bytes[i];
        }

        RELICS[_tokenId].kind = _kind;

        if (!isRelicId[_tokenId]) {
            isRelicId[_tokenId] = true;
            relicIds.push(_tokenId);
        }
    }

    function editRelic(uint _tokenId, bytes memory _bytes, uint _index) public onlyOwner {
        RELICS[_tokenId].data[_index] = _bytes;
    }

    function editKind(uint _tokenId, string memory _kind) public onlyOwner {
        RELICS[_tokenId].kind = _kind;
    }

    function relicToPayload(uint _tokenId) external view returns (bytes memory payload) {
        token memory t = RELICS[_tokenId];
        if (vessel.craftToMachineStatus(_tokenId)) {
            payload = IMachine(t.machine).craftToPayload(_tokenId);
        } else {
            bytes[] storage arr = RELICS[_tokenId].data;

            // For vaults: read selector; for others: read "current iteration" (latest)
            uint it;
            if (vessel.craftToVaultStatus(_tokenId)) {
                it = vessel.craftToChosenIteration(_tokenId);
                if (it == 0) it = vessel.craftToIteration(_tokenId); // default to latest
            } else {
                it = 1;
            }

            if (arr.length == 0) {
                payload = "";
            } else if (!vessel.craftToVaultStatus(_tokenId) && it == 0) {
                // capsule, first write
                payload = arr[0];
            } else if (it >= 1 && it <= arr.length) {
                // vault/capsule: iteration is 1-based, storage is 0-based
                payload = arr[it - 1];
            } else {
                // out-of-range protection
                payload = "";
            }
        }

    }

    function getTokenKind(uint _tokenId) external view returns (string memory) {
        return RELICS[_tokenId].kind;
    }

    function isRelic(uint _tokenId) public view returns (bool) {
        return isRelicId[_tokenId];
    }

    function readAllRelics() public view returns(bool[10001] memory relicList) {
        relicList[0] = false;
        for (uint i = 1; i <= 10000; i++) {
            relicList[i] = isRelic(i);
        }
    }

}
