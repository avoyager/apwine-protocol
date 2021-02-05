const { contract } = require("@openzeppelin/test-environment")
const { ethers, upgrades } = require("hardhat");



module.exports = {
    ADDRESS_0: "0x0000000000000000000000000000000000000000",
    AWETH_ADDRESS: "0x030bA81f1c18d280636F32af80b9AAd02Cf0854e",
    WETH_ADDRESS: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    ADAI_ADDRESS: "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d",
    YUSD_ADDRESS: "0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c",
    YDAI_ADDRESS: "0xC2cB1040220768554cf699b0d863A3cd4324ce32",
    FUTURE_DEPLOYER_ROLE: "0xdacd85ccbf3b93dd485a10886cc255d4fba1805ebed1521d0c405d4416eca3be",
    uniswapRouter: contract.fromABI(require("@uniswap/v2-periphery/build/IUniswapV2Router02.json").abi, undefined, "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"),
    DAY_TIME: 60 * 60 * 24,
}
