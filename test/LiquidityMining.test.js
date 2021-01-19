const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { AaveFuture, AaveFutureWallet, FutureVault, LiquidityGauge } = common.contracts
const { adai, ADAI_ADDRESS, WETH_ADDRESS, uniswapRouter , DAY_TIME } = common

const { initializeCore, initializeFutures } = require("./initialize")

describe("Gauge Controller", function (){

    this.timeout(100 * 10000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        await initializeCore.bind(this)()
    })

    it("can retrieve the epoch length", async function () {
        expect(await this.gaugeController.getEpochLength()).to.be.bignumber.gt(new BN(0))
    })

    it("can retrieve the epoch inflation rate", async function () {
        expect(await this.gaugeController.getLastEpochInflationRate()).to.be.bignumber.gt(new BN(0))
    })

    it("APW withdrawals disabled by default ", async function () {
        expect(await this.gaugeController.getWithdrawableState()).to.be.equal(false)
    })

    it("can enable APW withdrawals", async function () {
        await this.gaugeController.resumeAPWWithdraw({from:owner})
    })


    describe("With ongoing future (aave weekly adai)", function (){
    
        beforeEach(async function () {
            await initializeFutures.bind(this)()
            await this.registry.addFutureFactory(this.ibtFutureFactory.address, "AAVE", { from: owner });
            this.aaveFuture = await AaveFuture.new()
            this.aaveFutureWallet =  await AaveFutureWallet.new()
            this.aaveFutureVault = await FutureVault.new()
            await this.registry.addFuturePlatform(this.ibtFutureFactory.address, "AAVE", this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address,{ from: owner })
            await this.ibtFutureFactory.deployFutureWithIBT("AAVE",ADAI_ADDRESS,7,{ from: owner });
            this.deployedAaveFuture =  await AaveFuture.at(await this.registry.getFutureAt(0))
            this.aaveFutureLiquidityGauge =  await LiquidityGauge.at(await this.gaugeController.getLiquidityGaugeOfFuture(this.deployedAaveFuture.address))
            await this.gaugeController.setGaugeWeight( this.aaveFutureLiquidityGauge.address ,2000000000000000,{ from: owner } )
        })

        it("can set the weight of the liquity gauge", async function () {
            await this.gaugeController.setGaugeWeight( this.aaveFutureLiquidityGauge.address ,2000000000000000,{ from: owner } )
        })


        describe("With user liquidity provided", function (){
    
            beforeEach(async function () {
                await uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], user1, Date.now() + 25, { from: user1, value: ether("1") })
                await adai.approve(this.controller.address, ether("100"), { from: user1 })
                await this.controller.register(this.deployedAaveFuture.address, ether("100"), { from: user1 })
                await this.controller.setPeriodStartingDelay(DAY_TIME*7,{ from: owner })
                await this.controller.startFuturesByPeriodDuration(DAY_TIME*7,{ from: owner })
                await time.increase(DAY_TIME*7)
                await this.controller.startFuturesByPeriodDuration(DAY_TIME*7,{ from: owner })
                await this.gaugeController.resumeAPWWithdraw({from:owner})

            })


        })

    })
        
})
