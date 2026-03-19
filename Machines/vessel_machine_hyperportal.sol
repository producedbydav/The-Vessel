// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

interface IVesselToken {
    function ownerOf(uint _tokenId) external view returns (address);
    function craftToDelegate(uint _tokenId) external view returns (address);
}

interface ITerraforms {
    function tokenHeightmapIndices(uint _index) external view returns (uint[32][32] memory);
    function tokenToPlacement(uint _tokenId) external view returns (uint);
    function seed() external view returns (uint);
    function SUPPLY() external view returns (uint);
}

interface ITerraformsData {
    function levelAndTile(
        uint256 placement,
        uint256 seed
    ) external  view returns (uint256 level, uint256 tile);
}

interface ITerraformsLevelData {
    function levelToParcelCount(
        uint256 _level
    ) external view returns (uint256);

    function levelToToken(
        uint256 _level,
        uint256 _index
    ) external view returns (uint256 __tokenId);
}
/**
 * @notice Terraforms heightmap sampler:
 * - Source is always 32*32 = 1024 cells.
 * - Heights are 0..9 (assumed); we scale to 0..255.
 * - We build a "next-square band" (side^2 where side=ceilSqrt(totalSize)),
 *   then spread-crop back to totalSize (== tokenId in your renderer).
 */
contract Machine_Hyperportal is IMachine, Ownable {
    string public name = "Hyperportal";

    ITerraforms public          terraforms;
    ITerraformsData public      tfData;
    ITerraformsLevelData public levels;
    IVesselToken public         vessel;

    error MustBeHolderOrDelegate();

    mapping (uint => uint) public relicToLevel;
    mapping (uint => uint) public craftToChosenParcel;

    modifier onlyHolderOrDelegate(uint tokenId) {
        address owner = vessel.ownerOf(tokenId);
        address del = vessel.craftToDelegate(tokenId);
        if (msg.sender != owner && msg.sender != del) revert MustBeHolderOrDelegate();
        _;
    }

    constructor() 
        Ownable(msg.sender)
    {
        terraforms = ITerraforms        (0x4E1f41613c9084FdB9E34E11fAE9412427480e56);
        tfData = ITerraformsData        (0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2);
        levels = ITerraformsLevelData   (0x4b45b8D5C87F80c9a8c0642230Be02004863E187);
        vessel = IVesselToken           (0xECb92Cc7112b80A2234936315BbB493fb48d1463);
    }

    function craftToPayload(uint _tokenId) external view returns (bytes memory) {

        uint parcel;

        if (relicToLevel[_tokenId] != 0) {
            uint level = relicToLevel[_tokenId];
            uint index = block.number % levels.levelToParcelCount(level);
            parcel = levels.levelToToken(level, index);
        } else {
            if (craftToChosenParcel[_tokenId] == 0) {
                parcel = uint(keccak256(abi.encodePacked(_tokenId))) % terraforms.SUPPLY();
            } else {
                parcel = craftToChosenParcel[_tokenId];
            }
        }
        uint[32][32] memory hm = terraforms.tokenHeightmapIndices(parcel);
        return condenseBySampling(hm, _tokenId);
    }

    function condenseBySampling(
        uint[32][32] memory hm,
        uint256 totalSize
    )
        public
        pure
        returns (bytes memory out)
    {
        if (totalSize == 0) return new bytes(0);

        // Destination square side. We render into a square grid, then trim to totalSize.
        uint256 destSide = _ceilSqrt(totalSize);
        uint256 squareLen = destSide * destSide;

        bytes memory squareOut = new bytes(squareLen);

        // Resample SOURCE 32x32 -> DEST destSide x destSide using cell-center mapping.
        for (uint256 y = 0; y < destSide; ++y) {
            // map destination row center to source row 0..31
            uint256 srcY = ((2 * y + 1) * 32) / (2 * destSide);
            if (srcY > 31) srcY = 31;

            for (uint256 x = 0; x < destSide; ++x) {
                // map destination col center to source col 0..31
                uint256 srcX = ((2 * x + 1) * 32) / (2 * destSide);
                if (srcX > 31) srcX = 31;

                uint256 h = hm[srcY][srcX];
                if (h > 9) h = 9;

                uint8 v = uint8((h * 255) / 9);

                uint256 dstIdx = y * destSide + x;
                squareOut[dstIdx] = bytes1(v);
            }
        }

        // Trim to exact requested size.
        out = new bytes(totalSize);
        for (uint256 i = 0; i < totalSize; ++i) {
            out[i] = squareOut[i];
        }
    }

    function setCraftToChosenParcel(uint _craft, uint _parcel) public onlyHolderOrDelegate(_craft) {
        craftToChosenParcel[_craft] = _parcel;
    }

    function _ceilSqrt(uint256 x) internal pure returns (uint256) {
        uint256 r = _floorSqrt(x);
        return (r * r == x) ? r : (r + 1);
    }

    function _floorSqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function setRelicToLevel(uint _relic, uint _level) public onlyOwner {
        relicToLevel[_relic] = _level;
    }
}
