// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVESSEL {
    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }

    // ===== External dependency interfaces =====

    interface IExternalRenderer {
        function tokenURI(uint256 _tokenId) external view returns (string memory);
        function craftToSVG(uint256 _tokenId) external view returns (string memory);
        function contractURI() external view returns (string memory);
    }

    interface IMachine {
        function craftToPayload(uint256 _tokenId) external view returns (bytes memory);
        function name() external view returns (string memory);
    }

    interface IRelics {
        struct relic {
            string kind;
            bytes[] data;
            address machine;
        }

        function RELICS(uint256 _tokenId) external view returns (relic memory);
        function relicIds(uint256) external view returns (uint256);
        function relicToPayload(uint256 _tokenId) external view returns (bytes memory);
        function getTokenKind(uint256 _tokenId) external view returns (string memory);
        function isRelic(uint256 _tokenId) external view returns (bool);
    }

    // ===== Events =====

    event MetadataUpdate(uint256 _tokenId);
    event LockStarted(uint256 _blocknum);
    event PayloadSet(uint256 _tokenId, uint256 _length);
    event MachineSet(uint256 _tokenId, address _machine);
    event EntrySet(uint256 _tokenId, uint256 _entry);
    event DelegateSet(uint256 _tokenId, address _delegate);
    event RoleSet(address _user, role _role);

    // ===== Constants / public state =====

    function MAX_SUPPLY() external view returns (uint256);
    function BLOCKS_PER_DAY() external view returns (uint256);
    function LOCK_DIVISOR() external view returns (uint256);
    function PRICE_PER_UNIT() external view returns (uint256);

    function lockStart() external view returns (uint256);
    function claimedCount() external view returns (uint256);
    function claimIsPaused() external view returns (bool);
    function creatorSupplyClaimed() external view returns (bool);

    function renderer() external view returns (IExternalRenderer);
    function relics() external view returns (IRelics);
    function defaultMachine() external view returns (IMachine);

    function addressToRole(address) external view returns (role);
    function craftToRole(uint256) external view returns (role);
    function craftToClaimed(uint256) external view returns (bool);
    function craftToClaimBlock(uint256) external view returns (uint256);
    function craftToEntry(uint256) external view returns (uint256);
    function craftToChosenEntry(uint256) external view returns (uint256);
    function craftToChosenMachine(uint256) external view returns (IMachine);
    function craftToDelegate(uint256) external view returns (address);
    function blockEvents(uint256) external view returns (uint256);
    function blockEventLock(uint256) external view returns (bool);

    // ===== Core reads =====

    function craftToPayload(uint256 _tokenId) external view returns (bytes memory payload);
    function vaultToEntry(uint256 _tokenId, uint256 _entry) external view returns (bytes memory);

    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function contractURI() external view returns (string memory);
    function craftToSVG(uint256 _tokenId) external view returns (string memory);

    function craftToLocked(uint256 _tokenId) external view returns (bool);
    function craftToType(uint256 _tokenId) external view returns (string memory);
    function craftToMachine(uint256 _tokenId) external view returns (IMachine);
    function craftToMachineStatus(uint256 _tokenId) external view returns (bool);
    function craftToVaultStatus(uint256 _tokenId) external view returns (bool);
    function craftToLockBlock(uint256 _tokenId) external view returns (uint256);
    function craftToColorMode(uint256 _tokenId) external view returns (uint8);

    function claimIsActive() external view returns (bool);

    // ===== ERC721 reads commonly needed =====

    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);

    // ===== Writes =====

    function claim(
        address _to,
        uint256[] calldata _tokenIds,
        bytes calldata _bytes,
        address _machine
    ) external payable;

    function mintCreatorSupply() external;

    function setRole(role _r) external;
    function setPayloadHolder(uint256 _tokenId, bytes calldata _bytes) external;
    function setMachineHolder(uint256 _tokenId, address _machine) external;
    function setVaultEntryHolder(uint256 _tokenId, uint256 _entry) external;
    function setDelegate(uint256 _tokenId, address _delegate) external;

    function refreshMetadata(uint256 _tokenId) external;

    // ===== Admin =====

    function setRenderer(address _newRenderer) external;
    function setRelics(address _relics) external;
    function setDefaultMachine(address _machine) external;
    function setBlockEvent(uint256 _event, uint256 _block) external;
    function lockEvent(uint256 _event) external;
    function withdraw() external;
    function togglePaused() external;
}
