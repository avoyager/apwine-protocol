const { admin } = require('@openzeppelin/truffle-upgrades');

const team_wallet = require("./common").gnosisSafe;
const common = require("./common")

const { Controller, GaugeController, LiquidityGauge, Registry, Treasury, APWineMaths, APWineNaming, ProxyFactory, IBTFutureFactory, FutureYieldToken, APWineIBT } = common.contracts
const { admin_address,ADMIN_ROLE,DEFAULT_ADMIN_ROLE} = common;
 
module.exports = async function (deployer, network) {
   if (network == 'mainnet') {

    await registry.grantRole(ADMIN_ROLE,team_wallet);
    await registry.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await registry.renounceRole(ADMIN_ROLE,admin_address);
    await registry.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);  

    await controller.grantRole(ADMIN_ROLE,team_wallet);
    await controller.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await controller.renounceRole(ADMIN_ROLE,admin_address);
    await controller.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);  

    await gaugeController.grantRole(ADMIN_ROLE,team_wallet);
    await gaugeController.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await gaugeController.renounceRole(ADMIN_ROLE,admin_address);
    await gaugeController.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);  

    await treasury.grantRole(ADMIN_ROLE,team_wallet);
    await treasury.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await treasury.renounceRole(ADMIN_ROLE,admin_address);
    await treasury.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);

    await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, team_wallet);
    await ibtFutureFactory.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await ibtFutureFactory.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);
    await ibtFutureFactory.renounceRole(FUTURE_DEPLOYER_ROLE,admin_address);

    await aaveFuture.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await aaveFuture.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);

    await aaveFutureWallet.grantRole(ADMIN_ROLE,team_wallet);
    await aaveFutureWallet.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await aaveFutureWallet.renounceRole(ADMIN_ROLE,admin_address);
    await aaveFutureWallet.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);  

    await futureVault.grantRole(ADMIN_ROLE,team_wallet);
    await futureVault.grantRole(DEFAULT_ADMIN_ROLE,team_wallet);
    await futureVault.renounceRole(ADMIN_ROLE,admin_address);
    await futureVault.renounceRole(DEFAULT_ADMIN_ROLE,admin_address);  

    // The owner of the ProxyAdmin can upgrade our contracts
    await admin.transferProxyAdminOwnership(team_wallet);
  }
};