const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat");

const { BN, expectRevert, time, balance } = require("@openzeppelin/test-helpers")

const common = require("./common")
const { ADAI_ADDRESS, WETH_ADDRESS , DAY_TIME } = common

const { initializeCore, initializeFutures ,initializeAaveContracts} = require("./initialize");
const { util } = require("prettier");

describe("Aave Future", function (){

    this.timeout(100 * 10000)
    beforeEach(async function () {

        await initializeCore.bind(this)();
        await initializeFutures.bind(this)();
        await initializeAaveContracts.bind(this)();

        this.aaveFuture = await this.AaveFuture.deploy()
        this.aaveFutureWallet =  await this.AaveFutureWallet.deploy()
        this.aaveFutureVault = await this.FutureVault.deploy()
        
        await this.registry.connect(this.owner).addFutureFactory(this.ibtFutureFactory.address, "AAVE");
        await this.registry.connect(this.owner).addFuturePlatform(this.ibtFutureFactory.address, "AAVE", this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address)
    })


    it("Contracts correctly registered", async function () {
        expect(await this.registry.getFuturePlatform("AAVE")).to.eql([this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address])
    })

    it("Future registered", async function () {
        expect(await this.registry.isRegisteredFuturePlatform("AAVE")).to.be.equal(true)
    })
    
    it("Future platforms count is valid", async function () {
        expect(await this.registry.futurePlatformsCount()).to.equal(1)
    })

    describe("Weekly ADAI", function (){

        beforeEach(async function () {
            await this.ibtFutureFactory.connect(this.owner).deployFutureWithIBT("AAVE",ADAI_ADDRESS,7);
            this.deployedAaveFuture =  await this.AaveFuture.attach(await this.registry.getFutureAt(0))
            this.aaveFutureLiquidityGauge =  await this.LiquidityGauge.attach(await this.gaugeController.getLiquidityGaugeOfFuture(this.deployedAaveFuture.address))
            await this.gaugeController.connect(this.owner).setGaugeWeight( this.aaveFutureLiquidityGauge.address ,2000000000000000)
        })

        it("AAVE ADAI Future added in registry", async function () {
            expect(await this.registry.futureCount()).to.equal(1)
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
            expect(await this.registry.isRegisteredFuture(this.deployedAaveFuture.address)).to.be.equal(true)
        })

        it("Can check future wallet is correctly deployed", async function(){
            const futureWallet =  await this.AaveFutureWallet.attach(await this.deployedAaveFuture.getFutureWalletAddress())
            expect(await futureWallet.getFutureAddress()).to.be.deep.equal(this.deployedAaveFuture.address)
        })

        it("Can check future wallet is correctly set", async function(){
            const futureWallet =  await this.AaveFutureWallet.attach(await this.deployedAaveFuture.getFutureWalletAddress())
            expect(await futureWallet.getIBTAddress()).to.be.deep.equal(await this.deployedAaveFuture.getIBTAddress())
        })

        it("Can check future vault is correctly deployed", async function(){
            const futureVault =  await this.FutureVault.attach(await this.deployedAaveFuture.getFutureVaultAddress())
            expect(await futureVault.getFutureAddress()).to.be.deep.equal(this.deployedAaveFuture.address)
        })


        describe("User registration", function (){


            beforeEach(async function () {
                this.uniswapRouter = new ethers.Contract("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, this.owner);
                await this.uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], this.user1.address, Date.now() + 25, { value:  ethers.utils.parseEther("1") })              
                this.adai = new ethers.Contract(ADAI_ADDRESS,require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi, this.owner);
            })

            it("has at least 100 ADAI in their wallet", async function () {
                expect(await this.adai.balanceOf(this.user1.address)).to.gt(ethers.utils.parseEther("100"))
            })

            it("can't register if it hasn't approved", async function () {
                expectRevert.unspecified( this.controller.connect(this.user1).register(this.deployedAaveFuture.address, ethers.utils.parseEther("100")))
            })

            it("can register to the next period", async function () {
                await this.adai.connect(this.user1).approve(this.controller.address,  ethers.utils.parseEther("100"))
                await this.controller.connect(this.user1).register(this.deployedAaveFuture.address,  ethers.utils.parseEther("100"))
            })

            describe("with funds registered", function () {

                beforeEach(async function () {
                    await this.adai.connect(this.user1).approve(this.controller.address,  ethers.utils.parseEther("100"));
                    await this.controller.connect(this.user1).register(this.deployedAaveFuture.address,  ethers.utils.parseEther("100"))
                })

                it("can unregister", async function() {
                    await this.controller.connect(this.user1).unregister(this.deployedAaveFuture.address, ethers.utils.parseEther("1"))
                })

                it("can unregister the whole registered balance", async function() {
                    await this.controller.connect(this.user1).unregister(this.deployedAaveFuture.address,0)
                })

                it("can get its registered funds", async function() {
                    expect(await this.deployedAaveFuture.getRegisteredAmount(this.user1.address)).to.gte(ethers.utils.parseEther("1"))
                })

                it("can start the period", async function () {
                    await this.controller.connect(this.owner).setPeriodStartingDelay(DAY_TIME*7)
                    await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                })

                describe("with next period started", function () {

                    beforeEach(async function () {
                        await this.controller.connect(this.owner).setPeriodStartingDelay(DAY_TIME*7)
                        await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                        this.futureIBT = await this.APWineIBT.attach(await this.deployedAaveFuture.getAPWIBTAddress()); 
                    })

                    it("fyt was generated with the right name", async function() {
                        let addressFYT = await this.deployedAaveFuture.connect(this.owner).getFYTofPeriod(1)
                        const fyt1 = await this.FutureYieldToken.attach(addressFYT)
                        let symbolFYT = await fyt1.symbol()
                        expect(symbolFYT == "7D-AAVE-ADAI-1")
                    })

                    it("user can get apwibt balance", async function(){
                        expect(await this.futureIBT.balanceOf(this.user1.address)).to.gte(0)
                    })

                    it("user getter for claimable apwibt and apwibt claimed are consitent", async function(){
                        const amount = await this.deployedAaveFuture.getClaimableAPWIBT(this.user1.address);
                        await this.controller.connect(this.user1).claimFYT(this.deployedAaveFuture.address)
                        expect(await this.futureIBT.balanceOf(this.user1.address) == amount);
                    })

                    it("user get claimable apwibt", async function() {
                        expect(await this.deployedAaveFuture.getClaimableAPWIBT(this.user1.address)).to.gte(0)
                    })

                    it("user cant withdraw with 0 amount", async function() {
                        expectRevert(this.controller.connect(this.user1).withdrawLockFunds(this.deployedAaveFuture.address, 0),'Invalid amount')
                    })

                    it("user can withdraw all its locked locked balance after claiming", async function() {
                        await this.controller.connect(this.user1).claimFYT(this.deployedAaveFuture.address)
                        const amount = await this.futureIBT.balanceOf(this.user1.address)
                        await this.controller.connect(this.user1).withdrawLockFunds(this.deployedAaveFuture.address, amount)
                    })

                    it("user can claim tokens generated", async function() {
                        await this.controller.connect(this.user1).claimFYT(this.deployedAaveFuture.address)
                    })

                    it("can start another period", async function() {
                        await time.increase(DAY_TIME*7)
                        await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                    })

                    describe("with future period expired", function () {

                        beforeEach(async function () {
                            await this.controller.connect(this.user1).claimFYT(this.deployedAaveFuture.address)
                            await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME*7)
                            this.deployedAaveFutureWallet =  await this.AaveFutureWallet.attach(await this.deployedAaveFuture.getFutureWalletAddress())
                        })
    
                        it("internal next period id must be 3 ", async function() {
                            expect(await this.deployedAaveFuture.getNextPeriodIndex()).to.equal(3)
                        })
    
                        it("user can claim the new period tokens tokens generated", async function() {
                            await this.controller.connect(this.user1).claimFYT(this.deployedAaveFuture.address)
                        })

                        it("user can get its redeemable yield for the 1st period", async function() {
                           expect(await this.deployedAaveFutureWallet.connect(this.user1).getRedeemableYield(1,this.user1.address)).to.gte(0)
                        })

                        it("user can redeem its yield for the 1st period", async function() {
                            await this.deployedAaveFutureWallet.connect(this.user1).redeemYield(1)
                        })

                        it("can check the redeemable user liqudity in liquidity gauge  ", async function() {
                            expect(await this.aaveFutureLiquidityGauge.getUserRedeemable(this.user1.address)).to.gte(0)
                        })
              
                    })
          
                })
            })

        })

    })

})
