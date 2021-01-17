const { contract } = require("@openzeppelin/test-environment")

const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"

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
    WETH_ADDRESS: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    ADAI_ADDRESS,
    FUTURE_DEPLOYER_ROLE: "0xdacd85ccbf3b93dd485a10886cc255d4fba1805ebed1521d0c405d4416eca3be",
    adai: contract.fromArtifact("ERC20", ADAI_ADDRESS),
    uniswapRouter: contract.fromABI(require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, undefined, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D")
}
