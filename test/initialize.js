const { accounts } = require("@openzeppelin/test-environment")

const common = require("./common")
const { FUTURE_DEPLOYER_ROLE } = common
const { Controller, GaugeController, LiquidityGauge, Registry, Treasury, APWineMaths, APWineNaming, ProxyFactory, IBTFutureFactory, FutureYieldToken, APWineIBT } = common.contracts

const initializeCore = async function () {

    const [owner] = accounts

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
    await this.gaugeController.setEpochInflationRate(5000000000000000,{ from: owner } )
    await this.gaugeController.setEpochLength(60*60*24*365,{ from: owner } )

    await this.registry.setTreasury(this.treasury.address,{ from: owner })
    await this.registry.setController(this.controller.address,{ from: owner })
    await this.registry.setProxyFactory(this.proxyFactory.address,{ from: owner })
    await this.registry.setGaugeController(this.gaugeController.address,{ from: owner })

}

const initializeFutures = async function () {

    const [owner] = accounts

    await LiquidityGauge.detectNetwork()
    await LiquidityGauge.link("APWineMaths", this.maths.address)

    this.liquidityGaugeLogic = await LiquidityGauge.new()
    this.apwineIBTLogic = await APWineIBT.new()
    this.fytLogic = await FutureYieldToken.new()

    await this.registry.setLiquidityGaugeLogic(this.liquidityGaugeLogic.address, { from: owner });
    await this.registry.setAPWineIBTLogic(this.apwineIBTLogic.address, { from: owner });
    await this.registry.setFYTLogic(this.fytLogic.address, { from: owner });

    await IBTFutureFactory.detectNetwork()
    await IBTFutureFactory.link("APWineMaths", this.maths.address)

    this.ibtFutureFactory = await IBTFutureFactory.new()
    await this.ibtFutureFactory.initialize(this.controller.address, owner)
    await this.ibtFutureFactory.grantRole(FUTURE_DEPLOYER_ROLE, owner, { from: owner });

}

module.exports = { initializeCore, initializeFutures }