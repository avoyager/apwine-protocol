const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat");

const { BN, expectRevert, time, balance } = require("@openzeppelin/test-helpers")

const common = require("./common")
const { YUSD_ADDRESS, WETH_ADDRESS, DAY_TIME } = common

const { initializeCore, initializeFutures, initializeYearnContracts } = require("./initialize")
const { util } = require("prettier");


describe("Yearn Future", function () {

    this.timeout(100 * 10000)
    beforeEach(async function () {

        await initializeCore.bind(this)()
        await initializeFutures.bind(this)()
        await initializeYearnContracts.bind(this)()

        this.yTokenFuture = await this.yTokenFuture.deploy()
        this.yTokenFutureWallet = await this.yTokenFutureWallet.deploy()
        this.yearnFutureVault = await this.yearnFutureVault.deploy()

        await this.registry.connect(this.owner).addFutureFactory(this.ibtFutureFactory.address, "YEARN");
        await this.registry.connect(this.owner).addFuturePlatform(this.ibtFutureFactory.address, "YEARN", this.yTokenFuture.address, this.yTokenFutureWallet.address, this.yearnFutureVault.address)
    })


    it("Contracts correctly registered", async function () {
        expect(await this.registry.getFuturePlatform("YEARN")).to.eql([this.yTokenFuture.address, this.yTokenFutureWallet.address, this.yearnFutureVault.address])
    })

    it("Future registered", async function () {
        expect(await this.registry.isRegisteredFuturePlatform("YEARN")).to.be.equal(true)
    })

    it("Future platforms count is valid", async function () {
        expect(await this.registry.futurePlatformsCount()).to.equal(1)
    })

    describe("Weekly YUSD", function () {

        beforeEach(async function () {
            await this.ibtFutureFactory.connect(this.owner).deployFutureWithIBT("YEARN", YUSD_ADDRESS, 7)
            this.deployedYearnFuture = await this.yTokenFuture.attach(await this.registry.getFutureAt(0))
        })

        it("YEARN YUSD Future added in registry", async function () {
            expect(await this.registry.futureCount()).to.equal(1)
        })

        it("Can retrieve the future durations list", async function () {
            const durations = await this.controller.getDurations()
            expect(await durations.length).to.be.equal(1)
        })

        it("Can retrieve the registered future with its duration", async function () {
            const dailyFutures = await this.controller.getFuturesWithDuration(DAY_TIME * 7)
            expect(await dailyFutures.length).to.be.equal(1)
        })

        it("Can check is future is registred", async function () {
            expect(await this.registry.isRegisteredFuture(this.deployedYearnFuture.address)).to.be.equal(true)
        })

        it("Can check future wallet is correctly deployed", async function () {
            const futureWallet = await this.yTokenFutureWallet.attach(await this.deployedYearnFuture.getFutureWalletAddress())
            expect(await futureWallet.getFutureAddress()).to.be.deep.equal(this.deployedYearnFuture.address)
        })

        it("Can check future wallet is correctly set", async function () {
            const futureWallet = await this.yTokenFutureWallet.attach(await this.deployedYearnFuture.getFutureWalletAddress())
            expect(await futureWallet.getIBTAddress()).to.be.deep.equal(await this.deployedYearnFuture.getIBTAddress())
        })

        it("Can check future vault is correctly deployed", async function () {
            const futureVault = await this.yearnFutureVault.attach(await this.deployedYearnFuture.getFutureVaultAddress())
            expect(await futureVault.getFutureAddress()).to.be.deep.equal(this.deployedYearnFuture.address)
        })

        describe("User registration", function () {


            beforeEach(async function () {
                this.uniswapRouter = new ethers.Contract("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, this.owner);
                await this.uniswapRouter.swapExactETHForTokens(0, [WETH_ADDRESS, YUSD_ADDRESS], this.user1.address, Date.now() + 25, { value: ethers.utils.parseEther("1") })
                this.yusd = new ethers.Contract(YUSD_ADDRESS, require("@openzeppelin/contracts-upgradeable/build/contracts/ERC20Upgradeable.json").abi, this.owner);
            })

            it("has at least 100 YUSD in their wallet", async function () {
                expect(await this.yusd.balanceOf(this.user1.address)).to.gt(ethers.utils.parseEther("100"))
            })

            it("can't register if it hasn't approved", async function () {
                expectRevert.unspecified(this.controller.connect(this.user1).register(this.deployedYearnFuture.address, ethers.utils.parseEther("100")))
            })

            it("can register to the next period", async function () {
                await this.yusd.connect(this.user1).approve(this.controller.address, ethers.utils.parseEther("100"))
                await this.controller.connect(this.user1).register(this.deployedYearnFuture.address, ethers.utils.parseEther("100"))
            })

            describe("with funds registered", function () {

                beforeEach(async function () {
                    await this.yusd.connect(this.user1).approve(this.controller.address, ethers.utils.parseEther("100"))
                    await this.controller.connect(this.user1).register(this.deployedYearnFuture.address, ethers.utils.parseEther("100"))
                })


                it("can unregister", async function () {
                    await this.controller.connect(this.user1).unregister(this.deployedYearnFuture.address, ethers.utils.parseEther("1"))
                })

                it("can unregister the whole registered balance", async function () {
                    await this.controller.connect(this.user1).unregister(this.deployedYearnFuture.address, 0)
                })

                it("can get its registered funds", async function () {
                    expect(await this.deployedYearnFuture.getRegisteredAmount(this.user1.address)).to.gte(ethers.utils.parseEther("1"))
                })

                it("can start the period", async function () {
                    await this.controller.connect(this.owner).setPeriodStartingDelay(DAY_TIME * 7)
                    await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME * 7)
                })

                describe("with next period started", function () {

                    beforeEach(async function () {
                        await this.controller.connect(this.owner).setPeriodStartingDelay(DAY_TIME * 7)
                        await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME * 7)
                        this.futureIBT = await this.APWineIBT.attach(await this.deployedYearnFuture.getAPWIBTAddress());
                    })

                    it("fyt was generated with the right name", async function () {
                        let addressFYT = await this.deployedYearnFuture.connect(this.user1).getFYTofPeriod(1)
                        const fyt1 = await this.FutureYieldToken.attach(addressFYT)
                        let symbolFYT = await fyt1.symbol()
                        expect(symbolFYT == "7D-YEARN-YUSD-1")
                    })

                    it("user can get apwibt balance", async function () {
                        expect(await this.futureIBT.balanceOf(this.user1.address)).to.gte(0)
                    })

                    it("user getter for claimable apwibt and apwibt claimed are consitent", async function () {
                        const amount = await this.deployedYearnFuture.getClaimableAPWIBT(this.user1.address);
                        await this.controller.connect(this.user1).claimFYT(this.deployedYearnFuture.address)
                        expect(await this.futureIBT.balanceOf(this.user1.address) == amount);
                    })

                    it("user get claimable apwibt", async function () {
                        expect(await this.deployedYearnFuture.getClaimableAPWIBT(this.user1.address)).to.gte(0)
                    })

                    it("user cant withdraw with 0 amount", async function () {
                        expectRevert(this.controller.connect(this.user1).withdrawLockFunds(this.deployedYearnFuture.address, 0), 'Invalid amount')
                    })

                    it("user can withdraw all its locked locked balance after claiming", async function () {
                        await this.controller.connect(this.user1).claimFYT(this.deployedYearnFuture.address)
                        const amount = await this.futureIBT.balanceOf(this.user1.address)
                        await this.controller.connect(this.user1).withdrawLockFunds(this.deployedYearnFuture.address, amount)
                    })

                    it("user can claim tokens generated", async function () {
                        await this.controller.connect(this.user1).claimFYT(this.deployedYearnFuture.address)
                    })

                    it("can start another period", async function () {
                        await time.increase(DAY_TIME * 7)
                        await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME * 7)
                    })

                    describe("with future period expired", function () {

                        beforeEach(async function () {
                            await this.controller.connect(this.user1).claimFYT(this.deployedYearnFuture.address)
                            await this.controller.connect(this.owner).startFuturesByPeriodDuration(DAY_TIME * 7)
                            this.deployedYearnFutureWallet = await this.yTokenFutureWallet.attach(await this.deployedYearnFuture.getFutureWalletAddress())
                        })

                        it("internal next period id must be 3 ", async function () {
                            expect(await this.deployedYearnFuture.getNextPeriodIndex()).to.equal(3)
                        })

                        it("user can claim the new period tokens tokens generated", async function () {
                            await this.controller.connect(this.user1).claimFYT(this.deployedYearnFuture.address)
                        })

                        it("user can get its redeemable yield for the 1st period", async function () {
                            expect(await this.deployedYearnFutureWallet.connect(this.user1).getRedeemableYield(1, this.user1.address)).to.gte(0)
                        })

                        it("user can redeem its yield for the 1st period", async function () {
                            await this.deployedYearnFutureWallet.connect(this.user1).redeemYield(1)
                        })

                    })


                })
            })

        })

    })

})
