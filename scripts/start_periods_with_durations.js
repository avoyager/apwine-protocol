
require('dotenv').config();

const { ethers, upgrades } = require("hardhat");

const team_wal = require("./common").gnosisSafe;
const common = require("./common")
const {DAYS} = common;

async function main() {

    CONTROLLER_ADDR = "";
    FUTURES_DURATION = 7*DAYS;

    const [deployer] = await ethers.getSigners();
    console.log("caller account", await deployer.getAddress());
    console.log("account balance:", (await deployer.getBalance()).toString());

    Controller = await ethers.getContractFactory('Controller');
    const controller = await Controller.attach(CONTROLLER_ADDR);

    let tx = await controller.startFuturesByPeriodDuration(FUTURES_DURATION);
    await tx.wait();

    console.log('DONE');
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
