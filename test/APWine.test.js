const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")

const APWineController = contract.fromArtifact("APWineController")
const APWineAaveVineyard = contract.fromArtifact("APWineAaveVineyard")
const APWineMaths = contract.fromArtifact("APWineMaths")

const ADDRESS_0 = "0x0000000000000000000000000000000000000000"

describe("APWine", function () {

    this.timeout(100 * 1000)

    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        this.controller = await APWineController.new()
        this.controller.initialize(owner)

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
            this.aaveWeeklyVineyard.initialize(this.controller.address, "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d", 7, "aDAI", "aDAI", owner)
        })

        it("has no registered balance by default", async function () {
            expect(await this.aaveWeeklyVineyard.getRegisteredAmount(user1)).to.be.bignumber.equal(new BN(0))
        })

    })

})
