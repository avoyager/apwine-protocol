module.exports = {
    admin_address : process.env.PUBLIC_ADRESS,
    gnosisSafe: "0xca67f76BcCce3f856FcD38825E3aFC43386ec806",
    ADAI_Address : "0xdcf0af9e59c002fa3aa091a46196b37530fd48a8",
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