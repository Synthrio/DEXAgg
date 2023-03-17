
# DEX Aggregator based on LayerZero Cross-Chain Communication

This project is a DEX aggregator and SDK that leverages LayerZero's cross-chain communication capabilities to enable swapping of tokens across multiple chains using preferred synth routes.

## Overview

The core swap process consists of three components:

1. Swap into the synthetic asset (syAsset) on the source chain
2. Cross-chain or same-chain SYNTH SWAP
3. Swap out of the synthetic asset on the destination chain

### Components

The project consists of two main smart contracts:

1. `SourceChainUA.sol` - Handles the swap on the source chain, converting the input token into its synthetic counterpart (syAsset).
2. `DestinationChainUA.sol` - Handles the swap on the destination chain, converting the synthetic asset back into the desired token.

Both contracts inherit from `NonblockingLzApp`, which facilitates cross-chain communication using LayerZero.

### Cross-chain communication

The cross-chain communication is handled using LayerZero's `_lzSend` and `_nonblockingLzReceive` functions, enabling the swap to be executed across different blockchains seamlessly.

## Setup

1. Install dependencies:

```
npm install
```

2. Compile the smart contracts:

```
npx hardhat compile
```

3. Run tests (if any):

```
npx hardhat test
```

## Deployment

1. Modify the `hardhat.config.js` file with the appropriate network configurations and API keys.

2. Deploy the contracts using Hardhat:

```
npx hardhat run --network &lt;network_name&gt; scripts/deploy.js
```

## Usage

To interact with the deployed contracts, you can use any Ethereum-compatible library (e.g., Web3.js or Ethers.js).

1. Connect to the appropriate network using a provider (e.g., MetaMask or Infura).

2. Create a contract instance for both `SourceChainUA` and `DestinationChainUA` using their respective ABI and deployed addresses.

3. Call the `swapToSyAsset` function in the `SourceChainUA` contract to initiate the swap on the source chain.

4. Call the `crossChainSwap` function in the `SourceChainUA` contract to send cross-chain messages.

5. The `_nonblockingLzReceive` function in the `DestinationChainUA` contract will automatically handle the received message, and the contract will initiate the swap on the destination chain.

6. Call the `swapSyAssetToBaseAsset` function in the `DestinationChainUA` contract to complete the swap process on the destination chain.

## License

This project is licensed under the MIT License.
