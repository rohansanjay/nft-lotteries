# nft-lotteries • [![tests](https://github.com/rohansanjay/nft-lotteries/actions/workflows/tests.yml/badge.svg)](https://github.com/rohansanjay/nft-lotteries/actions/workflows/tests.yml)

Foundry template forked from the goated [abigger87 femplate](https://github.com/abigger87/femplate) with some customizations.

## Getting Started

```sh
mkdir project-name
cd project-name
forge init --template https://github.com/rohansanjay/nft-lotteries
git submodule update --init --recursive
make rename
yarn
```


## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
src
├─ tests
│  └─ Greeter.t — "Greeter Tests"
└─ Greeter — "A Minimal Greeter Contract"
```


## Development

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

- [femplate](https://github.com/abigger87/femplate)
- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [clones-with-immutable-args](https://github.com/wighawag/clones-with-immutable-args).
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).
- [forge-template](https://github.com/FrankieIsLost/forge-template) by [FrankieIsLost](https://github.com/FrankieIsLost).
- [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource.


## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
