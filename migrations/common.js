module.exports = {
    admin_address : process.env.PUBLIC_ADRESS,
    gnosisSafe: "0xca67f76BcCce3f856FcD38825E3aFC43386ec806",
    AWETH_ADDRESS: "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e",
    ADAI_ADDRESS:"0xdcf0af9e59c002fa3aa091a46196b37530fd48a8",
    YUSD_ADDRESS: "0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c",
    YDAI_ADDRESS:"0xC2cB1040220768554cf699b0d863A3cd4324ce32",
    EPOCH_LENGTH : 60*60*24*365,
    INITIAL_INFLATION_RATE: 5000000000000000,  
    DAY: 60*60*24,
    FUTURE_DEPLOYER_ROLE: "0xdacd85ccbf3b93dd485a10886cc255d4fba1805ebed1521d0c405d4416eca3be",
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