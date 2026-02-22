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
    function craftToEntry(uint _tokenId) external view returns (uint);
    function craftToClaimBlock(uint _tokenId) external view returns (uint);
    function craftToClaimed(uint _tokenId) external view returns (bool);    
    function craftToMachineStatus(uint _tokenId) external view returns (bool);
    function craftToType(uint _tokenId) external view returns (string memory);
    function craftToChosenEntry(uint _tokenId) external view returns (uint);
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
    mapping(uint256 => uint256) public relicIdToIndex;
    
    uint[] public relicIds;

    error RelicAlreadyExists();
    error RelicDoesNotExist();
    error BytesTooLong();
    
    constructor()  Ownable(msg.sender) {
        vessel =     IVesselToken    (0x353433fc2468B08CeF3eD1bEec4b43e25D49C311);
    }

    function addRelic(uint _tokenId, bytes[] memory _bytes, address _machine, string memory _kind) public onlyOwner {
        if (_bytes.length > _tokenId) revert BytesTooLong();
        if (_exists(_tokenId)) revert RelicAlreadyExists();

        for (uint i = 0; i < _bytes.length; i++) {
            RELICS[_tokenId].data.push(_bytes[i]);
        }

        RELICS[_tokenId].kind = _kind;
        RELICS[_tokenId].machine = _machine;

        relicIdToIndex[_tokenId] = relicIds.length;
        relicIds.push(_tokenId);
    }

    function editRelic(uint _tokenId, bytes memory _bytes, uint _index) public onlyOwner {
        RELICS[_tokenId].data[_index] = _bytes;
    }

    function editKind(uint _tokenId, string memory _kind) public onlyOwner {
        RELICS[_tokenId].kind = _kind;
    }

    function removeRelic(uint _tokenId) public onlyOwner {
        if (!_exists(_tokenId)) revert RelicDoesNotExist();

        uint256 index = relicIdToIndex[_tokenId];
        uint256 lastIndex = relicIds.length - 1;

        if (index != lastIndex) {
            uint256 lastId = relicIds[lastIndex];
            relicIds[index] = lastId;
            relicIdToIndex[lastId] = index;
        }

        relicIds.pop();
        delete relicIdToIndex[_tokenId];
        delete RELICS[_tokenId]; // clears kind + data array storage
    }

    function relicToPayload(uint _tokenId) external view returns (bytes memory payload) {
        token memory t = RELICS[_tokenId];
        if (vessel.craftToMachineStatus(_tokenId)) {
            payload = IMachine(t.machine).craftToPayload(_tokenId);
        } else {
            bytes[] storage arr = RELICS[_tokenId].data;

            // For vaults: read selector; for others: read "current Entry" (latest)
            uint it;
            if (vessel.craftToVaultStatus(_tokenId)) {
                it = vessel.craftToChosenEntry(_tokenId);
                if (it == 0) it = vessel.craftToEntry(_tokenId); // default to latest
            } else {
                it = 1;
            }

            if (arr.length == 0) {
                payload = "";
            } else if (!vessel.craftToVaultStatus(_tokenId) && it == 0) {
                // capsule, first write
                payload = arr[0];
            } else if (it >= 1 && it <= arr.length) {
                // vault/capsule: Entry is 1-based, storage is 0-based
                payload = arr[it - 1];
            } else {
                // out-of-range protection
                payload = "";
            }
        }

    }

    function setVesselContract(address _a) public onlyOwner {
        vessel = IVesselToken(_a);
    }

    function getTokenKind(uint _tokenId) external view returns (string memory) {
        return RELICS[_tokenId].kind;
    }

    function isRelic(uint _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return RELICS[tokenId].data.length != 0;
    }

}
