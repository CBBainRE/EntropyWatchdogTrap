// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SignalBeaconReceiver {
    event Signal(bytes data);

    function emitSignal(bytes calldata data) external {
        emit Signal(data);
    }
}
