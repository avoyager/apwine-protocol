
require('dotenv').config();

const { ethers, upgrades } = require("hardhat");

const team_wal = require("./common").gnosisSafe;
const common = require("./common")
const { ADMIN_ROLE, DEFAULT_ADMIN_ROLE, FUTURE_DEPLOYER_ROLE, INITIAL_INFLATION_RATE, INIT_SUPPLY, DAY, EPOCH_LENGTH, AWETH_ADDRESS } = common;
const { AUSDC_ADDRESS, ADAI_ADDRESS, YUSD_ADDRESS, YDAI_ADDRESS,YVEURSCRV } = common.mainnet;

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying the contracts with the account:", await deployer.getAddress());
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const STARTING_DELAY = 2 * 60;
  const BETA_STARTING_DATE = 1613386800; // 5th Feb 2021 6PM CET

  /* Load artifacts */
  APWineMaths = await ethers.getContractFactory('APWineMaths');
  APWineNaming = await ethers.getContractFactory('APWineNaming');
  ProxyFactory = await ethers.getContractFactory('ProxyFactory');
  Registry = await ethers.getContractFactory('Registry');
  Controller = await ethers.getContractFactory('Controller');
  Treasury = await ethers.getContractFactory('Treasury');
  APWineIBT = await ethers.getContractFactory('APWineIBT');
  FutureYieldToken = await ethers.getContractFactory('FutureYieldToken');
  IBTFutureFactory = await ethers.getContractFactory('IBTFutureFactory');

  AaveFuture = await ethers.getContractFactory('AaveFuture');
  AaveFutureWallet = await ethers.getContractFactory('AaveFutureWallet');

  yTokenFuture = await ethers.getContractFactory('yTokenFuture');
  yTokenFutureWallet = await ethers.getContractFactory('yTokenFutureWallet');

  FutureVault = await ethers.getContractFactory('FutureVault');


  /* Libraries*/
  console.log("\n###  Deploying core contract");
  const apwineMaths = await APWineMaths.deploy();
  await apwineMaths.deployed();
  console.log("APWineMaths deployed to:", apwineMaths.address);
  const apwineNaming = await APWineNaming.deploy();
  await apwineNaming.deployed();
  console.log("APWineNaming deployed to:", apwineNaming.address);

  /* Deploy main logic contracts */
  const apwineIBTLogic = await APWineIBT.deploy();
  await apwineIBTLogic.deployed();
  console.log("APWineIBT logic deployed to:", apwineIBTLogic.address);
  const fytLogic = await FutureYieldToken.deploy();
  await fytLogic.deployed();
  console.log("FutureYieldToken logic deployed to:", fytLogic.address);
  const proxyFactory = await ProxyFactory.deploy();
  await proxyFactory.deployed();
  console.log("ProxyFactory deployed to:", proxyFactory.address);

  /* Deploy and initialize core contracts */
  const registry = await upgrades.deployProxy(Registry, [deployer.address], { unsafeAllowCustomTypes: true });
  await registry.deployed();
  console.log("Registry deployed to:", registry.address);
  const controller = await upgrades.deployProxy(Controller, [deployer.address, registry.address], { unsafeAllowCustomTypes: true });
  await controller.deployed();
  console.log("Controller deployed to:", controller.address);
  const treasury = await upgrades.deployProxy(Treasury, [deployer.address], { unsafeAllowCustomTypes: true });
  await treasury.deployed();
  console.log("Treasury deployed to:", treasury.address);

  console.log("Transfering treasury role to final address");
  let tx = await treasury.grantRole(ADMIN_ROLE, team_wal);
  await tx.wait()
  tx = await treasury.grantRole(DEFAULT_ADMIN_ROLE, team_wal);
  await tx.wait()
  tx = await treasury.renounceRole(ADMIN_ROLE, deployer.address);
  await tx.wait()
  tx = await treasury.renounceRole(DEFAULT_ADMIN_ROLE, deployer.address);
  await tx.wait()


  /* Set addresses in registry */
  console.log("\n###  Setting addresses in registry... \n");
  tx = await registry.setTreasury(treasury.address);
  await tx.wait()
  tx = await registry.setController(controller.address);
  await tx.wait()
  //tx = await registry.setAPW(apw.address);
  //await tx.wait()
  tx = await registry.setProxyFactory(proxyFactory.address);
  await tx.wait()
  tx = await registry.setAPWineIBTLogic(apwineIBTLogic.address);
  await tx.wait()
  tx = await registry.setFYTLogic(fytLogic.address);
  await tx.wait()
  tx = await registry.setMathsUtils(apwineMaths.address)
  await tx.wait()
  tx = await registry.setNamingUtils(apwineNaming.address)
  await tx.wait()

  console.log("Setting controller parameters")
  tx = await controller.setPeriodStartingDelay(STARTING_DELAY)
  await tx.wait()
  tx = await controller.setNextPeriodSwitchTimestamp(7 * DAY, BETA_STARTING_DATE)
  await tx.wait()

  console.log("Transfering controller role to final address");
  tx = await controller.grantRole(ADMIN_ROLE, team_wal);
  await tx.wait();
  tx = await controller.grantRole(DEFAULT_ADMIN_ROLE, team_wal);
  await tx.wait();
  tx = await controller.renounceRole(ADMIN_ROLE, deployer.address);
  await tx.wait();
  tx = await controller.renounceRole(DEFAULT_ADMIN_ROLE, deployer.address);
  await tx.wait();

  console.log("\n### Deploying new futures..");
  const ibtFutureFactory = await upgrades.deployProxy(IBTFutureFactory, [controller.address, deployer.address], { unsafeAllowCustomTypes: true });
  await ibtFutureFactory.deployed();
  console.log("IBTFutureFactory deployed to:", ibtFutureFactory.address);

  tx = await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, deployer.address);
  await tx.wait()

  const futureVault = await FutureVault.deploy();
  await futureVault.deployed();
  console.log("FutureVault logic deployed to:", futureVault.address);

  /* Deploy and register future logic contracts*/
  console.log("\n###  AAVE")
  console.log("## Deploy AAVE Logic")
  const aaveFuture = await AaveFuture.deploy();
  await aaveFuture.deployed();
  console.log("AaveFuture deployed to:", aaveFuture.address);
  const aaveFutureWallet = await AaveFutureWallet.deploy();
  await aaveFutureWallet.deployed();
  console.log("AaveFutureWallet deployed to:", aaveFutureWallet.address);

  tx = await registry.addFutureFactory(ibtFutureFactory.address, "AAVE");
  await tx.wait()
  tx = await registry.addFuturePlatform(ibtFutureFactory.address, "AAVE", aaveFuture.address, aaveFutureWallet.address, futureVault.address);
  await tx.wait()

  // AAVE FUTURES
  console.log("Deploy AAVE DAI WEEKLY FUTURE")
  tx = await ibtFutureFactory.deployFutureWithIBT("AAVE", ADAI_ADDRESS, 30);
  await tx.wait()
  console.log("Deploy AAVE USDC WEEKLY FUTURE")
  tx = await ibtFutureFactory.deployFutureWithIBT("AAVE", AUSDC_ADDRESS, 30);
  await tx.wait()


  /* Deploy and register future logic contracts*/
  console.log("\n###  YEARN")
  console.log("Deploy YEARN Logic")
  const yearnFuture = await yTokenFuture.deploy();
  await yearnFuture.deployed();
  console.log("yTokenFuture deployed to:", yearnFuture.address);
  const yearnFutureWallet = await yTokenFutureWallet.deploy();
  await yearnFutureWallet.deployed();
  console.log("yearnFutureWallet deployed to:", yearnFutureWallet.address);

  tx = await registry.addFutureFactory(ibtFutureFactory.address, "YTOKEN");
  await tx.wait()
  tx = await registry.addFuturePlatform(ibtFutureFactory.address, "YTOKEN", yearnFuture.address, yearnFutureWallet.address, futureVault.address);
  await tx.wait()

  // YEARN FUTURES
  console.log("Deploy YUSD WEEKLY FUTURE")
  tx = await ibtFutureFactory.deployFutureWithIBT("YTOKEN", YUSD_ADDRESS, 30);
  await tx.wait()
  console.log("Deploy YDAI WEEKLY FUTURE")
  tx = await ibtFutureFactory.deployFutureWithIBT("YTOKEN", YVEURSCRV, 30);
  await tx.wait()

  console.log("IBT Future factory treasury role to final address");
  tx = await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, team_wal);
  await tx.wait()
  tx = await ibtFutureFactory.grantRole(DEFAULT_ADMIN_ROLE, team_wal);
  await tx.wait()
  tx = await ibtFutureFactory.renounceRole(DEFAULT_ADMIN_ROLE, deployer.address);
  await tx.wait()
  tx = await ibtFutureFactory.renounceRole(FUTURE_DEPLOYER_ROLE, deployer.address);
  await tx.wait()

  console.log("\nTransfering registry role to final address");
  tx = await registry.grantRole(ADMIN_ROLE, team_wal);
  await tx.wait()
  tx = await registry.grantRole(DEFAULT_ADMIN_ROLE, team_wal);
  await tx.wait()
  tx = await registry.renounceRole(ADMIN_ROLE, deployer.address);
  await tx.wait()
  tx = await registry.renounceRole(DEFAULT_ADMIN_ROLE, deployer.address);
  await tx.wait()

  console.log("Transfering proxy adming ownership to gnosis safe address...");
  await upgrades.admin.transferProxyAdminOwnership(team_wal);
  console.log('DONE');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
