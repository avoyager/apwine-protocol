const { accounts, contract } = require("@openzeppelin/test-environment")
const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat");

const { BN, ether: amount, expectRevert, time, balance } = require("@openzeppelin/test-helpers")
const ether = require("@openzeppelin/test-helpers/src/ether")

const common = require("./common")
const { initializeCore } = require("./initialize")

describe("APWine Contracts", function () {

    this.timeout(100 * 1000)

    beforeEach(async function () {
        await initializeCore.bind(this)()

    })

    it("Controller is correctly initialized", async function () {
        expect(await this.controller.getRegistryAddress()).to.equal(this.registry.address)
    })

})