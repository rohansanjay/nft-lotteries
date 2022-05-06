# nft-lotteries • [![tests](https://github.com/rohansanjay/nft-lotteries/actions/workflows/tests.yml/badge.svg)](https://github.com/rohansanjay/nft-lotteries/actions/workflows/tests.yml)

## Introduction
NFT Lotteries are an implementation of Lottery Fractionalization discussed in [Dave White's](https://twitter.com/_Dave__White_) paper on [Martingale Shares](https://www.paradigm.xyz/2021/09/martingale-shares). The protocol allows users to place an $X bet for a Y% chance at winning an NFT. NFT owners specify the required bet amount and probability a user has of winning their NFT, taking on the risk of losing it for the gains pocketed from each bet. Gamble your NFTs, anon.

## Mechanism

1. An NFT owner deposits their NFT into the smart contract and specifies the required bet amount and percentage chance of winning their NFT. For example, Alice deposits their Milday and lists a 1 ETH bet amount for a 20% chance to win it (which implies it is worth 5 ETH).
2. Bob wants to take Alice up on these Lottery terms for the Milady and pays the 1 ETH bet amount. The 1 ETH is sent to Alice.
3. The smart contract uses random number generation to simulate the Lottery giving Bob a 20% chance of winning. If Bob wins, they get the NFT (essentially having purchased it for 1 ETH). Otherwise, Alice keeps the NFT and locks in a 1 ETH gain from Bob's bet.
4. Alice can come back and withdraw their Milady at any time as long as nobody won the Lottery while it was listed.
5. The protocol continues to list all open NFT Lotteries and allows users to bet on them.

## Blueprint
```bash
├── lib
│   ├── ds-test
│   ├── forge-std
│   └── solmate
└── src
    ├── NFTLottery.sol
    └── test
        ├── NFTLottery.t.sol
```

## To-do
- Foundry reroutes
- Tests
- Upgradable?
- Frontend design and implementation
- README updates

## Development

**Set Up**
```bash
git clone https://github.com/rohansanjay/nft-lotteries.git
cd nft-lotteries
make install
```

**Building**
```bash
make build
```

**Testing**
```bash
make test
```
## License

[AGPL-3.0-only](https://github.com/rohansanjay/nft-lotteries/blob/master/LICENSE)

## Acknowledgements

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
