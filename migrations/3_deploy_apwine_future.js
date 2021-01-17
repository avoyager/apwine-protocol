const { deployProxy } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

const common = require("./common")
const { Controller, GaugeController, LiquidityGauge, Registry, Treasury, APWineMaths, APWineNaming, ProxyFactory, IBTFutureFactory, FutureYieldToken, APWineIBT } = common.contracts
const { admin_address, ADAI_Address,EPOCH_LENGTH,INITIAL_INFLATION_RATE, DAY} = common;

module.exports = async function (deployer) {

    const controller = await Controller.deployed();
    const registry = await Registry.deployed();

    const ibtFutureFactory =  await deployProxy(IBTFutureFactory,[controller.address, admin_address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true });
    await registry.addFutureFactory(ibtFutureFactory.address, "AAVE");

    /* Deploy and register future logic contracts*/
    const aaveFuture = await deployer.deploy(AaveFuture);
    const aaveFutureWallet = await deployer.deploy(AaveFutureWallet);
    const futureVault = await deployer.deploy(FutureVault);

    await registry.addFuturePlatform(ibtFutureFactory.address,"AAVE",aaveFuture.address,aaveFutureWallet.address,futureVault.address);
    await ibtFutureFactory.deployFutureWithIBT("AAVE",IBTAddress,DAY*7);

}