const { contract } = require("@openzeppelin/test-environment")


module.exports = {
    contracts: {
        // Core Protocol
        Controller: contract.fromArtifact('Controller'),
        GaugeController: contract.fromArtifact('GaugeController'),
        LiquidityGauge: contract.fromArtifact('LiquidityGauge'),
        Registry: contract.fromArtifact('Registry'),
        Treasury: contract.fromArtifact('Treasury'),

        // Libraries
        APWineMaths: contract.fromArtifact('APWineMaths'),
        APWineNaming: contract.fromArtifact('APWineNaming'),

        ProxyFactory: contract.fromArtifact('ProxyFactory'),

        // Future
        IBTFutureFactory: contract.fromArtifact('IBTFutureFactory'),

        // Future Platform
        AaveFuture: contract.fromArtifact('AaveFuture'),
        AaveFutureWallet: contract.fromArtifact('AaveFutureWallet'),
        FutureVault: contract.fromArtifact('FutureVault'),
        FutureYieldToken: contract.fromArtifact('FutureYieldToken'),
        APWineIBT: contract.fromArtifact('APWineIBT'),
    },
    ADDRESS_0: "0x0000000000000000000000000000000000000000",
    AWETH_ADDRESS: "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e",
    ADAI_ADDRESS:"0x028171bca77440897b824ca71d1c56cac55b68a3",
    YUSD_ADDRESS: "0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c",
    YDAI_ADDRESS:"0xC2cB1040220768554cf699b0d863A3cd4324ce32",
    FUTURE_DEPLOYER_ROLE: "0xdacd85ccbf3b93dd485a10886cc255d4fba1805ebed1521d0c405d4416eca3be",
    adai: contract.fromArtifact("ERC20", ADAI_ADDRESS),
    uniswapRouter: contract.fromABI(require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, undefined, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
}
