# splits-liquid

## What

Liquid splits are splits where ownership is represented by NFTs (e.g. 721s or 1155s).

## Why

This design gives ~control of the split to the recipients themselves, allowing the transfer or sale of ownership.

## Notes

1. `LiquidSplitFactory.sol` powers liquid splits offered at app.0xsplits.xyz
2. `LiquidSplit.sol` can be inherited in any NFT project & `LS1155.sol` is an example of how to integrate it
