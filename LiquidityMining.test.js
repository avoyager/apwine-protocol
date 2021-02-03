const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat");

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { adai, ADAI_ADDRESS, WETH_ADDRESS, uniswapRouter , DAY_TIME } = common

const { initializeCore, initializeFutures ,initializeAaveContracts} = require("./initialize")

describe("Gauge Controller", function (){

    this.timeout(100 * 10000)

    beforeEach(async function () {
        await initializeCore.bind(this)();
    })

    it("can retrieve the epoch length", async function () {
        expect(await this.gaugeController.getEpochLength()).to.gt(0)
    })

    it("can retrieve the epoch inflation rate", async function () {
        expect(await this.gaugeController.getLastEpochInflationRate()).to.gt(0)
    })

    it("APW withdrawals disabled by default ", async function () {
        expect(await this.gaugeController.getWithdrawableState()).to.be.equal(false)
    })

    it("can enable APW withdrawals", async function () {
        await this.gaugeController.connect(this.owner).resumeAPWWithdrawals()
    })


    describe("With ongoing future (aave weekly adai)", function (){
    
        beforeEach(async function () {
            await initializeFutures.bind(this)()
            await initializeAaveContracts.bind(this)();
            this.aaveFuture = await this.AaveFuture.deploy()
            this.aaveFutureWallet =  await this.AaveFutureWallet.deploy()
            this.aaveFutureVault = await this.FutureVault.deploy()
            await this.registry.connect(this.owner).addFutureFactory(this.ibtFutureFactory.address, "AAVE");
            await this.registry.connect(this.owner).addFuturePlatform(this.ibtFutureFactory.address, "AAVE", this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address)
            await this.ibtFutureFactory.connect(this.owner).deployFutureWithIBT("AAVE",ADAI_ADDRESS,7);
            this.deployedAaveFuture =  await this.AaveFuture.attach(await this.registry.getFutureAt(0))
            this.aaveFutureLiquidityGauge =  await this.LiquidityGauge.attach(await this.gaugeController.getLiquidityGaugeOfFuture(this.deployedAaveFuture.address))
            await this.gaugeController.connect(this.owner).setGaugeWeight( this.aaveFutureLiquidityGauge.address ,2000000000000000)
        })

        it("can set the weight of the liquity gauge", async function () {
            await this.gaugeController.connect(this.owner).setGaugeWeight( this.aaveFutureLiquidityGauge.address ,2000000000000000)
        })


        describe("With user liquidity provided", function (){
    
            beforeEach(async function () {
                await uniswapRouter.connect(user1).swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], this.user1.address, Date.now() + 25, {value: ether("1") })
                await adai.approve(this.controller.address, ether("100"))
                await this.controller.connect(this.user1).register(this.deployedAaveFuture.address, ether("100"))
                await this.controller.connect(this.owner).setPeriodStartingDelay(DAY_TIME*7)
                await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                await time.increase(DAY_TIME*7)
                await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                await this.gaugeController.connect(this.owner).resumeAPWWithdraw()

            })


        })

    })
        
})
