// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}

contract EntropyWatchdogTrap is ITrap {
    struct CollectOutput {
        uint256 timestamp;
        uint256 prevrandao;
        uint256 maxTimestampDelta; // порог для времени
        uint256 maxRandaoDelta;   // порог для рандома
    }

    uint256 private constant DEFAULT_MAX_TIMESTAMP_DELTA = 5; // секунд
    uint256 private constant DEFAULT_MAX_RNDAO_DELTA = type(uint128).max / 2;

    function collect() external view override returns (bytes memory) {
        CollectOutput memory output = CollectOutput({
            timestamp: block.timestamp,
            prevrandao: uint256(block.prevrandao),
            maxTimestampDelta: DEFAULT_MAX_TIMESTAMP_DELTA,
            maxRandaoDelta: DEFAULT_MAX_RNDAO_DELTA
        });

        return abi.encode(output);
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, bytes("Not enough data"));
        }

        CollectOutput memory current = abi.decode(data[0], (CollectOutput));
        CollectOutput memory previous = abi.decode(data[1], (CollectOutput));

        uint256 tsDelta = current.timestamp > previous.timestamp
            ? current.timestamp - previous.timestamp
            : previous.timestamp - current.timestamp;

        uint256 randaoDelta = current.prevrandao > previous.prevrandao
            ? current.prevrandao - previous.prevrandao
            : previous.prevrandao - current.prevrandao;

        if (tsDelta > previous.maxTimestampDelta || randaoDelta > previous.maxRandaoDelta) {
            return (
                true,
                abi.encode(
                    "Significant entropy drift",
                    tsDelta,
                    randaoDelta
                )
            );
        }

        return (false, bytes("No significant drift"));
    }
}
