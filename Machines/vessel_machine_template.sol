// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMachine {
    function craftToPayload(uint256 tokenId)
        external
        view
        returns (bytes memory);

    function name()
        external
        view
        returns (string memory);
}

interface IVessel {
    function craftToPayload(uint256 tokenId)
        external
        view
        returns (bytes memory);

    // Add any other read functions your Machine needs.
    // Example:
    // function craftToRole(uint256 tokenId) external view returns (uint8);
    // function craftToLocked(uint256 tokenId) external view returns (bool);
}

contract GenericMachine is IMachine {
    IVessel public immutable vessel;
    string public constant MACHINE_NAME = "Generic Machine";

    constructor(address vesselAddress) {
        vessel = IVessel(vesselAddress);
    }

    function name() external pure returns (string memory) {
        return MACHINE_NAME;
    }

    function craftToPayload(uint256 tokenId)
        external
        view
        returns (bytes memory)
    {
        // Insert custom logic here.
        // You might generate entirely new data,
        // or read and reinterpret onchain material.
        // return _transform(basePayload);

        return bytes("");
    }
}
