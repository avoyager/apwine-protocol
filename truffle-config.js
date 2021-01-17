require('dotenv').config();

const HDWalletProvider = require('truffle-hdwallet-provider');
const mnemonic = process.env.MNEMONIC;
const infuraProjectId = process.env.INFURA_PROJECT_ID;


module.exports = {
  networks: {
    development: {
      protocol: 'http',
      host: 'localhost',
      port: 8545,
      gas: 5000000,
      gasPrice: 5e9,
      networkId: '*',
    },
    kovan: {
      provider: function() { 
          return new HDWalletProvider(mnemonic, "https://kovan.infura.io/v3/" + infuraProjectId,0,4);
      },
      network_id: 42,
      gas: 12450000,
      gasPrice: 25000000000,
    },
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, "https://ropsten.infura.io/v3/" + infuraProjectId),
      networkId: 3
    },
    mainnet: {
      provider: () => new HDWalletProvider(mnemonic, "https://mainnet.infura.io/v3/" + infuraProjectId),
      networkId: 1
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : { excludeContracts: ['Migrations'] }
  },

  // Configure your compilers
  compilers: {
    solc: {
      version:"0.7.6+commit.7338295f",
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 1
       },
      }
    }
  },
  plugins: [
    'truffle-contract-size',
    'solidity-coverage'
  ]
};
