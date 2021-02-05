# apwine-protocol
The APWINE On-Chain Protocol

## Abstract
The APWINE protocol allow to trade **future yield**. Interest bearing tokens of other DeFi protocols are deposited on future contracts. 

Futures are defined by a period duration (i.e 7 days), an interest bearing token (i.e. aDAI), and a platform (i.e AAVE).

**At the begenning** of each period, every liquidty providers receives an amount of future yield tokens (FYT) proportional to the liquidity deposited. They represents the future yield that each of these tokens will generated through that period. FYT follows the ERC20 standards and can be freely exchanged and traded.

**At the expiration** of one future period, its corresponding FYT can be burned to redeem the actual underlying yield

## Main contracts
Contract name | addresses |role
------------ | ------------- | -------------
`Registry`| [0x39Bd31635217c51bF064f302E1d7e7Fb847cAfBb](https://etherscan.io/address/0x39Bd31635217c51bF064f302E1d7e7Fb847cAfBb)| hold all the valid addresses of the contracts used by the protocol
`Treasury` | [0xf7A4B132d866EEbfc0dE5b4a84DD1F0418BcfEda](https://etherscan.io/address/0xf7A4B132d866EEbfc0dE5b4a84DD1F0418BcfEda)| hold the treasury funds of the protocol
`Controller` | [0xe7D8883099836F37b8844c65961D492EcdFADDa0](https://etherscan.io/address/0xe7D8883099836F37b8844c65961D492EcdFADDa0) | handles the futures contracts. User interfaces to the futures
`GaugeController` | --- |regulate the weight of liquidity gauge and APW emission

### Futures contracts
Contract name | role
------------ | -------------
`Future` | Main contracts for future mecanisms (admin and user)
`Future Vault` | hold the treasury funds of the protocol
`Future Wallet` | hold the funds of expired futures
`Liquidity Gauge` | track the user liquidity for the future


## Deployment

1. Create a copy of `.env.example` and rename it `.env`. This file is ignored by git and will contain secrets which should always stay on your computer.
2. Fill the `.env` with api keys, account mneumonic for deployement and other parameters
3. `npm install` to install dependencies
4. `npm run covergage` for detailed coverage report
5. `npm run test` to run the tests


