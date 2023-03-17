# DEX Aggregator + SDK with LayerZero Cross-Chain Communication

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

WIP

