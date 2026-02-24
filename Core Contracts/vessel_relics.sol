// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    function craftToDelegate(uint _tokenId) external view returns (address);
    function lockStart() external view returns (uint);
    function ownerOf(uint _tokenId) external view returns (address);
    function refreshMetadata(uint _tokenId) external;
    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }
}

contract THE_VESSEL_relics is Ownable {

    IVesselToken public vessel;

    struct relic {
        string kind;
        bytes[] data;
        uint entries;
        address machine;
    }

    mapping (uint => relic) public  RELICS;
    mapping(uint => uint) public    relicIdToIndex;
    mapping(uint => uint) public    relicToChosenEntry;

    uint[] public relicIds;

    error RelicAlreadyExists();
    error RelicDoesNotExist();
    error BytesTooLong();
    error NotRelic();
    error MustBeHolderOrDelegate();
    error WrongType();
    error OutOfRangeEntry();

    event RelicEntrySet(uint tokenId, uint entry);

    modifier onlyHolderOrDelegate(uint tokenId) {
        address owner = vessel.ownerOf(tokenId);
        address del = vessel.craftToDelegate(tokenId);
        if (msg.sender != owner && msg.sender != del) revert MustBeHolderOrDelegate();
        _;
    }
    
    constructor()  Ownable(msg.sender) {
        vessel =     IVesselToken    (0xECb92Cc7112b80A2234936315BbB493fb48d1463);
    }

    function addRelic(uint _tokenId, bytes[] memory _bytes, address _machine, string memory _kind) public onlyOwner {
        if (_bytes.length > _tokenId) revert BytesTooLong();
        if (_exists(_tokenId)) revert RelicAlreadyExists();

        for (uint i = 0; i < _bytes.length; i++) {
            RELICS[_tokenId].data.push(_bytes[i]);
        }

        RELICS[_tokenId].kind = _kind;
        RELICS[_tokenId].machine = _machine;
        RELICS[_tokenId].entries = _bytes.length;

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
        relic storage t = RELICS[_tokenId];

        if (vessel.craftToMachineStatus(_tokenId)) {
            return IMachine(t.machine).craftToPayload(_tokenId);
        }

        bytes[] storage arr = t.data;
        uint len = arr.length;
        if (len == 0) return "";

        // Capsule (non-vault, non-machine): always first entry
        if (!vessel.craftToVaultStatus(_tokenId)) {
            return arr[0];
        }

        // Vault: chosen entry is 1-based. If 0, default to latest (len).
        uint entry = relicToChosenEntry[_tokenId];
        if (entry == 0) entry = len;

        // entry must be in [1..len]
        if (entry > len) return "";

        // convert 1-based entry -> 0-based index
        return arr[entry - 1];
    }

    function vaultRelicToEntry(uint _tokenId, uint _entry) public view returns (bytes memory) {
        if (!vessel.craftToVaultStatus(_tokenId)) {revert WrongType();}
        if (!isRelic(_tokenId)) {revert NotRelic();}
        return RELICS[_tokenId].data[_entry - 1];
    }

    function setVaultEntryHolder(uint _tokenId, uint _entry) public onlyHolderOrDelegate(_tokenId) {
        if (!vessel.craftToVaultStatus(_tokenId)) revert WrongType();
        if (_entry == 0 ||_entry > RELICS[_tokenId].data.length) revert OutOfRangeEntry();
        relicToChosenEntry[_tokenId] = _entry;
        vessel.refreshMetadata(_tokenId);
        emit RelicEntrySet(_tokenId, _entry);
    }

    function setVesselContract(address _a) public onlyOwner {
        vessel = IVesselToken(_a);
    }

    function getTokenKind(uint _tokenId) external view returns (string memory) {
        return RELICS[_tokenId].kind;
    }

    function getTokenEntries(uint _tokenId) external view returns (uint) {
        return RELICS[_tokenId].entries;
    }
    function isRelic(uint _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return RELICS[tokenId].data.length != 0;
    }

}
