
require('dotenv').config();

const { ethers, upgrades } = require("hardhat");

const team_wallet = require("./common").gnosisSafe;
const common = require("./common")
const {ADMIN_ROLE,DEFAULT_ADMIN_ROLE, FUTURE_DEPLOYER_ROLE,INITIAL_INFLATION_RATE,INIT_SUPPLY,DAY,EPOCH_LENGTH,ADAI_ADDRESS,AWETH_ADDRESS} = common;

async function main() {

    const [deployer] = await ethers.getSigners();
    console.log("Deploying the contracts with the account:", await deployer.getAddress());
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const REGISTRY ="";
    const IBT_FUTURE_FACTORY="";

    /* Load artifacts */
    Registry = await ethers.getContractFactory('Registry');
    IBTFutureFactory = await ethers.getContractFactory('IBTFutureFactory');

    AaveFuture = await ethers.getContractFactory('AaveFuture');
    AaveFutureWallet = await ethers.getContractFactory('AaveFutureWallet');
    FutureVault = await ethers.getContractFactory('FutureVault');

    /* Deploy and register future logic contracts*/
    const aaveFuture = await AaveFuture.deploy();
    await aaveFuture.deployed()
    console.log("AaveFuture deployed to:", aaveFuture.address);
    const aaveFutureWallet = await AaveFutureWallet.deploy();
    await aaveFutureWallet.deployed()

    console.log("AaveFutureWallet deployed to:", aaveFutureWallet.address);
    const futureVault = await FutureVault.deploy();
    await futureVault.deployed()
    console.log("FutureVault deployed to:", futureVault.address);


    const registry = await Registry.attach(REGISTRY)
    const ibtFutureFactory = await IBTFutureFactory.attach(IBT_FUTURE_FACTORY)

    let tx = await registry.addFuturePlatform(ibtFutureFactory.address,"AAVE",aaveFuture.address,aaveFutureWallet.address,futureVault.address);
    await tx.wait()
    tx = await registry.addFutureFactory(ibtFutureFactory.address, "AAVE");
    await tx.wait()

    tx = await ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, deployer.address);
    await tx.wait()

    }

    main()
      .then(() => process.exit(0))
      .catch(error => {
        console.error(error);
        process.exit(1);
      });