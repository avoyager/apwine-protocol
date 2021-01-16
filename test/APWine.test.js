const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

// Core Protocol
const Controller = contract.fromArtifact('Controller');
const GaugeController = contract.fromArtifact('GaugeController');
const LiquidityGauge = contract.fromArtifact('LiquidityGauge');
const Registry = contract.fromArtifact('Registry');
const Treasury = contract.fromArtifact('Treasury');

// Libraries
const APWineMaths = contract.fromArtifact('APWineMaths');
const APWineNaming = contract.fromArtifact('APWineNaming');

const ProxyFactory = contract.fromArtifact('ProxyFactory');

// Future
const IBTFutureFactory = contract.fromArtifact('IBTFutureFactory');

// Future Platform
const AaveFuture = contract.fromArtifact('AaveFuture');
const AaveFutureWallet = contract.fromArtifact('AaveFutureWallet');
const FutureVault = contract.fromArtifact('FutureVault');
const FutureYieldToken = contract.fromArtifact('FutureYieldToken');
const APWineIBT = contract.fromArtifact('APWineIBT');


const ADDRESS_0 = "0x0000000000000000000000000000000000000000"

const WETH_ADDRESS = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"

const FUTURE_DEPLOYER_ROLE ="0xdacd85ccbf3b93dd485a10886cc255d4fba1805ebed1521d0c405d4416eca3be"

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
            expect(await this.naming.genFYTSymbol(2,"ADAI","AAVE", 60*60*24*30) == "30D-AAVE-ADAI-2");
        })

    })

})


