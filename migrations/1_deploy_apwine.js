const { deployProxy } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

const admin_address = process.env.PUBLIC_ADRESS;

const Controller = artifacts.require('Controller');
const APWineMaths = artifacts.require('APWineMaths');
const ProxyFactory = artifacts.require('ProxyFactory');
const FutureYieldToken = artifacts.require('FutureYieldToken');
const APWineIBT = artifacts.require('APWineIBT');
const APWineAaveVineyard = artifacts.require('APWineAaveVineyard');
const APWineAaveCellar = artifacts.require('APWineAaveCellar');
const FutureVault = artifacts.require('FutureVault');


module.exports = async function (deployer) {

  const controller = await deployProxy(Controller, [admin_address], { deployer,unsafeAllowCustomTypes:true });
  const proxyFactory = await deployer.deploy(ProxyFactory);
  const apwineMaths = await deployer.deploy(APWineMaths);
  await APWineAaveVineyard.link('APWineMaths',apwineMaths.address);
  await APWineAaveCellar.link('APWineMaths',apwineMaths.address);


  console.log("Set APWineProxyFactoryAddress");
  await controller.setAPWineProxyFactoryAddress(proxyFactory.address);

  const apwineIBT = await deployer.deploy(APWineIBT);

  console.log("Set APWineIBTLogic");
  await controller.setAPWineIBTLogic(apwineIBT.address);

  const fyt = await deployer.deploy(FutureYieldToken);

  console.log("Set FutureYieldTokenLogic");
  await controller.setFutureYieldTokenLogic(fyt.address);

  console.log("Set Treasury address");
  await controller.setTreasuryAddress(controller.address);

  const aaveVineyard = await deployProxy(APWineAaveVineyard, [controller.address,"0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a",7,"Weekly Aave Dai Future","WADAI",admin_address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true});
  const aaveCellar = await deployProxy(APWineAaveCellar, [aaveVineyard.address,admin_address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true});
  const aaveFutureWallet = await deployProxy(FutureVault, [aaveVineyard.address], { deployer,unsafeAllowCustomTypes:true,unsafeAllowLinkedLibraries:true});

  console.log("Register vineyard in controller");
  await controller.addVineyard(aaveVineyard.address);

  // Requires the sender to be the admin_address set
  const in3Days = Math.floor(Date.now() / 1000) + 3*24*60*60;
  await aaveVineyard.setNextPeriodTimestamp(in3Days);
  console.log("Next period set in 3 days");

  console.log('Controller: ', controller.address);
  console.log('ProxyFactory: ', proxyFactory.address);
  console.log('FutureYieldToken: ', fyt.address);
  console.log('APWineIBT: ', apwineIBT.address);
  console.log('APWineAaveVineyard: ', aaveVineyard.address);
  console.log('APWineAaveCellar: ', aaveCellar.address);
  console.log('FutureVault: ', aaveFutureWallet.address);
  console.log('The admin adress used is:',admin_address);

};