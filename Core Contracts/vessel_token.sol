// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

interface IExternalRenderer {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function craftToSVG(uint _tokenId) external view returns (string memory);
    function contractURI() external view returns (string memory);
}

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

interface IRelics {
    function RELICS(uint _tokenId) external view returns (string memory kind, bytes memory data);
    function relicIds(uint256) external view returns (uint256);
    function relicToPayload(uint _tokenId) external view returns (bytes memory);
    function relicToKind(uint _tokenId) external view returns (string memory);
    function isRelic(uint _tokenId) external view returns (bool);
}

contract THE_VESSEL is ERC721, Ownable, ReentrancyGuard {

    IRelics public relics;
    uint amountMachines = 1500;
    uint amountVault = 3650; //4850 3650 1500
    uint public lockStart;
    uint public claimedCount;
    bool public claimIsPaused;
    bool public creatorSupplyClaimed;

    uint public constant MAX_SUPPLY = 10000;
    uint public constant BLOCKS_PER_DAY = 7200;
    uint public constant PRICE_PER_UNIT = 0.00001 ether;
    uint public constant LOCK_DIVISOR = 10;

    address immutable creator1 = 0xCcf0a1307E5e5Ad04E85d94d7f9D400390F0118a;
    address immutable creator2 = 0x28940210Fc7Af79B154265AeaD728541405A0ecD;

    mapping (uint => uint) public blockEvents;

    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }

    mapping (uint => bytes[]) private           payloadList;
    mapping (address => role) public            addressToRole;
    mapping (uint => role) public               craftToRole;
    mapping (uint => bool) public               craftToClaimed;
    mapping (uint => uint) public               craftToClaimBlock;
    mapping (uint => uint) public               craftToEntry;
    mapping (uint => uint) public               craftToChosenEntry;
    mapping (uint => IMachine) public           craftToChosenMachine;
    mapping (uint => address) public            craftToDelegate;
    IMachine public                             defaultMachine;

    error AlreadyClaimed();
    error OutOfRange();
    error MustBeHolder();
    error MustBeHolderOrDelegate();
    error ClaimPaused();
    error ClaimNotActive();
    error CraftLocked();
    error PriceIncorrect();
    error BytesExceedCapacity();
    error InvalidMachine();
    error Locked();
    error IsRelic();
    error WrongType();
    error NotAllClaimed();
    error CraftNotClaimed();
    error OutOfRangeEntry();
    
    modifier  notClaimed (uint[] memory _tokenIds) {
        for (uint i = 0; i < _tokenIds.length; i++){
            if (craftToClaimed[_tokenIds[i]]) revert AlreadyClaimed();
            if (_tokenIds[i] < 1 || _tokenIds[i] > MAX_SUPPLY) revert OutOfRange();
        }
        _;
    }

    modifier  onlyHolder (uint _tokenId) {
        if (msg.sender != ownerOf(_tokenId)) revert MustBeHolder();
        _;
    }

    modifier  onlyHolderOrDelegate (uint _tokenId) {
        if (
            craftToDelegate[_tokenId] == address(0) && msg.sender != ownerOf(_tokenId) || 
            craftToDelegate[_tokenId] != address(0)  && msg.sender != craftToDelegate[_tokenId]
        )
        revert MustBeHolderOrDelegate();
        _;
    }

    modifier whenActive() {
        if (!claimIsActive()) revert ClaimNotActive();
        _;
    }

    event MetadataUpdate    (uint _tokenId);
    event LockStarted       (uint _blocknum);
    event PayloadSet        (uint _tokenId, uint _length);
    event MachineSet        (uint _tokenId, address _machine);
    event EntrySet          (uint _tokenId, uint _Entry);
    event DelegateSet       (uint _tokenId, address _delegate);
    event RoleSet           (address _user, role _role);

    IExternalRenderer public renderer;

    constructor()                                                                                           
        ERC721("The Vessel", "VESSEL")
        Ownable(msg.sender)
    {
        blockEvents[0] = block.number;
        blockEvents[1] = block.number + 50400;
        defaultMachine =    IMachine(0x4bc881B11019df89330F4bE3fa573183F452c05d);
        relics =            IRelics(0x96DbC03929F07339EbC105E4341Cabb8aE586682);
    }

    function craftToPayload(uint _tokenId) public view returns (bytes memory payload) {
        // 1. Relic
        if (relics.isRelic(_tokenId)) {
            payload = relics.relicToPayload(_tokenId);
        }

        // 2. Machine
        else if (craftToMachineStatus(_tokenId)) {
            payload = craftToMachine(_tokenId).craftToPayload(_tokenId);
        }

        // 3. Local payload storage
        else {
            bytes[] storage arr = payloadList[_tokenId];

            // For vaults: read selector; for others: read "current Entry" (latest)
            uint it;
            if (craftToVaultStatus(_tokenId)) {
                it = craftToChosenEntry[_tokenId];
                if (it == 0) it = craftToEntry[_tokenId]; // default to latest
            } else {
                it = craftToEntry[_tokenId];
            }

            if (arr.length == 0) {
                payload = "";
            } else if (!craftToVaultStatus(_tokenId) && it == 0) {
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


    //========================================================//
    //======================= MINTING ========================//
    //========================================================//

    function claim(
        address _to,
        uint256[] memory _tokenIds,
        bytes memory _bytes,
        address _machine
    ) public payable notClaimed(_tokenIds) 
        whenActive 
        nonReentrant 
        {
        uint256 n = _tokenIds.length;
        if (claimIsPaused) revert ClaimPaused();

        uint256 sumCap;
        for (uint256 i = 0; i < n; i++) {
            sumCap += _tokenIds[i];
        }

        if (msg.value != PRICE_PER_UNIT * sumCap) revert PriceIncorrect();

        if (_bytes.length > sumCap) revert BytesExceedCapacity();

        uint256 offset = 0;
        for (uint256 i = 0; i < n; i++) {
            uint256 tokenId = _tokenIds[i];

            uint256 cap = tokenId; // max bytes this token can take

            uint256 remaining = (offset >= _bytes.length) ? 0 : (_bytes.length - offset);
            uint256 take = remaining < cap ? remaining : cap;

            bytes memory chunk = new bytes(take);
            for (uint256 k = 0; k < take; k++) {
                chunk[k] = _bytes[offset + k];
            }
            offset += take;

            if (craftToMachineStatus(tokenId)) {
                _setMachine(tokenId, _machine);
            }

            if (chunk.length != 0) {_setPayload(tokenId, chunk);} // ok with empty bytes if we're out
            craftToClaimed[tokenId] = true;
            craftToRole[tokenId] = addressToRole[msg.sender];
            craftToClaimBlock[tokenId] = block.number - blockEvents[1];
            _safeMint(_to, tokenId);
            claimedCount++;
        }

    }

    function mintCreatorSupply() public onlyOwner {

        require (!creatorSupplyClaimed);
        
        bytes32 base = keccak256(
            abi.encodePacked(
                block.prevrandao,
                block.number,
                block.timestamp,
                msg.sender,
                creator1,
                creator2
            )
        );

        
        for (uint256 i = 0; i < 50;) {
            uint256 idA = _pickUnused(uint256(keccak256(abi.encodePacked(base, "A", i))));
            _safeMint(creator1, idA);
            craftToClaimed[idA] = true;
            craftToClaimBlock[idA] = 0;
            craftToRole[idA] = role.navigator;
            claimedCount++;
            
            uint256 idB = _pickUnused(uint256(keccak256(abi.encodePacked(base, "B", i))));
            _safeMint(creator2, idB);
            craftToClaimed[idB] = true;
            craftToClaimBlock[idB] = 0;
            craftToRole[idB] = role.navigator;
            claimedCount++;
            unchecked { i++; }
        }
        
        creatorSupplyClaimed = true;

    }

    function vaultToEntry(uint _tokenId, uint _entry) public view returns (bytes memory) {
        if (!craftToVaultStatus(_tokenId)) {revert WrongType();}
        return payloadList[_tokenId][_entry];
    }


    //========================================================//
    //=============== WRITING BYTES TO TOKEN =================//
    //========================================================//

    function setRole(role _r) public {
        addressToRole[msg.sender] = _r;
        emit RoleSet(msg.sender, _r);
    }

    function setPayloadHolder (uint _tokenId, bytes memory _bytes) public onlyHolderOrDelegate(_tokenId) {
        if (craftToMachineStatus(_tokenId)) revert WrongType();
        if (craftToLocked(_tokenId)) revert CraftLocked();
        if (relics.isRelic(_tokenId)) revert IsRelic();
        _setPayload(_tokenId, _bytes);
        emit PayloadSet(_tokenId, _bytes.length);
        emit MetadataUpdate(_tokenId);
    }

    function setMachineHolder (uint _tokenId, address _machine) public onlyHolder(_tokenId) {
        if (craftToLocked(_tokenId)) revert CraftLocked();
        if (!craftToMachineStatus(_tokenId)) revert WrongType();
        _setMachine (_tokenId, _machine);
        emit MetadataUpdate(_tokenId);
    }

    function setVaultEntryHolder(uint _tokenId, uint _entry) public onlyHolder(_tokenId) {
        if (!craftToVaultStatus(_tokenId)) revert OutOfRangeEntry();
        if (_entry > craftToEntry[_tokenId]) revert WrongType();
        craftToChosenEntry[_tokenId] = _entry;
        emit EntrySet(_tokenId, _entry);
        emit MetadataUpdate(_tokenId);
    }

    function _setMachine (uint _tokenId, address _machine) internal {
        if (_machine == address(0) || _machine.code.length == 0) revert InvalidMachine();
        craftToChosenMachine[_tokenId] = IMachine(_machine);
        emit MachineSet(_tokenId, _machine);
    }

    function _setPayload (uint _tokenId, bytes memory _bytes) internal {
        if (craftToLocked(_tokenId)) revert CraftLocked();
        if (_bytes.length > _tokenId) revert BytesExceedCapacity();
        if (!craftToVaultStatus(_tokenId)) {   //capsule
            if (craftToEntry[_tokenId] == 0) {
                payloadList[_tokenId].push(_bytes);
                craftToEntry[_tokenId]++;
            } else {
                payloadList[_tokenId][0] = _bytes;
            }
        } 
        else {                                  //vault
            payloadList[_tokenId].push(_bytes);
            craftToEntry[_tokenId]++;
        }
    }

    function setDelegate(uint _tokenId, address _delegate) public onlyHolder(_tokenId) {
        craftToDelegate[_tokenId] = _delegate;
        emit DelegateSet(_tokenId, _delegate);
    }


    //========================================================//
    //=========== TOKEN URI / RENDERER FUNCTIONS =============//
    //========================================================//

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (_ownerOf(_tokenId) == address(0)) revert CraftNotClaimed();
        return renderer.tokenURI(_tokenId);
    }

    function contractURI() external view returns (string memory) {
        return renderer.contractURI();
    }

    function craftToSVG(uint _tokenId) external view returns (string memory) {
        return renderer.craftToSVG(_tokenId);
    }

    function craftToLocked(uint _tokenId) public view returns (bool) {
        return craftToLockBlock(_tokenId) < block.number;
    }

    function craftToType(uint _tokenId) public view returns (string memory) {
        require(_tokenId <= MAX_SUPPLY, "Out of range");
        if (craftToMachineStatus(_tokenId)) {return "Machine";}
        else if (craftToVaultStatus(_tokenId)) {return "Vault";}
        else {return "Capsule";}
    }

    function craftToMachine(uint _tokenId) public view returns (IMachine) {
        if (address(craftToChosenMachine[_tokenId]) == address(0x0)) {
            if (craftToMachineStatus(_tokenId)) {
                return defaultMachine;
            }
        } else {
            return craftToChosenMachine[_tokenId];
        }
    }

    function craftToMachineStatus(uint _tokenId) public view returns (bool) {
        uint256 r = _permute(_tokenId);
        return r <= amountMachines;
    }

    function craftToVaultStatus(uint _tokenId) public view returns (bool) {
        uint256 r = _permute(_tokenId);
        return r >= amountMachines && r <= amountMachines + amountVault;
    }

    function craftToLockBlock(uint _tokenId) public view returns (uint) {
        if (lockStart == 0) {return type(uint).max;}
        else {
            return lockStart + (_tokenId * BLOCKS_PER_DAY) / LOCK_DIVISOR;
        }
    }

    function startLockClock() public onlyOwner {
        if(claimedCount < MAX_SUPPLY) revert NotAllClaimed();
        lockStart = block.number;
        emit LockStarted(block.number);
    }

    uint32 private constant W_GREY  = 9540;
    uint32 private constant W_GREEN =  100;
    uint32 private constant W_RED   =  40;
    uint32 private constant W_BLUE  =   15; 
    uint32 private constant W_TOTAL = W_GREY + W_RED + W_GREEN + W_BLUE;

    function craftToColorMode(uint _tokenId) public view returns (uint8) {
        uint256 r = uint256(keccak256(abi.encodePacked(blockEvents[0], _tokenId))) % W_TOTAL;

        if (r < W_GREY) return 0;
        r -= W_GREY;
        if (r < W_RED) return 1;
        r -= W_RED;
        if (r < W_GREEN) return 2;
        // else must be blue range
        return 3; 
    }

    function refreshMetadata(uint _tokenId) public {
        emit MetadataUpdate(_tokenId);
    }
    

    //========================================================//
    //=================== OTHER ADMIN ========================//
    //========================================================//

    function setRenderer(address _newRenderer) public onlyOwner {
        renderer = IExternalRenderer(_newRenderer);
    }

    function setRelics(address _relics) public onlyOwner {
        relics = IRelics(_relics);
    }

    function setDefaultMachine(address _machine) public onlyOwner {
        defaultMachine = IMachine(_machine);
    }

    function setBlockEvent(uint _event, uint _block) public onlyOwner {
        blockEvents[_event] = _block;
    }

    function withdraw() external onlyOwner{
        uint256 bal = address(this).balance;
        (bool ok, ) = payable(creator1).call{value: bal}("");
        require(ok, "ETH transfer failed");
    }

    function togglePaused() public onlyOwner {
        claimIsPaused = !claimIsPaused;
    } 

    function claimIsActive() public view returns (bool) {
        return block.number >= blockEvents[1];
    }


    //========================================================//
    //====================== HELPERS =========================//
    //========================================================//

    function _permute(uint256 x) internal view returns (uint256) {
        require(x >= 1 && x <= MAX_SUPPLY, "x out of range");
        uint256 v = x - 1;           // 0..9999

        while (true) {
            // operate on 14-bit space 0..16383
            uint256 L = v & 127;           // low 7 bits
            uint256 R = (v >> 7) & 127;    // high 7 bits

            unchecked {
                for (uint256 r = 0; r < 6; r++) { // 6+ rounds is fine
                    uint256 F = uint256(keccak256(abi.encodePacked(R, blockEvents[0], r))) & 127;
                    (L, R) = (R, (L ^ F) & 127);
                }
            }

            uint256 y = L | (R << 7);      // 0..16383
            if (y < MAX_SUPPLY) return y + 1;   // accept if in domain
            v = y;                         // cycle-walk otherwise
        }
    }

    function _pickUnused(uint256 seed) internal view returns (uint256 tokenId) {
        uint256 id = (seed % MAX_SUPPLY) + 1; // 1..10000

        // Walk forward until we find an unclaimed slot
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            if (!craftToClaimed[id]) {
                return id;
            }

            unchecked {
                id++;
                if (id > MAX_SUPPLY) id = 1; // wrap
            }
        }

        revert("No unused tokens left");
    }

}
