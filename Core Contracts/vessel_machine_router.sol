// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

interface IMachine {
    function craftToPayload(uint256 _tokenId) external view returns (bytes memory);
    function name() external view returns (string memory);
}

interface IVesselToken {
    function claimedCount() external view returns (uint256);
}

/**
 * @title MachineRouter
 * @notice Forwards to one of many registered machines, rotating based on Vessel mint progress.
 *
 * Rotation rule:
 * - blocksPerStep = 10_000 - totalMinted()
 * - once totalMinted() >= 10_000, blocksPerStep = 1
 *
 * So:
 * - 0 minted     => 10000 blocks per step
 * - 5000 minted  => 5000 blocks per step
 * - 9999 minted  => 1 block per step
 * - 10000 minted => 1 block per step
 */
contract MachineRouter is IMachine, Ownable {
    error NoMachinesRegistered();
    error InvalidMachine();
    error IndexOutOfRange();

    uint256 public constant MAX_MINT = 10_000;

    IVesselToken public vessel;

    uint256 public machineCount;

    mapping(uint256 => IMachine) public machines;

    constructor() Ownable(msg.sender) {
        vessel = IVesselToken(0xECb92Cc7112b80A2234936315BbB493fb48d1463);
    }

    function name() external view returns (string memory) {
        if (machineCount == 0) {
            return "Machine Router";
        }

        return string(
            abi.encodePacked(
                "Machine Router: ",
                activeMachine().name()
            )
        );
    }

    function setVessel(address _vessel) external onlyOwner {
        vessel = IVesselToken(_vessel);
    }

    function addMachine(address _machine) external onlyOwner {
        if (_machine == address(0)) revert InvalidMachine();

        machines[machineCount] = IMachine(_machine);
        unchecked {
            machineCount++;
        }
    }

    function setMachine(uint256 _index, address _machine) external onlyOwner {
        if (_index >= machineCount) revert IndexOutOfRange();
        if (_machine == address(0)) revert InvalidMachine();

        machines[_index] = IMachine(_machine);
    }

    function blocksPerStep() public view returns (uint256) {
        uint256 minted = vessel.claimedCount();
        if (minted >= MAX_MINT) return 1;
        return MAX_MINT - minted;
    }

    function activeMachineIndex() public view returns (uint256) {
        if (machineCount == 0) revert NoMachinesRegistered();

        uint256 step = blocksPerStep();
        return (block.number / step) % machineCount;
    }

    function activeMachine() public view returns (IMachine) {
        return machines[activeMachineIndex()];
    }

    function generate(uint256 _tokenId) public view returns (bytes memory) {
        return activeMachine().craftToPayload(_tokenId);
    }

    function craftToPayload(uint256 _tokenId) external view returns (bytes memory) {
        bytes memory out = generate(_tokenId);
        return _cap(out, _tokenId);
    }

    function _cap(bytes memory _data, uint256 _capLen) internal pure returns (bytes memory) {
        if (_data.length <= _capLen) return _data;

        bytes memory clipped = new bytes(_capLen);
        for (uint256 i = 0; i < _capLen; i++) {
            clipped[i] = _data[i];
        }
        return clipped;
    }
}
