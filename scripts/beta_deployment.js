
require('dotenv').config();

const { ethers, upgrades } = require("hardhat");

const team_wal = require("./common").gnosisSafe;
const common = require("./common")
const {ADMIN_ROLE,DEFAULT_ADMIN_ROLE, FUTURE_DEPLOYER_ROLE,INITIAL_INFLATION_RATE,INIT_SUPPLY,DAY,EPOCH_LENGTH,ADAI_ADDRESS,AWETH_ADDRESS} = common;

async function main() {

    const [deployer] = await ethers.getSigners();
    console.log("Deploying the contracts with the account:", await deployer.getAddress());
    console.log("Account balance:", (await deployer.getBalance()).toString());

      /* Load artifacts */
      APWineMaths = await ethers.getContractFactory('APWineMaths');
      APWineNaming = await ethers.getContractFactory('APWineNaming');
      ProxyFactory = await ethers.getContractFactory('ProxyFactory');
      Registry = await ethers.getContractFactory('Registry');
      Controller = await ethers.getContractFactory('Controller');
      Treasury= await ethers.getContractFactory('Treasury');
      APWineIBT = await ethers.getContractFactory('APWineIBT');
      FutureYieldToken = await ethers.getContractFactory('FutureYieldToken');
      IBTFutureFactory = await ethers.getContractFactory('IBTFutureFactory');

      AaveFuture = await ethers.getContractFactory('AaveFuture');
      AaveFutureWallet = await ethers.getContractFactory('AaveFutureWallet');
      FutureVault = await ethers.getContractFactory('FutureVault');

      yTokenFuture = await ethers.getContractFactory('yTokenFuture');
      yTokenFutureWallet = await ethers.getContractFactory('yTokenFutureWallet');
      yearnFutureVault = await ethers.getContractFactory('FutureVault');


      /* Libraries*/
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
  
      // /* Deploy and initialize core contracts */
      const registry = await upgrades.deployProxy(Registry, [deployer.address], {unsafeAllowCustomTypes:true});
      await registry.deployed();
      console.log("Registry deployed to:", registry.address);
      const controller = await upgrades.deployProxy(Controller, [deployer.address, registry.address], {unsafeAllowCustomTypes:true});
      await controller.deployed();
      console.log("Controller deployed to:", controller.address);
      const treasury = await upgrades.deployProxy(Treasury, [deployer.address], {unsafeAllowCustomTypes:true});
      await treasury.deployed();
      console.log("Treasury deployed to:", treasury.address);

  
      // /* Set addresses in registry */
      console.log("Setting addresses in registry...");
      let tx = await registry.setTreasury(treasury.address);
      await tx.wait()

       tx = await registry.setController(controller.address);
      await tx.wait()

      //await registry.setAPW(apw.address);
  
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



      // // /* Deploy and register future logic contracts*/
      const aaveFuture = await AaveFuture.deploy();
      await aaveFuture.deployed();

      console.log("AaveFuture deployed to:", aaveFuture.address);

      const aaveFutureWallet = await AaveFutureWallet.deploy();
      await aaveFutureWallet.deployed();

      console.log("AaveFutureWallet deployed to:", aaveFutureWallet.address);
      
      const futureVault = await FutureVault.deploy();
      await futureVault.deployed();

      console.log("FutureVault deployed to:", futureVault.address);

      console.log("Deploying new future..");
      const ibtFutureFactory =  await upgrades.deployProxy(IBTFutureFactory,[controller.address, deployer.address], {unsafeAllowCustomTypes:true});
      await ibtFutureFactory.deployed();

      console.log("IBTFutureFactory deployed to:", ibtFutureFactory.address);
       tx = await registry.addFutureFactory(ibtFutureFactory.address, "AAVE");
       await tx.wait()
       tx = await registry.addFuturePlatform(ibtFutureFactory.address, "AAVE", aaveFuture.address,aaveFutureWallet.address,futureVault.address);
       await tx.wait()

       tx = await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, deployer.address);
      await tx.wait()

       tx = await ibtFutureFactory.deployFutureWithIBT("AAVE",ADAI_ADDRESS,7);
      await tx.wait()


      /* Role modification to transfer owner right to multisig */
      console.log("Deployement finished, revoking roles of deployer...");
      // console.log("Registry (1/8)");
      // await registry.grantRole(ADMIN_ROLE,team_wal);
      // await registry.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await registry.renounceRole(ADMIN_ROLE,deployer.address);
      // await registry.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);  
  
      // console.log("Controller (2/8)");
      // await controller.grantRole(ADMIN_ROLE,team_wal);
      // await controller.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await controller.renounceRole(ADMIN_ROLE,deployer.address);
      // await controller.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);  
  
      // console.log("Gauge controller (3/8)");
      // await gaugeController.grantRole(ADMIN_ROLE,team_wal);
      // await gaugeController.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await gaugeController.renounceRole(ADMIN_ROLE,deployer.address);
      // await gaugeController.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);  
  
      // console.log("Treasury (4/8)");
      // await treasury.grantRole(ADMIN_ROLE,team_wal);
      // await treasury.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await treasury.renounceRole(ADMIN_ROLE,deployer.address);
      // await treasury.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);
  
      // console.log("IBT Futures factory (5/8)");
      // await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, team_wal);
      // await ibtFutureFactory.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await ibtFutureFactory.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);
      // await ibtFutureFactory.renounceRole(FUTURE_DEPLOYER_ROLE,deployer.address);
  
      // console.log("AAVE Future (6/8)");
      // await aaveFuture.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await aaveFuture.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);
  
      // console.log("AAVE Future Wal (7/8)");
      // await aaveFutureWallet.grantRole(ADMIN_ROLE,team_wal);
      // await aaveFutureWallet.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await aaveFutureWallet.renounceRole(ADMIN_ROLE,deployer.address);
      // await aaveFutureWallet.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);  
  
      // console.log("AAVE Future Vault (8/8)");
      // await futureVault.grantRole(ADMIN_ROLE,team_wal);
      // await futureVault.grantRole(DEFAULT_ADMIN_ROLE,team_wal);
      // await futureVault.renounceRole(ADMIN_ROLE,deployer.address);
      // await futureVault.renounceRole(DEFAULT_ADMIN_ROLE,deployer.address);  

      // console.log("Transfering proxy adming ownership to gnosis safe address...");
      // await upgrades.admin.transferProxyAdminOwnership(team_wal);
      console.log('DONE');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
