const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat");


const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")

describe("APWine Utils", function () {

    this.timeout(100 * 1000)

    describe("APWineMaths", function () {
        beforeEach(async function () {
            const APWineMaths = await ethers.getContractFactory('APWineMaths');
            this.maths = await APWineMaths.deploy()
        })

        it("getScaledInput for 0 values", async function () {
            expect(await this.maths.getScaledInput(0, 0, 0)).to.equal(0)
        })

        it("getActualOutput for 0 values", async function () {
            expect(await this.maths.getActualOutput(0, 0, 0)).to.equal(0)
        })

        it("scaling of input is consistent", async function () {
            // Input 10 is first of sum, it doubles before second input of 10
            expect(await this.maths.getScaledInput(10, 10, 20)).to.equal(5)
        })

        it("scalling of output is consistent", async function () {
            // Input 10 is first of sum, it doubles before second input of 10
            expect(await this.maths.getActualOutput(5, 15, 30)).to.equal(10)
        })

    })

    describe("APWineNaming", function () {
        beforeEach(async function () {
            const APWineNaming = await ethers.getContractFactory('APWineNaming');
            this.naming = await APWineNaming.deploy()
        })
        it("Token Name generation works for corrects inputs", async function () {
            expect(await this.naming.genFYTSymbol(2, "ADAI", "AAVE", 60 * 60 * 24 * 30) == "30D-AAVE-ADAI-2");
        })

    })

})
