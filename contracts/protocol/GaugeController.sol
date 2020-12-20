pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "contracts/interfaces/apwine/ILiquidityGauge.sol";
import "contracts/interfaces/apwine/tokens/IAPWToken.sol";
import "contracts/interfaces/apwine/IRegistry.sol";
import "contracts/interfaces/IProxyFactory.sol";

contract GaugeController is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 private inflationRate;
    uint256 private initialSupply;
    uint256 private epochLength;

    mapping(address => uint256) private gaugesWeights;
    mapping(address => uint256) private gaugeTypesWeights;
    mapping(address => address) private futureGauges;

    uint256[] private totalsFactors;

    /* Addresses */
    EnumerableSetUpgradeable.AddressSet private liquidityGauges;
    IAPWToken private apw;
    IRegistry registery;

    event LiquidityGaugeRegistered(address _future, address _newLiquidityGauge);

    function initialize(
        address _ADMIN,
        address _APW,
        address _registry
    ) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _ADMIN);
        _setupRole(ADMIN_ROLE, _ADMIN);
        registery = IRegistry(_registry);
        apw = IAPWToken(_APW);
    }

    function registerNewGauge(address _future) public returns (address) {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not the DAO");
        address newLiquidityGauge = deployLiquidityGauge(_future);
        futureGauges[_future] = newLiquidityGauge;
        emit LiquidityGaugeRegistered(_future, newLiquidityGauge);
        return newLiquidityGauge;
    }

    function deployLiquidityGauge(address _future) internal returns (address) {
        bytes memory payload = abi.encodeWithSignature("initialize(address,address)", address(this), _future);
        ILiquidityGauge newLiquidityGauge =
            ILiquidityGauge(
                IProxyFactory(registery.getProxyFactoryAddress()).deployMinimal(
                    registery.getLiquidityGaugeLogicAddress(),
                    payload
                )
            );
        return address(newLiquidityGauge);
    }

    function claimAPW(address _future) public {
        // last fyt claimed -now,
        address liquidityGauge = futureGauges[_future];
        require(liquidityGauges.contains(liquidityGauge), "Incorrect future address");
        ILiquidityGauge(liquidityGauge).redeemAPW(msg.sender);
    }

    function mint(address _user, uint256 _amount) external {
        address liquidityGauge = futureGauges[msg.sender];
        require(liquidityGauges.contains(liquidityGauge), "Incorrect future address");
        apw.mint(_user, _amount);
    }

    /* Getters */
    function getLastEpochInflationRate() external view returns (uint256) {
        return inflationRate;
    }

    function getGaugeWeight(address _liquidityGauge) external view returns (uint256) {
        return gaugesWeights[_liquidityGauge];
    }

    function getGaugeTypeWeight(address _liquidityGauge) external view returns (uint256) {
        return gaugeTypesWeights[_liquidityGauge]; // TODO Change with enum etc
    }

    function getEpochLength() external view returns (uint256) {
        return epochLength;
    }

    /* Setters */
}
