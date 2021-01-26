const { deployProxy } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

const common = require("./common")
const { Controller, GaugeController, LiquidityGauge, Registry, Treasury, APWineMaths, APWineNaming, ProxyFactory, IBTFutureFactory, FutureYieldToken, APWineIBT } = common.contracts
const { admin_address, ADAI_Address,EPOCH_LENGTH,INITIAL_INFLATION_RATE} = common;
const team_wallet = require("./common").gnosisSafe;


module.exports = async function (deployer) {

    /* Libraries*/
    const apwineMaths = await APWineMaths.new();
    const apwineNaming = await APWineNaming.new();

    /* Deploy and initialize core contracts */
    const registry = await deployProxy(Registry, [admin_address], { deployer,unsafeAllowCustomTypes:true});
    const controller = await deployProxy(Controller, [admin_address, registry.address], { deployer,unsafeAllowCustomTypes:true});
    const gaugeController = await deployProxy(GaugeController, [admin_address, registry.address], { deployer,unsafeAllowCustomTypes:true});
    const treasury = await deployProxy(Treasury, [admin_address], { deployer,unsafeAllowCustomTypes:true});

    /* Deploy main logic contracts */  
    const apwineIBTLogic = await deployer.deploy(APWineIBT);
    const fytLogic = await deployer.deploy(FutureYieldToken);
    const liquidityGaugeLogic = await deployer.deploy(LiquidityGauge);
    const proxyFactory = await deployer.deploy(ProxyFactory);

    /* Set addresses in registry */
    await registry.setTreasury(treasury.address);
    await registry.setGaugeController(gaugeController.address);
    await registry.setController(controller.address);
    //await registry.setAPW(apw.address);

    await registry.setProxyFactory(proxyFactory.address);
    await registry.setLiquidityGaugeLogic(liquidityGaugeLogic.address);
    await registry.setAPWineIBTLogic(apwineIBTLogic.address);
    await registry.setFYTLogic(fytLogic.address);

    await registry.setMathsUtils(apwineMaths.address)
    await registry.setNamingUtils(apwineNaming.address)

    await gaugeController.setEpochInflationRate(INITIAL_INFLATION_RATE)
    await gaugeController.setEpochLength(EPOCH_LENGTH)

}