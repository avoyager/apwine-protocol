const { deployProxy } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

const admin_address = process.env.PUBLIC_ADRESS;
const IBTAddress = "0xdcf0af9e59c002fa3aa091a46196b37530fd48a8";

// Core Protocol
const Controller = artifacts.require('Controller');
const GaugeController = artifacts.require('GaugeController');
const LiquidityGauge = artifacts.require('LiquidityGauge');
const Registry = artifacts.require('Registry');
const Treasury = artifacts.require('Treasury');

// Libraries
const APWineMaths = artifacts.require('APWineMaths');
const APWineNaming = artifacts.require('APWineNaming');

// Future
const IBTFutureFactory = artifacts.require('IBTFutureFactory');

// Future Platform
const AaveFuture = artifacts.require('AaveFuture');
const AaveFutureWallet = artifacts.require('AaveFutureWallet');
const FutureVault = artifacts.require('FutureVault');
const FutureYieldToken = artifacts.require('FutureYieldToken');
const APWineIBT = artifacts.require('APWineIBT');

module.exports = async function (deployer) {

  /* Libraries*/
  const apwineMaths = await deployer.deploy(APWineMaths);
  await Controller.link('APWineMaths',apwineMaths.address);
  await GaugeController.link('APWineMaths',apwineMaths.address);
  await LiquidityGauge.link('APWineMaths',apwineMaths.address);
  await Registry.link('APWineMaths',apwineMaths.address);
  await Treasury.link('APWineMaths',apwineMaths.address);
  await IBTFutureFactory.link('APWineMaths',apwineMaths.address);
  await AaveFuture.link('APWineMaths',apwineMaths.address);
  await AaveFutureWallet.link('APWineMaths',apwineMaths.address);

  const apwineNaming = await deployer.deploy(APWineNaming);
  await Controller.link('APWineNaming',apwineNaming.address);
  await AaveFuture.link('APWineNaming',apwineNaming.address);

  /* Deploy and initialize core contracts */
  const registery = await deployProxy(Registry, [admin_address], { deployer,unsafeAllowCustomTypes:true, unsafeAllowLinkedLibraries:true});
  const controller = await deployProxy(Controller, [admin_address, registery.address], { deployer,unsafeAllowCustomTypes:true ,unsafeAllowLinkedLibraries:true});
  const treasury = await deployProxy(Treasury, [admin_address], { deployer,unsafeAllowCustomTypes:true ,unsafeAllowLinkedLibraries:true});
  const gaugeController = await deployProxy(GaugeController, [admin_address, registery.address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true });

  /* Deploy main logic contracts */  
  const apwineIBTLogic = await deployer.deploy(APWineIBT);
  const fytLogic = await deployer.deploy(FutureYieldToken);
  const liquidityGaugeLogic = await deployer.deploy(LiquidityGauge);

  /* Set addresses in registery */
  await registery.setTreasury(treasury.address);
  await registery.setGaugeController(gaugeController.address);
  await registery.setController(controller.address);
  //await registery.setAPW(apw.address);

  await registery.setProxyFactory("0xb738Ae1B8ae3a41a51Dc9EA471f4d15803a33fB3"); // Set manually
  await registery.setLiquidityGaugeLogic(liquidityGaugeLogic.address);
  await registery.setAPWineIBTLogic(apwineIBTLogic.address);
  await registery.setFYTLogic(fytLogic.address);

  // const proxyFactory = await deployer.deploy(ProxyFactory);

  await APWineAaveFuture.link('APWineMaths',apwineMaths.address);
  await APWineAaveFutureWallet.link('APWineMaths',apwineMaths.address);

  const ibtFutureFactory =  await deployProxy(IBTFutureFactory,[controller.address, admin_address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true });
  await registery.addFutureFactory(ibtFutureFactory.address, "AAVE");

  /* Deploy and register future logic contracts*/
  const aaveFuture = await deployer.deploy(AaveFuture);
  const aaveFutureWallet = await deployer.deploy(AaveFutureWallet);
  const futureVault = await deployer.deploy(FutureVault);

  await registery.addFuturePlatform(ibtFutureFactory.address,"AAVE",aaveFuture.address,aaveFutureWallet.address,futureVault.address);
  await ibtFutureFactory.deployFutureWithIBT("AAVE",IBTAddress,60*60*24*7);
};