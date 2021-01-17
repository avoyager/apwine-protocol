const { admin } = require('@openzeppelin/truffle-upgrades');

const team_wallet = require("./common").gnosisSafe;
 
module.exports = async function (deployer, network) {
   if (network == 'mainnet') {
    // The owner of the ProxyAdmin can upgrade our contracts
    await admin.transferProxyAdminOwnership(team_wallet);
  }
};