describe("APWine Contracts", function () {

    this.timeout(100 * 1000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {

        this.maths = await APWineMaths.new()
        this.naming = await APWineNaming.new()
        this.proxyFactory = await ProxyFactory.new()

        await Controller.detectNetwork()
        await Controller.link("APWineMaths", this.maths.address)
        await Controller.link("APWineNaming", this.naming.address)

        await Registry.detectNetwork()
        await Registry.link('APWineMaths',this.maths.address);

        await Treasury.detectNetwork()
        await Treasury.link('APWineMaths',this.maths.address);

        this.registry = await Registry.new()
        await this.registry.initialize(owner)

        this.controller = await Controller.new()
        await this.controller.initialize(owner,this.registry.address)

        this.treasury = await Treasury.new()
        await this.treasury.initialize(owner)

        await GaugeController.detectNetwork()
        await GaugeController.link("APWineMaths", this.maths.address)
        this.gaugeController =  await GaugeController.new()
        await this.gaugeController.initialize(owner, this.registry.address)

        await this.registry.setTreasury(this.treasury.address,{ from: owner })
        await this.registry.setController(this.controller.address,{ from: owner })
        await this.registry.setProxyFactory(this.proxyFactory.address,{ from: owner })
        await this.registry.setGaugeController(this.gaugeController.address,{ from: owner })
    })

    it("Controller is correctly initialized", async function () {
        expect(await this.controller.getRegistryAddress()).to.equal(this.registry.address)
    })

    describe("With Futures", function (){

        beforeEach(async function () {
            await LiquidityGauge.detectNetwork()
            await LiquidityGauge.link("APWineMaths", this.maths.address)

            this.liquidityGaugeLogic = await LiquidityGauge.new()
            this.apwineIBTLogic = await APWineIBT.new()
            this.fytLogic = await FutureYieldToken.new()

            await this.registry.setLiquidityGaugeLogic(this.liquidityGaugeLogic.address, { from: owner });
            await this.registry.setAPWineIBTLogic(this.apwineIBTLogic.address,{ from: owner });
            await this.registry.setFYTLogic(this.fytLogic.address,{ from: owner });
        })

        describe("IBT Futures", function (){

            beforeEach(async function () {
                await IBTFutureFactory.detectNetwork()
                await IBTFutureFactory.link("APWineMaths", this.maths.address)

                this.ibtFutureFactory = await IBTFutureFactory.new()
                await this.ibtFutureFactory.initialize(this.controller.address, owner)
                await this.ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, owner,{ from: owner });
            })

            describe("AAVE futures", function (){

                beforeEach(async function () {
                    await this.registry.addFutureFactory(this.ibtFutureFactory.address, "AAVE",{ from: owner });

                    await AaveFuture.detectNetwork()
                    await AaveFuture.link("APWineMaths", this.maths.address)
                    this.aaveFuture = await AaveFuture.new()

                    await AaveFutureWallet.detectNetwork()
                    await AaveFutureWallet.link("APWineMaths", this.maths.address)
                    this.aaveFutureWallet =  await AaveFutureWallet.new()

                    this.aaveFutureVault = await FutureVault.new()

                    await this.registry.addFuturePlatform(this.ibtFutureFactory.address, "AAVE",this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address,{ from: owner })
                })


                it("AAVE future contracts correctly registered", async function () {
                    expect(await this.registry.getFuturePlatform("AAVE")).to.eql([this.aaveFuture.address,this.aaveFutureWallet.address,this.aaveFutureVault.address])
                })

                it("AAVE future registered", async function () {
                    expect(await this.registry.isRegisteredFuturePlatform("AAVE")).to.be.equal(true)
                })
                
                it("Future platforms count is valid", async function () {
                    expect(await this.registry.futurePlatformsCount()).to.be.bignumber.equal(new BN(1))
                })


                describe("Weekly ADAI", function (){

                    beforeEach(async function () {
                        await this.ibtFutureFactory.deployFutureWithIBT("AAVE",ADAI_ADDRESS,60*60*24*7,{ from: owner });
                    })

                    it("AAVE ADAI Future added", async function () {
                        expect(await this.registry.futureCount()).to.be.bignumber.equal(new BN(1))
                    })

                })

            })

        })

    })


    // describe("APWine Aave integration", function () {

    //     beforeEach(async function () {
    //         await AaveFuture.detectNetwork()
    //         await AaveFuture.link("APWineMaths", this.maths.address)
    //         await AaveFuture.link("APWineNaming", this.naming.address)
    //         this.aaveWeeklyFuture = await AaveFuture.new()
    //         await this.aaveWeeklyFuture.initialize(this.controller.address, ADAI_ADDRESS, 7,"W","Aave", "Weekly Aave DAI", "WADAIAAVE", owner)
    //         await AaveFutureWallet.detectNetwork()
    //         await AaveFutureWallet.link("APWineMaths", this.maths.address)
    //         this.aaveWeeklyFutureWallet = await AaveFutureWallet.new()
    //         await this.aaveWeeklyFutureWallet.initialize(this.aaveWeeklyFuture.address,owner)

    //         this.aaveWeeklyFutureVault = await FutureVault.new()
    //         await this.aaveWeeklyFutureVault.initialize(this.aaveWeeklyFuture.address, owner)
    //         await this.aaveWeeklyFuture.setFutureVault(this.aaveWeeklyFutureVault.address,{from:owner})
    //         await this.aaveWeeklyFuture.setFutureWallet(this.aaveWeeklyFutureWallet.address,{from:owner})

    //         await this.controller.addFuture(this.aaveWeeklyFuture.address, {from:owner});
    //     })

    //     it("future is registered in controller", async function () {
    //         expect(await this.controller.future(0)).to.equal(this.aaveWeeklyFuture.address)
    //     })

    //     it("has no registered balance by default", async function () {
    //         expect(await this.aaveWeeklyFuture.getRegisteredAmount(user1)).to.be.bignumber.equal(new BN(0))
    //     })

    //     describe("with initial user ADAI balance", function () {

    //         beforeEach(async function () {
    //             await uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, ADAI_ADDRESS], user1, Date.now() + 25, { from: user1, value: ether("1") })
    //         })

    //         it("has at least 100 ADAI in their wallet", async function () {
    //             expect(await adai.balanceOf(user1)).to.be.bignumber.gt(ether("100"))
    //         })

    //         it("can't register if it hasn't approved", async function () {
    //             expectRevert.unspecified(this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: user1 }))
    //         })

    //         // const register = async (address) => {
    //         //     await adai.approve(this.controller.address, ether("100"))
    //         //     await this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: address })
    //         // }

    //         it("can register to the next period", async function () {
    //             await adai.approve(this.controller.address, ether("100"), { from: user1 })
    //             await this.controller.register(this.aaveWeeklyFuture.address, ether("100"), { from: user1 })
    //         })

    //         describe("with ADAI registered for the period", function () {

    //             beforeEach(async function () {
    //                 await adai.approve(this.controller.address, ether("100"), { from: user1 })
    //                 await this.controller.register(this.aaveWeeklyFuture.address, ether("1"), { from: user1 })
    //             })

    //             it("can start the period", async function () {
    //                 await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
    //                 await this.aaveWeeklyFuture.startNewPeriod({ from: owner })
    //             })

    //             it("can unregister", async function() {
    //                 await this.aaveWeeklyFuture.unregister(ether("1"), { from: user1 })
    //             })

    //             it("can get its registered funds", async function() {
    //                 expect(await this.aaveWeeklyFuture.getRegisteredAmount(user1)).to.be.bignumber.gte(ether("1"))
    //             })

    //             describe("with next period started", function () {

    //                 beforeEach(async function () {
    //                     await this.controller.setPeriodStartingDelay(24*60*60*7,{ from: owner })
    //                     await this.aaveWeeklyFuture.startNewPeriod({ from: owner })
    //                 })

    //                 it("fyt was generated with the right name", async function() {
    //                    let addressFYT = await this.aaveWeeklyFuture.getFYTofPeriod(1, { from: user1 })
    //                    const fyt1 = await contract.fromArtifact("ERC20", addressFYT)
    //                    let symbolFYT = await fyt1.symbol()
    //                    expect(symbolFYT == "W1ADAIAAVE")
    //                 })

    //                 it("user can claim tokens generated", async function() {
    //                     await this.aaveWeeklyFuture.claimFYT(user1, { from: user1 })
    //                 })

        
        
    //             })



    //         })

    //     })

    // })

})
