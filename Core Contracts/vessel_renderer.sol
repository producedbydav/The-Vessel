// SPDX-License-Identifier: MIT
import "./base64.sol";
import "./LibString.sol";
import "./IFileStore.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

pragma solidity ^0.8.20;

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
    function lockStart() external view returns (uint);
    enum role {
        undefined,
        navigator,
        steward,
        merchant
    }
}

interface IRelics {
    function RELICS(uint _tokenId) external view returns (string memory kind, bytes memory data);
    function relicIds(uint256) external view returns (uint256); // auto getter for public array
    function relicToPayload(uint _tokenId) external view returns (bytes memory);
    function relicToKind(uint _tokenId) external view returns (string memory);
    function isRelic(uint _tokenId) external view returns (bool);
}

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

interface IMetadataExtention {
    function metadataExtension(uint _tokenId) external view returns (string memory);
}

contract THE_VESSEL_renderer is Ownable {

    IVesselToken        public token;
    IRelics             public relics;
    IMetadataExtention  public extention;
    uint8 private constant MODE_GREY  = 0;
    uint8 private constant MODE_RED   = 1;
    uint8 private constant MODE_GREEN = 2;
    uint8 private constant MODE_BLUE  = 3;

    IFileStore public fileStore;

    string[] colors = ["greyscale", "Red", "Green", "Blue"];

    constructor() 
        Ownable(msg.sender)
    {
        token =     IVesselToken    (0x353433fc2468B08CeF3eD1bEec4b43e25D49C311);
        relics =    IRelics         (0x3231477c3d23D1EB79EAFC557560b76Da6bAA148);
        fileStore = IFileStore      (0xFe1411d6864592549AdE050215482e4385dFa0FB);
    }

    function tokenURI(uint256 _tokenId) external view returns(string memory) {
        require (token.craftToClaimed(_tokenId), "Token has not been claimed yet");
        string memory image;
        string memory prefix;
        if (token.craftToEntry(_tokenId) != 0 || token.craftToMachineStatus(_tokenId)) {
            string memory svg = craftToSVG(_tokenId);
            prefix = 'data:image/svg+xml;base64,';
            image = Base64.encode(bytes(svg));
        }
        else {
            image = getEmptyImage();
            prefix = 'data:image/jpeg;base64,';
        }
        string memory traits = craftToTraits(_tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"Craft #', LibString.toString(_tokenId),
                        '","image": "',
                        prefix,
                        image,
                        '","attributes": [',
                            traits,
                        ']}'
                    )
                )
            )
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function craftToTraits(uint _tokenId) public view returns (string memory) {

        string memory lockStr = token.craftToLocked(_tokenId) ? "True" : "False";
        string memory lockBlock = token.lockStart() != 0 ? LibString.toString(token.craftToLockBlock(_tokenId)) : "n/a";
        string memory claimStr = LibString.toString(token.craftToClaimBlock(_tokenId));
        string memory typeStr = token.craftToType(_tokenId);
        string memory roleStr = roleToString(_tokenId);
        string memory color = colors[token.craftToColorMode(_tokenId)];

        bytes memory colorLine = (token.craftToColorMode(_tokenId) != 0) ? abi.encodePacked     ('{"trait_type": "Color", "value": "', color, '"}, ') : new bytes(0);
        bytes memory axiomLine = _isAxiom(_tokenId) ? abi.encodePacked                          ('{"trait_type": "Axiom", "value": "True"}, ') : new bytes(0);
        bytes memory relicLine = relics.isRelic(_tokenId) ? abi.encodePacked                    ('{"trait_type": "Relic", "value": "True"}, ') : new bytes(0);
        bytes memory entriesLine = token.craftToVaultStatus(_tokenId) ? abi.encodePacked        ('{"trait_type": "Entries", "value": "', LibString.toString(token.craftToEntry(_tokenId)), '"}, ') : new bytes(0);
        bytes memory machineLine;

        //string memory ext = getMetadataExtention(_tokenId);

        if (token.craftToMachineStatus(_tokenId)) {
            address m = address(token.craftToMachine(_tokenId));
            if (m != address(0) && m.code.length > 0) {
                try IMachine(m).name() returns (string memory n) {
                    string memory escapedName = LibString.escapeJSON(n, false);
                    machineLine = abi.encodePacked(
                        '{"trait_type":"Machine Name","value":"',
                        escapedName,
                        '"}, '
                    );
                } catch {}
            }
        }
        
        bytes memory traits = abi.encodePacked(
            '{"trait_type": "Type", "value": "', typeStr, '"}, ',
            '{"trait_type": "Role", "value": "', roleStr, '"}, ',
            '{"trait_type": "Lock Block", "value": "', lockBlock, '"}, '
        );

        bytes memory traits2 = abi.encodePacked(
            '{"trait_type": "Locked", "value": "', lockStr, '"}, ',
            machineLine,
            relicLine,
            axiomLine
        );

        bytes memory traits3 = abi.encodePacked(
            colorLine,
            entriesLine,
            '{"trait_type": "Claim Block", "value": "', claimStr, '"} '
        );

        return string(abi.encodePacked(traits, traits2, traits3));
    }

    function getMetadataExtention(uint _tokenId) private view returns (string memory) {
        return "";
    }

    function craftToSVG(uint _tokenId) public view returns (string memory) {
        bytes memory imgSource = token.craftToPayload(_tokenId);
        if (imgSource.length == 0) imgSource = new bytes(_tokenId);
        string memory svg = render(imgSource, token.craftToColorMode(_tokenId), _tokenId);
        return svg;
    }

    function contractURI() external pure returns (string memory) {

        string memory image = string(abi.encodePacked(
                "data:application/json;base64,",
                getContractSVG()
            ));

        string memory description = "Vessel description";

        bytes memory json = abi.encodePacked(
            '{',
                '"name":"The Vessel",',
                '"description":"', description, '",',
                '"image":"', image, '",',
                '"external_link":"https://www.thevessel.fun",'
            '}'
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(json)
            )
        );
    }

    function getEmptyImage() public view returns (string memory) {
        string memory name = "test.jpg";
        string memory img = fileStore.getFile(name).read();
        return img;
    }

    function getContractSVG() public pure returns (string memory) {
        return Base64.encode(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" ',
                'viewBox="0 0 400 400"><rect width="400" height="400" fill="#00000',
                '0"/><polygon fill="#ffffff"points="198,68110,238155,325198,299"/>',
                '<polygon fill="#ffffff"points="205,68293,238248,325205,299"/></svg>'
            )
        );
    }

    function setTokenContract (address _a) public onlyOwner {
        token = IVesselToken(_a);
    }
    
    function setRelicsContract (address _a) public onlyOwner {
        relics = IRelics(_a);
    }

    function render(bytes memory data, uint8 mode, uint totalSize) internal pure returns (string memory) {

        (uint256 cols, uint256 rows) = _grid(totalSize);

        bytes memory head = _svgHead();
        bytes memory tail = _svgTail();

        bytes memory out = _alloc(head.length, tail.length, totalSize);

        uint256 p = _writeHead(out, head);
        p = _writePixels(out, p, data, cols, rows, mode, totalSize);
        p = _writeTail(out, p, tail);

        assembly { mstore(out, p) } // shrink
        return string(out);
    }

    /* ------------------------- static elements ------------------------- */

    function _grid(uint256 n) internal pure returns (uint256 cols, uint256 rows) {
        if (n == 0) return (1, 1);
        cols = _min(100, _ceilSqrt(n));
        rows = (n + cols - 1) / cols;
    }

    function _offsets(uint256 cols, uint256 rows) internal pure returns (uint256 offsetX, uint256 offsetY) {
        offsetX = (100 - cols) / 2;
        offsetY = (100 - rows) / 2;
    }

    function _svgHead() internal pure returns (bytes memory) {
        return bytes(
            "<svg xmlns='http://www.w3.org/2000/svg' width='600' height='600' viewBox='0 0 100 100' shape-rendering='crispEdges'>"
        );
    }

    function _svgTail() internal pure returns (bytes memory) {
        return bytes("</svg>");
    }

    function _alloc(uint256 headLen, uint256 tailLen, uint256 n) internal pure returns (bytes memory out) {
        // 70 is a conservative per-rect budget for your ranges (0..99, 0..255)
        out = new bytes(headLen + tailLen + n * 70);
    }

    function _writeHead(bytes memory out, bytes memory head) internal pure returns (uint256 p) {
        p = _memcpy(out, 0, head, 0, head.length);
    }

    function _writeTail(bytes memory out, uint256 p, bytes memory tail) internal pure returns (uint256) {
        return _memcpy(out, p, tail, 0, tail.length);
    }

    /* ---------------------- for-loop concatenation --------------------- */

    function _writePixels(
        bytes memory out,
        uint256 p,
        bytes memory data,
        uint256 cols,
        uint256 rows,
        uint8 mode,
        uint totalSize
    ) internal pure returns (uint256) {
        (uint256 offsetX, uint256 offsetY) = _offsets(cols, rows);

        uint256 n = data.length;
        for (uint256 i = 0; i < totalSize; ++i) {
            uint256 x = offsetX + (i % cols);
            uint256 y = offsetY + (i / cols);
            uint8 d;
            if (i < n) {
                d = uint8(data[i]);
            } else {
                d = uint8(0);
            }
            p = _appendRect(out, p, x, y, d, mode);
        }
        return p;
    }

    function _appendRect(bytes memory out, uint256 p, uint256 x, uint256 y, uint8 v, uint8 mode)
        private pure returns (uint256)
    {
        p = _writeLit(out, p, "<rect x='");
        p = _writeUint2(out, p, x);       // x 0..99
        p = _writeLit(out, p, "' y='");
        p = _writeUint2(out, p, y);       // y 0..99
        p = _writeLit(out, p, "' width='1' height='1' fill='rgb(");
        p = _writeRGB(out, p, v, mode);   // writes "r,g,b" digits
        p = _writeLit(out, p, ")'/>");
        return p;
    }

    function _writeRGB(bytes memory out, uint256 p, uint8 v, uint8 mode) private pure returns (uint256) {
        if (mode == 1) { // v,0,0
            p = _writeUint3(out, p, v); p = _writeByte(out, p, ","); p = _writeByte(out, p, "0");
            p = _writeByte(out, p, ","); p = _writeByte(out, p, "0");
            return p;
        }
        if (mode == 2) { // 0,v,0
            p = _writeByte(out, p, "0"); p = _writeByte(out, p, ","); p = _writeUint3(out, p, v);
            p = _writeByte(out, p, ","); p = _writeByte(out, p, "0");
            return p;
        }
        if (mode == 3) { // 0,0,v
            p = _writeByte(out, p, "0"); p = _writeByte(out, p, ","); p = _writeByte(out, p, "0");
            p = _writeByte(out, p, ","); p = _writeUint3(out, p, v);
            return p;
        }
        // v,v,v
        p = _writeUint3(out, p, v); p = _writeByte(out, p, ","); p = _writeUint3(out, p, v);
        p = _writeByte(out, p, ","); p = _writeUint3(out, p, v);
        return p;
    }

    function _writeLit(bytes memory out, uint256 p, string memory s) private pure returns (uint256) {
        bytes memory b = bytes(s);
        return _memcpy(out, p, b, 0, b.length);
    }

    function _writeByte(bytes memory out, uint256 p, string memory ch) private pure returns (uint256) {
        bytes memory b = bytes(ch);
        out[p] = b[0];
        return p + 1;
    }

    // write 0..99 without allocating a string
    function _writeUint2(bytes memory out, uint256 p, uint256 v) private pure returns (uint256) {
        if (v >= 10) {
            out[p++] = bytes1(uint8(48 + (v / 10)));
            out[p++] = bytes1(uint8(48 + (v % 10)));
        } else {
            out[p++] = bytes1(uint8(48 + v));
        }
        return p;
    }

    // write 0..255 without allocating a string
    function _writeUint3(bytes memory out, uint256 p, uint256 v) private pure returns (uint256) {
        if (v >= 100) {
            out[p++] = bytes1(uint8(48 + (v / 100)));
            out[p++] = bytes1(uint8(48 + ((v / 10) % 10)));
            out[p++] = bytes1(uint8(48 + (v % 10)));
        } else if (v >= 10) {
            out[p++] = bytes1(uint8(48 + (v / 10)));
            out[p++] = bytes1(uint8(48 + (v % 10)));
        } else {
            out[p++] = bytes1(uint8(48 + v));
        }
        return p;
    }

    function _memcpy(bytes memory dst, uint256 dstOff, bytes memory src, uint256 srcOff, uint256 len)
        private pure returns (uint256)
    {
        for (uint256 i = 0; i < len; ++i) {
            dst[dstOff + i] = src[srcOff + i];
        }
        return dstOff + len;
    }

    function roleToString(uint _tokenId) public view returns (string memory) {

        IVesselToken.role _r = token.craftToRole(_tokenId);
        if (_r == IVesselToken.role.navigator) return "Navigator";
        if (_r == IVesselToken.role.steward)   return "Steward";
        if (_r == IVesselToken.role.merchant)  return "Merchant";
        return "Undefined";
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // Integer sqrt (floor), then convert to ceil(sqrt(x))
    function _ceilSqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;
        uint256 s = _isqrt(x);
        return s * s == x ? s : s + 1;
    }

    // uint -> decimal string
    function _u(uint256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        uint256 len;
        uint256 t = v;
        while (t != 0) { len++; t /= 10; }
        bytes memory b = new bytes(len);
        while (v != 0) {
            len--;
            b[len] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(b);
    }

    function _isAxiom(uint _tokenId) internal pure returns (bool) {
        uint256 r = _isqrt(_tokenId);
        return r * r == _tokenId;
    }

    function _isqrt(uint256 x) internal pure returns (uint256 r) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        r = x;
        while (z < r) {
            r = z;
            z = (x / z + z) / 2;
        }
    }
    
}
