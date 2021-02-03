require('dotenv').config();

const { ethers, upgrades } = require("hardhat");

const team_wallet = require("../common").gnosisSafe;
const common = require("../common")

async function main() {

    IBT_FUTURE_FACTORY ="";
    ATOKEN_ADDRESS="";
    DURATION = 7;

    const [deployer] = await ethers.getSigners();
    console.log("Deploying the contracts with the account:", await deployer.getAddress());
    console.log("Account balance:", (await deployer.getBalance()).toString());

    IBTFutureFactory = await ethers.getContractFactory('IBTFutureFactory');

    const ibtFutureFactory = await IBTFutureFactory.attach(IBT_FUTURE_FACTORY)

    let tx = await ibtFutureFactory.deployFutureWithIBT("AAVE",ATOKEN_ADDRESS,DURATION);
    await tx.wait()

    console.log("done");
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });


