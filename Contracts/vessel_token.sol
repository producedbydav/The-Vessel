// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";
import "./LibString.sol";

interface IExternalRenderer {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function craftToSVG(uint _tokenId) external view returns (string memory);
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

    address creator1 = 0xCcf0a1307E5e5Ad04E85d94d7f9D400390F0118a;
    address creator2 = 0x28940210Fc7Af79B154265AeaD728541405A0ecD;

    mapping (uint => uint) public blockEvents;

    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }

    mapping (address => role) public            addressToRole;
    mapping (uint => role) public               craftToRole;
    mapping (uint => bool) public               craftToClaimed;
    mapping (uint => uint) public               craftToClaimBlock;
    mapping (uint => bytes[]) public            payloadList;
    mapping (uint => uint) public               craftToIteration;
    mapping (uint => uint) public               craftToChosenIteration;
    mapping (uint => IMachine) public           craftToChosenMachine;
    IMachine public                             defaultMachine;

    modifier  notClaimed (uint[] memory _tokenIds) {
        for (uint i = 0; i < _tokenIds.length; i++){
            require (!craftToClaimed[_tokenIds[i]], "Already claimed");
            require (_tokenIds[i] >= 1 && _tokenIds[i] <= MAX_SUPPLY, "Out of range");
        }
        _;
    }

    modifier  onlyHolder (uint _tokenId) {
        require (msg.sender == ownerOf(_tokenId), "Must be holder of token");
        _;
    }

    modifier whenActive() {
        require (claimIsActive(), "Claiming is not active");
        _;
    }

    event MetadataUpdate    (uint _tokenId);
    //event TokenClaimed      (uint _tokenId);
    event LockStarted       (uint _blocknum);
    event PayloadSet        (uint _tokenId, uint _length);
    event MachineSet        (uint _tokenId, address _machine);
    event IterationSet      (uint _tokenId, uint _iteration);

    IExternalRenderer public renderer;

    constructor()
        ERC721("The Vessel", "VESSEL")
        Ownable(msg.sender)
    {
        blockEvents[0] = block.number;
        blockEvents[1] = block.number + 50000;
        defaultMachine = IMachine(0x4bc881B11019df89330F4bE3fa573183F452c05d);
        renderer = IExternalRenderer(0x4730dd1b1e477BE374F201571A7E555Da81ab979);
        relics = IRelics(0x3231477c3d23D1EB79EAFC557560b76Da6bAA148);
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

            // For vaults: read selector; for others: read "current iteration" (latest)
            uint it;
            if (craftToVaultStatus(_tokenId)) {
                it = craftToChosenIteration[_tokenId];
                if (it == 0) it = craftToIteration[_tokenId]; // default to latest
            } else {
                it = craftToIteration[_tokenId];
            }

            if (arr.length == 0) {
                payload = "";
            } else if (!craftToVaultStatus(_tokenId) && it == 0) {
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


    //========================================================//
    //======================= MINTING ========================//
    //========================================================//

    function claim(
        address _to,
        uint256[] memory _tokenIds,
        bytes memory _bytes,
        address _machine
    ) public payable notClaimed(_tokenIds) whenActive 
        //nonReentrant 
        {
        uint256 n = _tokenIds.length;
        require(n > 0, "No tokenIds");
        require(!claimIsPaused, "Claim has been paused");

        uint256 sumCap;
        for (uint256 i = 0; i < n; i++) {
            sumCap += _tokenIds[i];
        }

        require(msg.value == PRICE_PER_UNIT * sumCap, "Price incorrect");

        require(_bytes.length <= sumCap, "Bytes exceed capacity");

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

            _setPayload(tokenId, chunk); // ok with empty bytes if we're out
            craftToClaimed[tokenId] = true;
            craftToRole[tokenId] = addressToRole[msg.sender];
            craftToClaimBlock[tokenId] = block.number - blockEvents[1];
            _safeMint(_to, tokenId);
            claimedCount++;
            //emit TokenClaimed(tokenId);
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
            claimedCount++;
            
            uint256 idB = _pickUnused(uint256(keccak256(abi.encodePacked(base, "B", i))));
            _safeMint(creator2, idB);
            craftToClaimed[idB] = true;
            craftToClaimBlock[idB] = 0;
            claimedCount++;
            unchecked { i++; }
        }
        
        creatorSupplyClaimed = true;

    }


    //========================================================//
    //=============== WRITING BYTES TO TOKEN =================//
    //========================================================//

    function setRole(role _r) public {
        addressToRole[msg.sender] = _r;
    }

    function setPayloadHolder (uint _tokenId, bytes memory _bytes) public onlyHolder(_tokenId) {
        //require (!craftToMachineStatus(_tokenId), "Craft is a machine"); //secret space?
        require (!craftToLocked(_tokenId), "Craft is locked.");
        require (!relics.isRelic(_tokenId), "Craft is a relic.");
        _setPayload(_tokenId, _bytes);
        emit PayloadSet(_tokenId, _bytes.length);
        emit MetadataUpdate(_tokenId);
    }

    function setMachineHolder (uint _tokenId, address _machine) public onlyHolder(_tokenId) {
        require (craftToMachineStatus(_tokenId), "Craft is not a machine");
        require (!craftToLocked(_tokenId), "Craft is locked.");
        _setMachine (_tokenId, _machine);
        //emit MetadataUpdate(_tokenId);
    }

    function _setMachine (uint _tokenId, address _machine) internal {
        require(_machine != address(0), "Invalid machine address");
        require(_machine.code.length > 0, "Machine must be a contract");

        // Validate interface
        try IMachine(_machine).name() returns (string memory) {
            craftToChosenMachine[_tokenId] = IMachine(_machine);
            emit MachineSet(_tokenId, _machine);
        } catch {
            revert("Machine does not implement required interface");
        }
        
    }

    function setVaultIterationHolder(uint _tokenId, uint _iteration) public onlyHolder(_tokenId) {
        require (craftToVaultStatus(_tokenId), "Craft is not a vault");
        craftToChosenIteration[_tokenId] = _iteration;
        emit IterationSet(_tokenId, _iteration);
        //emit MetadataUpdate(_tokenId);
    }

    function _setPayload (uint _tokenId, bytes memory _bytes) internal {
        require (_bytes.length <= _tokenId, "String too long"); 
        if (lockStart != 0) {require (craftToLockBlock(_tokenId) > block.number, "Token is locked");}
        if (!craftToVaultStatus(_tokenId)) {   //capsule
            if (craftToIteration[_tokenId] == 0) {
                payloadList[_tokenId].push(_bytes);
                craftToIteration[_tokenId]++;
            } else {
                payloadList[_tokenId][0] = _bytes;
            }
        } 
        else {                                  //vault
            payloadList[_tokenId].push(_bytes);
            craftToIteration[_tokenId]++;
        }
        //emit MetadataUpdate(_tokenId);
    }


    //========================================================//
    //=========== TOKEN URI / RENDERER FUNCTIONS =============//
    //========================================================//

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(_tokenId) != address(0), "Does not exist");
        return renderer.tokenURI(_tokenId);
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
        require(claimedCount == MAX_SUPPLY, "Not all claimed");
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
        (bool ok, ) = payable(owner()).call{value: bal}("");
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




