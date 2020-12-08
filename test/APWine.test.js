const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const Controller = contract.fromArtifact("Controller")
const AaveFuture = contract.fromArtifact("AaveFuture")
const AaveFutureWallet = contract.fromArtifact("AaveFutureWallet")
const ProxyFactory = contract.fromArtifact("ProxyFactory")
const APWineIBT = contract.fromArtifact("APWineIBT")
const FutureYieldToken = contract.fromArtifact("FutureYieldToken")
const FutureVault = contract.fromArtifact("FutureVault")
const APWineMaths = contract.fromArtifact("APWineMaths")
const APWineNaming = contract.fromArtifact("APWineNaming")


const ADDRESS_0 = "0x0000000000000000000000000000000000000000"

const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"
const adai = contract.fromArtifact("ERC20", ADAI_ADDRESS)

const uniswapRouter = contract.fromABI(require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, undefined, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")

describe("APWine Libraries", function () {

    this.timeout(100 * 1000)
    const [owner, user1, user2] = accounts

    describe("APWineMaths", function(){
        beforeEach(async function () {
            this.maths = await APWineMaths.new()
        })

        it("getScaledInput for 0 values", async function () {
            expect(await this.maths.getScaledInput(0,0,0)).to.be.bignumber.equal(new BN(0))
        })

        it("getActualOutput for 0 values", async function () {
            expect(await this.maths.getActualOutput(0,0,0)).to.be.bignumber.equal(new BN(0))
        })

        it("scalling of input is consistent", async function () {
            // Input 10 is first of sum, it doubles before second input of 10
            expect(await this.maths.getScaledInput(10,10,20)).to.be.bignumber.equal(new BN(5))
        })

        it("scalling of output is consistent", async function () {
            // Input 10 is first of sum, it doubles before second input of 10
            expect(await this.maths.getActualOutput(5,15,30)).to.be.bignumber.equal(new BN(10))
        })

    })

    describe("APWineNaming", function(){
        beforeEach(async function () {
            this.naming = await APWineNaming.new()
        })
        it("Token Name generation works for corrects inputs", async function () {
            expect(await this.naming.genTokenSymbol(0,"ADAI","AAVE", "W") == "W0ADAIAAVE");
        })

    })

})


describe("APWine Contracts", function () {

    this.timeout(100 * 1000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        this.controller = await Controller.new()
        await this.controller.initialize(owner)
        this.proxyFactory = await ProxyFactory.new()
        await this.controller.setAPWineProxyFactoryAddress(this.proxyFactory.address, {from:owner})
        this.apwineIBT = await APWineIBT.new()
        await this.controller.setAPWineIBTLogic(this.apwineIBT.address, {from:owner})
        this.fyt = await FutureYieldToken.new()
        await this.controller.setFutureYieldTokenLogic(this.fyt.address, {from:owner})
        this.maths = await APWineMaths.new()
        this.naming = await APWineNaming.new()
    })

    it("has no futures available by default", async function () {
        expect(await this.controller.futureCount()).to.be.bignumber.equal(new BN(0))
    })


    describe("APWine Aave integration", function () {

        beforeEach(async function () {
            await AaveFuture.detectNetwork()
            await AaveFuture.link("APWineMaths", this.maths.address)
            await AaveFuture.link("APWineNaming", this.naming.address)
            this.aaveWeeklyFuture = await AaveFuture.new()
            await this.aaveWeeklyFuture.initialize(this.controller.address, ADAI_ADDRESS, 7,"W","Aave", "Weekly Aave DAI", "WADAIAAVE", owner)
            await AaveFutureWallet.detectNetwork()
            await AaveFutureWallet.link("APWineMaths", this.maths.address)
            this.aaveWeeklyFutureWallet = await AaveFutureWallet.new()
            await this.aaveWeeklyFutureWallet.initialize(this.aaveWeeklyFuture.address,owner)

            this.aaveWeeklyFutureVault = await FutureVault.new()
            await this.aaveWeeklyFutureVault.initialize(this.aaveWeeklyFuture.address, owner)
            await this.aaveWeeklyFuture.setFutureVault(this.aaveWeeklyFutureVault.address,{from:owner})
            await this.aaveWeeklyFuture.setFutureWallet(this.aaveWeeklyFutureWallet.address,{from:owner})

            await this.controller.addFuture(this.aaveWeeklyFuture.address, {from:owner});
        })

        it("future is registered in controller", async function () {
            expect(await this.controller.future(0)).to.equal(this.aaveWeeklyFuture.address)
        })

        it("has no registered balance by default", async function () {
            expect(await this.aaveWeeklyFuture.getRegisteredAmount(user1)).to.be.bignumber.equal(new BN(0))
        })

        describe("with initial user ADAI balance", function () {

            beforeEach(async function () {
                await uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], user1, Date.now() + 25, { from: user1, value: ether("1") })
            })

            it("has at least 100 ADAI in their wallet", async function () {
                expect(await adai.balanceOf(user1)).to.be.bignumber.gt(ether("100"))
            })

            it("can't register if it hasn't approved", async function () {
                expectRevert.unspecified(this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: user1 }))
            })

            // const register = async (address) => {
            //     await adai.approve(this.controller.address, ether("100"))
            //     await this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: address })
            // }

            it("can register to the next period", async function () {
                await adai.approve(this.controller.address, ether("100"), { from: user1 })
                await this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: user1 })
            })

            describe("with ADAI registered for the period", function () {

                beforeEach(async function () {
                    await adai.approve(this.controller.address, ether("100"), { from: user1 })
                    await this.controller.register(this.aaveWeeklyFuture.address, ether("1"), { from: user1 })
                })

                it("can start the period", async function () {
                    await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
                    await this.aaveWeeklyFuture.startNewPeriod({ from: owner })
                })

                it("can unregister", async function() {
                    await this.aaveWeeklyFuture.unregister(ether("1"), { from: user1 })
                })

                it("can get its registered funds", async function() {
                    expect(await this.aaveWeeklyFuture.getRegisteredAmount(user1)).to.be.bignumber.gte(ether("1"))
                })

                describe("with next period started", function () {

                    beforeEach(async function () {
                        await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
                        await this.aaveWeeklyFuture.startNewPeriod({ from: owner })
                    })

                    it("fyt was generated with the right name", async function() {
                       let addressFYT = await this.aaveWeeklyFuture.getFYTofPeriod(1, { from: user1 })
                       const fyt1 = await contract.fromArtifact("ERC20", addressFYT)
                       let symbolFYT = await fyt1.symbol()
                       expect(symbolFYT == "W1ADAIAAVE")
                    })

                    it("user can claim tokens generated", async function() {
                        await this.aaveWeeklyFuture.claimFYT(user1, { from: user1 })
                    })

        
        
                })



            })

        })





    })

})
