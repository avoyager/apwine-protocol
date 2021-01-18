const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { AaveFuture, AaveFutureWallet, FutureVault } = common.contracts
const { adai, ADAI_ADDRESS, WETH_ADDRESS, uniswapRouter } = common

const { initializeCore, initializeFutures } = require("./initialize")

describe("Aave Future", function (){

    this.timeout(100 * 10000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {

        await initializeCore.bind(this)()
        await initializeFutures.bind(this)()

        await this.registry.addFutureFactory(this.ibtFutureFactory.address, "AAVE", { from: owner });

        this.aaveFuture = await AaveFuture.new()

        this.aaveFutureWallet =  await AaveFutureWallet.new()

        this.aaveFutureVault = await FutureVault.new()

        await this.registry.addFuturePlatform(this.ibtFutureFactory.address, "AAVE", this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address,{ from: owner })
    })


    it("Contracts correctly registered", async function () {
        expect(await this.registry.getFuturePlatform("AAVE")).to.eql([this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address])
    })

    it("Future registered", async function () {
        expect(await this.registry.isRegisteredFuturePlatform("AAVE")).to.be.equal(true)
    })
    
    it("Future platforms count is valid", async function () {
        expect(await this.registry.futurePlatformsCount()).to.be.bignumber.equal(new BN(1))
    })

    describe("Weekly ADAI", function (){

        beforeEach(async function () {
            await this.ibtFutureFactory.deployFutureWithIBT("AAVE",ADAI_ADDRESS,7,{ from: owner })
            await this.gaugeController.setGaugeWeight( await this.gaugeController.getLiquidityGaugeOfFuture(await this.registry.getFutureAt(0)),2000000000000000,{ from: owner } )
        })

        it("AAVE ADAI Future added in registry", async function () {
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

        it("Can check future wallet is correctly deployed", async function(){
            const deployedAaveFuture =  await AaveFuture.at(await this.registry.getFutureAt(0))
            const futureWallet =  await AaveFutureWallet.at(await deployedAaveFuture.getFutureWalletAddress())
            expect(await futureWallet.getFutureAddress()).to.be.deep.equal(deployedAaveFuture.address)
        })

        it("Can check future wallet is correctly set", async function(){
            const deployedAaveFuture =  await AaveFuture.at(await this.registry.getFutureAt(0))
            const futureWallet =  await AaveFutureWallet.at(await deployedAaveFuture.getFutureWalletAddress())
            expect(await futureWallet.getIBTAddress()).to.be.deep.equal(await deployedAaveFuture.getIBTAddress())
        })

        it("Can check future vault is correctly deployed", async function(){
            const deployedAaveFuture = await AaveFuture.at(await this.registry.getFutureAt(0))
            const futureVault =  await FutureVault.at(await deployedAaveFuture.getFutureVaultAddress())
            expect(await futureVault.getFutureAddress()).to.be.deep.equal(deployedAaveFuture.address)
        })


        describe("User registration", function (){


            beforeEach(async function () {
                this.deployedAaveFuture =  await AaveFuture.at(await this.registry.getFutureAt(0))
                await uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], user1, Date.now() + 25, { from: user1, value: ether("1") })
            })

            it("has at least 100 ADAI in their wallet", async function () {
                expect(await adai.balanceOf(user1)).to.be.bignumber.gt(ether("100"))
            })

            it("can't register if it hasn't approved", async function () {
                expectRevert.unspecified( this.controller.register(this.deployedAaveFuture.address, ether("100"), { from: user1 }))
            })

            it("can register to the next period", async function () {
                await adai.approve(this.controller.address, ether("100"), { from: user1 })
                await this.controller.register(this.deployedAaveFuture.address, ether("100"), { from: user1 })
            })

            describe("with funds registered", function () {

                beforeEach(async function () {
                    await adai.approve(this.controller.address, ether("100"), { from: user1 })
                    await this.controller.register(this.deployedAaveFuture.address, ether("100"), { from: user1 })
                })

                it("can unregister", async function() {
                    await this.controller.unregister(this.deployedAaveFuture.address,ether("1"), { from: user1 })
                })

                it("can get its registered funds", async function() {
                    expect(await this.deployedAaveFuture.getRegisteredAmount(user1)).to.be.bignumber.gte(ether("1"))
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
                        let addressFYT = await this.deployedAaveFuture.getFYTofPeriod(1, { from: user1 })
                        const fyt1 = await contract.fromArtifact("ERC20", addressFYT)
                        let symbolFYT = await fyt1.symbol()
                        expect(symbolFYT == "7D-AAVE-ADAI-1")
                    })


                    it("user get claimable apwibt", async function() {
                        expect(await this.deployedAaveFuture.getClaimableAPWIBT(user1)).to.be.bignumber.gte(new BN(0))
                    })


                    it("user can claim tokens generated", async function() {
                        await this.controller.claimFYT(this.deployedAaveFuture.address, { from: user1 })
                    })

                    describe("with future period expired", function () {

                        beforeEach(async function () {
                            await this.controller.claimFYT(this.deployedAaveFuture.address, { from: user1 })
                            await this.controller.startFuturesByPeriodDuration(24*60*60*7,{ from: owner })
                            this.deployedAaveFutureWallet =  await AaveFutureWallet.at(await this.deployedAaveFuture.getFutureWalletAddress())
                        })
    
                        it("internal next period id must be 3 ", async function() {
                            expect(this.deployedAaveFuture.getNextPeriodIndex()).to.be.bignumber.equal(new BN(3))
                        })
    
                        it("user can claim the new period tokens tokens generated", async function() {
                            await this.controller.claimFYT(this.deployedAaveFuture.address, { from: user1 })
                        })

                        it("user can get its redeemable yield for the 1st period", async function() {
                           expect(await this.deployedAaveFutureWallet.getRedeemableYield(1,user1, { from: user1 })).to.be.bignumber.gte(new BN(0))
                        })

                        it("user can redeem its yield for the 1st period", async function() {
                            await this.deployedAaveFutureWallet.redeemYield(1, { from: user1 })
                        })
              
                    })
          
                })
            })

        })

    })

})
