module.exports = {
    admin_address : process.env.PUBLIC_ADRESS,
    gnosisSafe: "0xca67f76BcCce3f856FcD38825E3aFC43386ec806",
    AWETH_ADDRESS: "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e",
    ADAI_ADDRESS:"0x028171bca77440897b824ca71d1c56cac55b68a3",
    YUSD_ADDRESS: "0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c",
    YDAI_ADDRESS:"0xC2cB1040220768554cf699b0d863A3cd4324ce32",
    EPOCH_LENGTH : 60*60*24*365,
    INITIAL_INFLATION_RATE: 5000000000000000,  
    DAY: 60*60*24,

    // Core Protocol
    contracts:{
        Controller : artifacts.require('Controller'),
        GaugeController : artifacts.require('GaugeController'),
        LiquidityGauge : artifacts.require('LiquidityGauge'),
        Registry : artifacts.require('Registry'),
        Treasury : artifacts.require('Treasury'),

        ProxyFactory : artifacts.require('ProxyFactory'),

        // Utils
        APWineMaths : artifacts.require('APWineMaths'),
        APWineNaming : artifacts.require('APWineNaming'),

        // Future
        IBTFutureFactory : artifacts.require('IBTFutureFactory'),
        FutureYieldToken : artifacts.require('FutureYieldToken'),
        APWineIBT : artifacts.require('APWineIBT'),

        // Future Platform
        AaveFuture : artifacts.require('AaveFuture'),
        AaveFutureWallet : artifacts.require('AaveFutureWallet'),
        FutureVault : artifacts.require('FutureVault')
    }
}