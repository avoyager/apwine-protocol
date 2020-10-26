const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")

const APWineController = contract.fromArtifact("APWineController")
const APWineProxy = contract.fromArtifact("APWineProxy")
const FutureYieldTokenFactory = contract.fromArtifact("FutureYieldTokenFactory")
const APWineCompound = contract.fromArtifact("APWineCompound")
const APWineAave = contract.fromArtifact("APWineAave")

const ERC20 = contract.fromArtifact("@openzeppelin/contracts/ERC20PresetMinterPauser")

const ADDRESS_0 = "0x0000000000000000000000000000000000000000"

describe("APWine", function () {
    const [owner, user1, user2] = accounts

    beforeEach(async function () {
        this.controller = await APWineController.new()
        this.tokenFactory = await FutureYieldTokenFactory.new()

        // Deploy Compound
        this.compToken = await ERC20.new("COMP", "COMP")
        this.cdaiToken = await ERC20.new("CDAI", "CDAI")
        this.compoundWeekly = await APWineCompound.new(this.controller.address, this.tokenFactory.address, this.compToken.address, "Compound Weekly", 7)
        //TODO: refactor APWineCompound, APWineAave initializers to take platforms addresses instead of hardcoded values
        await this.controller.addFuture(this.compoundWeekly.address)

        // Deploy Aave
        /*this.aaveWeekly = await APWineAave.new()*/
    })

    it("has registered futures correctly", async function () {
        expect(await this.controller.futuresCount()).to.be.bignumber.equal(new BN(1))
        expect(await this.controller.future(0)).to.be.equal(this.compoundWeekly.address)
    })

    it("has no proxy set up by default", async function () {
        const proxy = await this.controller.proxiesByUser(user1)
        expect(proxy).to.be.equal(ADDRESS_0)
    })

    it("creates a proxy successfully", async function () {
        await this.controller.createProxy({ from: user1 })
        expect(await this.controller.proxiesByUser(user1)).to.not.be.equal(ADDRESS_0)
    })

    it("can't create proxy twice", async function () {
        await this.controller.createProxy({ from: user1 })
        expectRevert(this.controller.createProxy({ from: user1 }), "User already has proxy")
    })

    describe("with proxies set up, and initial user token balance", function () {

        beforeEach(async function () {
            await this.controller.createProxy({ from: user1 })
            await this.controller.createProxy({ from: user2 })
            this.proxy1 = await APWineProxy.at(await this.controller.proxiesByUser(user1))
            this.proxy2 = await APWineProxy.at(await this.controller.proxiesByUser(user2))
            await this.cdaiToken.mint(user1, amount("1000"))
            await this.cdaiToken.mint(user2, amount("1000"))
        })

        it("can send tokens to a proxy", async function () {
            await this.cdaiToken.transfer(this.proxy1.address, amount("10"), { from: user1 })
            expect(await this.cdaiToken.balanceOf(this.proxy1.address)).to.be.bignumber.equal(amount("10"))
        })

        describe("with initial proxy token balance", function () {
            
            beforeEach(async function () {
                await this.cdaiToken.transfer(await this.controller.proxiesByUser(user1), amount("10"), { from: user1 })
                await this.cdaiToken.transfer(await this.controller.proxiesByUser(user2), amount("20"), { from: user2 })
            })

            it("doesn't let other users interact with the proxy", async function () {
                expectRevert(this.proxy1.withdraw(this.cdaiToken.address, amount("10"), { from: user2 }), "Caller is not owner")
            })

            it("can't withdraw more tokens than proxy balance", async function () {
                expectRevert(this.proxy1.withdraw(this.cdaiToken.address, amount("11"), { from: user1 }), "Insufficient funds")
            })

            it("can withdraw tokens from proxy", async function () {
                const cdaiBalance = await this.cdaiToken.balanceOf(user1)
                await this.proxy1.withdraw(this.cdaiToken.address, amount("10"), { from: user1 })
                expect(await this.cdaiToken.balanceOf(user1)).to.be.bignumber.equal(cdaiBalance.add(amount("10")))
            })

        })

    })

})
