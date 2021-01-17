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

    bool private isAPWClaimable;

    mapping(address => uint256) private gaugesWeights;
    mapping(address => address) private futureGauges;

    uint256[] private totalsFactors;

    /* Addresses */
    EnumerableSetUpgradeable.AddressSet private liquidityGauges;
    IAPWToken private apw;
    IRegistry registry;

    mapping(address => uint256) internal redeemedByUser;
    mapping(address => uint256) internal userLiquidity;

    event LiquidityGaugeRegistered(address _future, address _newLiquidityGauge);
    event APWRedeemed(address _user, uint256 _amount);

    modifier isValidLiquidyGauge() {
        require(liquidityGauges.contains(msg.sender), "Incorrect liqudity gauge");
        _;
    }

    function initialize(address _ADMIN, address _registry) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _ADMIN);
        _setupRole(ADMIN_ROLE, _ADMIN);
        registry = IRegistry(_registry);
    }

    function registerNewGauge(address _future) public returns (address) {
        require(registry.isRegisteredFutureFactory(msg.sender), "incorrect future factory address");
        address newLiquidityGauge = deployLiquidityGauge(_future);
        futureGauges[_future] = newLiquidityGauge;
        emit LiquidityGaugeRegistered(_future, newLiquidityGauge);
        return newLiquidityGauge;
    }

    function deployLiquidityGauge(address _future) internal returns (address) {
        bytes memory payload = abi.encodeWithSignature("initialize(address,address)", address(this), _future);
        ILiquidityGauge newLiquidityGauge =
            ILiquidityGauge(
                IProxyFactory(registry.getProxyFactoryAddress()).deployMinimal(
                    registry.getLiquidityGaugeLogicAddress(),
                    payload
                )
            );
        return address(newLiquidityGauge);
    }

    function claimAPW() public {
        require(isAPWClaimable, "apw rewards not claimable atm");
        uint256 totalRedeemable;
        for (uint256 i = 0; i < liquidityGauges.length(); i++) {
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(liquidityGauges.at(i)).updateAndGetRedeemable(msg.sender));
        }
        uint256 actualRedeemable = totalRedeemable.sub(redeemedByUser[msg.sender]);
        require(actualRedeemable != 0, "User doesnt have any withdrawable APW");
        redeemedByUser[msg.sender] = redeemedByUser[msg.sender].add(actualRedeemable);
        apw.mint(msg.sender, actualRedeemable);
        emit APWRedeemed(msg.sender, actualRedeemable);
    }

    function claimAPW(address[] memory _liquidityGauges) public {
        require(isAPWClaimable, "apw rewards not claimable atm");
        uint256 totalRedeemable;
        for (uint256 i = 0; i < _liquidityGauges.length; i++) {
            require(liquidityGauges.contains(_liquidityGauges[i]), "invalid liquidity gauge addess");
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(_liquidityGauges[i]).updateAndGetRedeemable(msg.sender));
        }
        uint256 actualRedeemable = totalRedeemable.sub(redeemedByUser[msg.sender]);
        require(actualRedeemable != 0, "User doesnt have any withdrawable APW");
        redeemedByUser[msg.sender] = redeemedByUser[msg.sender].add(actualRedeemable);
        apw.mint(msg.sender, actualRedeemable);
        emit APWRedeemed(msg.sender, actualRedeemable);
    }

    /* Getters */
    function getLastEpochInflationRate() external view returns (uint256) {
        return inflationRate;
    }

    function getGaugeWeight(address _liquidityGauge) external view returns (uint256) {
        return gaugesWeights[_liquidityGauge];
    }

    function getEpochLength() external view returns (uint256) {
        return epochLength;
    }

    function getLiquidityGaugeOfFuture(address _future) public view returns (address) {
        return futureGauges[_future];
    }

    function getUserRedeemableAPW(address _user) external view returns (uint256) {
        uint256 totalRedeemable;
        for (uint256 i = 0; i < liquidityGauges.length(); i++) {
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(liquidityGauges.at(i)).getUserRedeemable(_user));
        }
        return totalRedeemable.sub(redeemedByUser[_user]);
    }

    function getWithdrawableState() external view returns (bool) {
        return isAPWClaimable;
    }

    /* Setters */

    function setEpochInflationRate(uint256 _inflationRate) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        inflationRate = _inflationRate;
    }

    function setGaugeWeight(address _liquidityGauge, uint256 _gaugeWeight) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        gaugesWeights[_liquidityGauge] = _gaugeWeight;
    }

    function setEpochLength(uint256 _epochLength) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        epochLength = _epochLength;
    }

    function setAPW(address _APW) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(address(apw) != address(0), "Token already set");
        apw = IAPWToken(_APW);
    }

    function pauseAPWWithdraw() public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isAPWClaimable, "apw rewards already paused");
        isAPWClaimable = false;
    }

    function resumeAPWWithdraw() public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(!isAPWClaimable, "apw rewards already resumed");
        isAPWClaimable = true;
    }
}
