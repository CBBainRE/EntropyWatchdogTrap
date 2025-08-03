// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}

/// @title EntropyWatchdogTrap — triggers on entropy drift between blocks
contract EntropyWatchdogTrap is ITrap {
    function collect() external view override returns (bytes memory) {
        return abi.encode(block.timestamp, block.prevrandao);
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, bytes("Not enough data"));
        }

        bytes32 hashCurrent = keccak256(data[0]);
        bytes32 hashPrevious = keccak256(data[1]);

        if (hashCurrent != hashPrevious) {
            return (true, abi.encode("Entropy drift detected"));
        }

        return (false, bytes("No drift"));
    }
}
