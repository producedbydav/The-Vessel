// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMachine {
    function craftToPayload(uint _tokenId) external view returns (bytes memory);
    function name() external returns (string memory);
}

contract Machine_rand is IMachine {

    string public name = "Entropy";
    
    function craftToPayload(uint _tokenId) external view returns (bytes memory) {
        // If you want “less predictable” while still deterministic-per-block:
        // uint256 seed = uint256(keccak256(abi.encodePacked(_tokenId, block.number, block.prevrandao)));
        // If you truly want pure determinism independent of chain state, just use _tokenId.
        uint256 seed = uint256(keccak256(abi.encodePacked(_tokenId, block.number)));
        return _getRandomPayload(seed, _tokenId);
    }

    function _getRandomPayload(uint256 seed, uint256 n) internal pure returns (bytes memory out) {
        if (n > 10000) n = 10000;

        out = new bytes(n);

        uint256 fullChunks = n / 32;
        uint256 rem = n % 32;

        assembly {
            // Pointer to first byte of out data
            let p := add(out, 0x20)

            // Write full 32-byte chunks
            for { let i := 0 } lt(i, fullChunks) { i := add(i, 1) } {
                // keccak256(seed, i)
                // We'll hash a 64-byte buffer [seed || i] in scratch space.
                mstore(0x00, seed)
                mstore(0x20, i)
                let h := keccak256(0x00, 0x40)

                // Store bytes32 directly into out
                mstore(add(p, mul(i, 0x20)), h)
            }

            // Handle remainder
            if gt(rem, 0) {
                mstore(0x00, seed)
                mstore(0x20, fullChunks)
                let h2 := keccak256(0x00, 0x40)

                // Store the last 32 bytes, but avoid overwriting beyond length.
                // We write to the last 32-byte slot and rely on masking.
                let lastPtr := add(p, mul(fullChunks, 0x20))

                // Build a mask that preserves the bytes beyond rem.
                // mask keeps the *low* (32-rem) bytes from existing memory.
                // We want to write the *first rem bytes* (high bytes) of h2.
                let mask := sub(shl(mul(8, sub(0x20, rem)), 1), 1) // (1<<(8*(32-rem)))-1

                // existing & mask  OR  h2 & ~mask
                let existing := mload(lastPtr)
                let blended := or(and(existing, mask), and(h2, not(mask)))
                mstore(lastPtr, blended)
            }
        }
    }
}
