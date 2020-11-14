const { deployProxy } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

const admin_address = process.env.PUBLIC_ADRESS;

const APWineController = artifacts.require('APWineController');
const ProxyFactory = artifacts.require('ProxyFactory');
const APWineProxy = artifacts.require('APWineProxy');
const FutureYieldToken = artifacts.require('FutureYieldToken');
const APWineAave = artifacts.require('APWineAave');




module.exports = async function (deployer) {

  const controller = await deployProxy(APWineController, [admin_address], { deployer,unsafeAllowCustomTypes:true });

  const proxyFactory = await deployer.deploy(ProxyFactory);

  console.log("Set APWineProxyFactoryAddress");
  await controller.setAPWineProxyFactoryAddress(proxyFactory.address);

  const apwineProxy = await deployer.deploy(APWineProxy);

  console.log("Set APWineProxyLogic");
  await controller.setAPWineProxyLogic(apwineProxy.address);

  const fyt = await deployer.deploy(FutureYieldToken);

  console.log("Set FutureYieldTokenLogic");
  await controller.setFutureYieldTokenLogic(fyt.address);

  console.log("Set Treasury address");
  await controller.setTreasuryAddress(controller.address);

  const aavefuture = await deployProxy(APWineAave, [controller.address,proxyFactory.address,"0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a","Weekly Aave Dai Future",7,admin_address], { deployer,unsafeAllowCustomTypes:true });
  
  console.log("Register future in controller");
  await controller.addFuture(aavefuture.address);

  console.log("Grant future role for admin address");
  await aavefuture.grantRole("0x4873ef423ebf9f9a54f12880e8328ce2fa6922f8fd56c195a45c5a0ae9a42a14",admin_address);
  await aavefuture.grantRole("0xa740542f7a58151bbede3b475841aea632d450804b6b85d24d49aa8a519ef4bc",admin_address);

  console.log('APWineController: ', controller.address);
  console.log('ProxyFactory: ', proxyFactory.address);
  console.log('APWineProxyLogic: ', apwineProxy.address);
  console.log('APWinePrFutureYieldTokenLogic: ', fyt.address);
  console.log('APWineAave: ', aavefuture.address);

  console.log('The admin adress used is:',admin_address);

};