# EntropyWatchdogTrap.sol

## Objective
Design and deploy a Drosera-compatible smart contract that:
- Continuously monitors entropy indicators from the Ethereum block headers,
- Implements the collect() / shouldRespond() standard trap interface,
- Detects unexpected changes in entropy inputs between blocks,
- Sends alerts through a separate on-chain signaling contract.

## Problem
Smart contracts often rely on block.timestamp and block.prevrandao for timing and randomness. Any abrupt or subtle shift in these values between consecutive blocks can signal:
- Validator manipulation or coordination,
- Randomness injection inconsistencies,
- Blockchain reorgs or timestamp skewing.

These entropy anomalies, if undetected, may lead to vulnerabilities in DAO governance, randomness-dependent dApps, or time-based DeFi mechanics.

## Solution
This trap observes the entropy fingerprint of each block (composed of timestamp and prevrandao) and computes a hash for comparison. If there's any mismatch between consecutive blocks’ entropy data, it triggers a response via a dedicated contract.

This allows the network to react promptly to entropy irregularities that could affect critical systems.

## Trap Logic

**Contract: EntropyWatchdogTrap.sol**

```solidity
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
```

## Response Contract

**Contract: SignalBeaconReceiver.sol**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SignalBeaconReceiver {
    event Signal(bytes data);

    function emitSignal(bytes calldata data) external {
        emit Signal(data);
    }
}
```


## Deployment & Integration

Deploy contracts with Foundry:

bash

```solidity
forge create src/EntropyWatchdogTrap.sol:EntropyWatchdogTrap \
  --rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --private-key 0x...

forge create src/SignalBeaconReceiver.sol:SignalBeaconReceiver \
  --rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --private-key 0x...
```

Update `drosera.toml`:


path = "out/EntropyWatchdogTrap.sol/EntropyWatchdogTrap.json"
response_contract = "0x62Dd5A86bF1053F37F8F447e9914F14Ce8F883aB"
response_function = "emitSignal"


Apply changes:

bash

```solidity
DROSERA_PRIVATE_KEY=0xYOUR_PRIVATE_KEY drosera apply
```

## How to Test
1. Deploy both the trap and the response contract to Ethereum Hoodi.
2. Configure and apply the Drosera settings.
3. Wait 1–2 blocks for entropy shift to naturally occur.
4. Observe Drosera logs or dashboard:
- A shouldRespond=true result indicates entropy drift,
- The emitSignal event should be emitted accordingly.

## Potential Improvements
- Include additional block fields like basefee, gaslimit in entropy fingerprint,
- Add configurable entropy sources via constructor or setter,
- Forward alerts to an off-chain webhook or emergency multisig responder.

## Date & Author
- Created: August 3, 2025
- Author: CBBainRE
- Telegram: @aswereno
- Discord: cbbainre
- Email: anatolijbatalko@gmail.com
