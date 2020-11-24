const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")

const APWineController = contract.fromArtifact("APWineController")
const APWineAaveVineyard = contract.fromArtifact("APWineAaveVineyard")
const APWineAaveCellar = contract.fromArtifact("APWineAaveCellar")
const ProxyFactory = contract.fromArtifact("ProxyFactory")
const APWineIBT = contract.fromArtifact("APWineIBT")
const FutureYieldToken = contract.fromArtifact("FutureYieldToken")
const APWineFutureWallet = contract.fromArtifact("APWineFutureWallet")
const APWineMaths = contract.fromArtifact("APWineMaths")

const ADDRESS_0 = "0x0000000000000000000000000000000000000000"

describe("APWine Libraries", function () {

    this.timeout(100 * 1000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        this.maths = await APWineMaths.new()
    })

    it("getScaledInput for 0 values", async function () {
        expect(await this.maths.getScaledInput(0,0,0)).to.be.bignumber.equal(new BN(0))
    })

    it("getActualOutput for 0 values", async function () {
        expect(await this.maths.getActualOutput(0,0,0)).to.be.bignumber.equal(new BN(0))
    })

})


describe("APWine", function () {

    this.timeout(100 * 1000)

    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        this.controller = await APWineController.new()
        await this.controller.initialize(owner)
        this.proxyFactory = await ProxyFactory.new()
        await this.controller.setAPWineProxyFactoryAddress(this.proxyFactory.address, {from:owner})
        this.apwineIBT = await APWineIBT.new()
        await this.controller.setAPWineIBTLogic(this.apwineIBT.address, {from:owner})
        this.fyt = await FutureYieldToken.new()
        await this.controller.setFutureYieldTokenLogic(this.fyt.address, {from:owner})
        this.maths = await APWineMaths.new()
    })

    it("has no vineyards available by default", async function () {
        expect(await this.controller.vineyardCount()).to.be.bignumber.equal(new BN(0))
    })


    describe("with APWineAave deployed", function () {

        beforeEach(async function () {
            await APWineAaveVineyard.detectNetwork()
            await APWineAaveVineyard.link("APWineMaths", this.maths.address)
            this.aaveWeeklyVineyard = await APWineAaveVineyard.new()
            await this.aaveWeeklyVineyard.initialize(this.controller.address, "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d", 7, "aDAI", "aDAI", owner)

            await APWineAaveCellar.detectNetwork()
            await APWineAaveCellar.link("APWineMaths", this.maths.address)
            this.aaveWeeklyCellar = await APWineAaveCellar.new()
            await this.aaveWeeklyCellar.initialize(this.aaveWeeklyVineyard.address,owner)

            this.aaveWeeklyFutureWallet = await APWineFutureWallet.new()
            await this.aaveWeeklyFutureWallet.initialize(this.aaveWeeklyVineyard.address)
            await this.controller.addVineyard(this.aaveWeeklyVineyard.address, {from:owner});
        })

        it("vineyard is registered in controller", async function () {
            expect(await this.controller.vineyard(0)).to.equal(this.aaveWeeklyVineyard.address)
        })

        it("has no registered balance by default", async function () {
            expect(await this.aaveWeeklyVineyard.getRegisteredAmount(user1)).to.be.bignumber.equal(new BN(0))
        })

        // need approve and positive balance
        // it("user can register", async function () {
        //     expect(await this.controller.register(this.aaveWeeklyVineyard.address,500))
        // })

    })

})
