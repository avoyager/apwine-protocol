const { accounts } = require("@openzeppelin/test-environment")

const { ethers, upgrades } = require("hardhat");

const common = require("./common")
const { FUTURE_DEPLOYER_ROLE } = common

const initializeCore = async function () {

    [this.owner, this.user1, this.user2] = await ethers.getSigners();

    this.APWineMaths = await ethers.getContractFactory('APWineMaths');
    this.APWineNaming = await ethers.getContractFactory('APWineNaming');
    this.ProxyFactory = await ethers.getContractFactory('ProxyFactory');
    this.Registry = await ethers.getContractFactory('Registry');
    this.Controller = await ethers.getContractFactory('Controller');
    this.Treasury = await ethers.getContractFactory('Treasury');

    this.maths = await this.APWineMaths.deploy()
    this.naming = await this.APWineNaming.deploy()
    this.proxyFactory = await this.ProxyFactory.deploy()

    this.registry = await upgrades.deployProxy(this.Registry, [this.owner.address], { unsafeAllowCustomTypes: true });

    this.controller = await upgrades.deployProxy(this.Controller, [this.owner.address, this.registry.address], { unsafeAllowCustomTypes: true });

    this.treasury = await upgrades.deployProxy(this.Treasury, [this.owner.address], { unsafeAllowCustomTypes: true });

    await this.registry.connect(this.owner).setTreasury(this.treasury.address)
    await this.registry.connect(this.owner).setController(this.controller.address)
    await this.registry.connect(this.owner).setProxyFactory(this.proxyFactory.address)
    await this.registry.connect(this.owner).setMathsUtils(this.maths.address)
    await this.registry.connect(this.owner).setNamingUtils(this.naming.address)


}

const initializeFutures = async function () {

    this.APWineIBT = await ethers.getContractFactory('APWineIBT');
    this.FutureYieldToken = await ethers.getContractFactory('FutureYieldToken');
    this.IBTFutureFactory = await ethers.getContractFactory('IBTFutureFactory');

    this.apwineIBTLogic = await this.APWineIBT.deploy()
    this.fytLogic = await this.FutureYieldToken.deploy()

    await this.registry.connect(this.owner).setAPWineIBTLogic(this.apwineIBTLogic.address);
    await this.registry.connect(this.owner).setFYTLogic(this.fytLogic.address);

    this.ibtFutureFactory = await upgrades.deployProxy(this.IBTFutureFactory, [this.controller.address, this.owner.address], { unsafeAllowCustomTypes: true });
    await this.ibtFutureFactory.connect(this.owner).grantRole(FUTURE_DEPLOYER_ROLE, this.owner.address);

}

const initializeAaveContracts = async function () {
    this.AaveFuture = await ethers.getContractFactory('AaveFuture');
    this.AaveFutureWallet = await ethers.getContractFactory('AaveFutureWallet');
    this.FutureVault = await ethers.getContractFactory('FutureVault');
}

const initializeYearnContracts = async function () {
    this.yTokenFuture = await ethers.getContractFactory('yTokenFuture');
    this.yTokenFutureWallet = await ethers.getContractFactory('yTokenFutureWallet');
    this.yearnFutureVault = await ethers.getContractFactory('FutureVault');
}




module.exports = { initializeCore, initializeFutures, initializeAaveContracts, initializeYearnContracts }