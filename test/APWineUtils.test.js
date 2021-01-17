const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { APWineMaths, APWineNaming } = common.contracts

describe("APWine Utils", function () {

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

        it("scaling of input is consistent", async function () {
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
