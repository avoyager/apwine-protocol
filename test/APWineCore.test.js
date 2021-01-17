const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { Controller, GaugeController, LiquidityGauge, Registry, Treasury, APWineMaths, APWineNaming, ProxyFactory, IBTFutureFactory, AaveFuture, AaveFutureWallet, FutureVault, FutureYieldToken, APWineIBT } = common.contracts

const { initializeCore } = require("./initialize")

describe("APWine Contracts", function () {

    this.timeout(100 * 1000)
    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        await initializeCore.bind(this)()

    })

    it("Controller is correctly initialized", async function () {
        expect(await this.controller.getRegistryAddress()).to.equal(this.registry.address)
    })

})