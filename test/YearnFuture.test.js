const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { yTokenFuture, yTokenFutureWallet, FutureVault } = common.contracts
const { adai, YUSD_ADDRESS,WETH_ADDRESS, uniswapRouter } = common

const { initializeCore, initializeFutures } = require("./initialize")

describe("Yearn Future", function (){

    this.timeout(100 * 5000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {

        await initializeCore.bind(this)()
        await initializeFutures.bind(this)()

        await this.registry.addFutureFactory(this.ibtFutureFactory.address, "YEARN", { from: owner });

        this.yearnFuture = await yTokenFuture.new()

        this.yearnFutureWallet =  await yTokenFutureWallet.new()

        this.yearnFutureVault = await FutureVault.new()

        await this.registry.addFuturePlatform(this.ibtFutureFactory.address, "YEARN", this.yearnFuture.address,this.yearnFutureWallet.address,this.yearnFutureVault.address,{ from: owner })
    })


    it("Contracts correctly registered", async function () {
        expect(await this.registry.getFuturePlatform("YEARN")).to.eql([this.yearnFuture.address,this.yearnFutureWallet.address,this.yearnFutureVault.address])
    })

    it("Future registered", async function () {
        expect(await this.registry.isRegisteredFuturePlatform("YEARN")).to.be.equal(true)
    })
    
    it("Future platforms count is valid", async function () {
        expect(await this.registry.futurePlatformsCount()).to.be.bignumber.equal(new BN(1))
    })

    describe("Weekly YUSD", function (){

        beforeEach(async function () {
            await this.ibtFutureFactory.deployFutureWithIBT("YEARN",YUSD_ADDRESS,7,{ from: owner })
            await this.gaugeController.setGaugeWeight( await this.gaugeController.getLiquidityGaugeOfFuture(await this.registry.getFutureAt(0)),2000000000000000,{ from: owner } )
        })

        it("YEARN YUSD Future added in registry", async function () {
            expect(await this.registry.futureCount()).to.be.bignumber.equal(new BN(1))
        })

        it("Can retrieve the future durations list" , async function(){
            const durations = await this.controller.getDurations()
            expect(await durations.length).to.be.equal(1)
        })

        it("Can retrieve the registered future with its duration", async function (){
            const dailyFutures = await this.controller.getFuturesWithDuration(60*60*24*7)
            expect(await dailyFutures.length).to.be.equal(1)
        })

        it("Can check is future is registred", async function(){
            expect(await this.registry.isRegisteredFuture(await this.registry.getFutureAt(0))).to.be.equal(true)
        })

        describe("User registration", function (){


            beforeEach(async function () {
                this.deployedYearnFuture =  await yTokenFuture.at(await this.registry.getFutureAt(0))
                await uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, YUSD_ADDRESS], user1, Date.now() + 25, { from: user1, value: ether("1") })
            })

            it("has at least 100 YUSD in their wallet", async function () {
                expect(await yusd.balanceOf(user1)).to.be.bignumber.gt(ether("100"))
            })

            it("can't register if it hasn't approved", async function () {
                expectRevert.unspecified( this.controller.register(this.deployedYearnFuture.address, ether("100"), { from: user1 }))
            })

            it("can register to the next period", async function () {
                await yusd.approve(this.controller.address, ether("100"), { from: user1 })
                await this.controller.register(this.deployedYearnFuture.address, ether("100"), { from: user1 })
            })

            describe("with funds registered", function () {

                beforeEach(async function () {
                    await yusd.approve(this.controller.address, ether("100"), { from: user1 })
                    await this.controller.register(this.deployedYearnFuture.address, ether("100"), { from: user1 })
                })

                it("can unregister", async function() {
                    await this.controller.unregister(this.deployedYearnFuture.address,ether("1"), { from: user1 })
                })

                it("can get its registered funds", async function() {
                    expect(await this.deployedYearnFuture.getRegisteredAmount(user1)).to.be.bignumber.gte(ether("1"))
                })

                it("can start the period", async function () {
                    await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
                    await this.controller.startFuturesByPeriodDuration(24*60*60*7,{ from: owner })
                })

                describe("with next period started", function () {

                    beforeEach(async function () {
                        await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
                        await this.controller.startFuturesByPeriodDuration(24*60*60*7,{ from: owner })
                    })

                    it("fyt was generated with the right name", async function() {
                        let addressFYT = await this.deployedYearnFuture.getFYTofPeriod(1, { from: user1 })
                        const fyt1 = await contract.fromArtifact("ERC20", addressFYT)
                        let symbolFYT = await fyt1.symbol()
                        expect(symbolFYT == "7D-YEARN-YUSD-1")
                    })

                    it("user can claim tokens generated", async function() {
                        await this.controller.claimFYT(this.deployedYearnFuture.address, { from: user1 })
                    })

                    
                })
            })

        })

    })

})
