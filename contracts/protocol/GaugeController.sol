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

    mapping(address => uint256) internal redeemedByUser;
    mapping(address => uint256) internal userLiquidity;


    event LiquidityGaugeRegistered(address _future, address _newLiquidityGauge);
    event APWRedeemed(address _user, uint256 _amount);


    modifier isValidLiquidyGauge(){
        require(liquidityGauges.contains(msg.sender), "Incorrect liqudity gauge");
        _;
    }

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

    function claimAPW() public {
        uint256 totalRedeemable;
        for(uint256 i=0; i<liquidityGauges.length();i++){
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(liquidityGauges.at(i)).updateAndGetRedeemable(msg.sender));
        }
        uint256 actualRedeemable = totalRedeemable.sub(redeemedByUser[msg.sender]);
        require(actualRedeemable != 0, "User doesnt have any withdrawable APW");
        redeemedByUser[msg.sender] = redeemedByUser[msg.sender].add(actualRedeemable);
        apw.mint(msg.sender, actualRedeemable);
        emit APWRedeemed(msg.sender, actualRedeemable);
    }

    function claimAPW(address[] memory _liquidityGauges) public {
        uint256 totalRedeemable;
        for(uint256 i=0; i<_liquidityGauges.length;i++){
            require(liquidityGauges.contains(_liquidityGauges[i]), "invalid liquidity gauge addess");
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(_liquidityGauges[i]).updateAndGetRedeemable(msg.sender));
        }
        uint256 actualRedeemable = totalRedeemable.sub(redeemedByUser[msg.sender]);
        require(actualRedeemable != 0, "User doesnt have any withdrawable APW");
        redeemedByUser[msg.sender] = redeemedByUser[msg.sender].add(actualRedeemable);
        apw.mint(msg.sender, actualRedeemable);
        emit APWRedeemed(msg.sender, actualRedeemable);
    }

    function addUserRedeemable(address _user, uint256 _amount) public isValidLiquidyGauge{
        userLiquidity[_user] = userLiquidity[_user].add(_amount);
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

    function getUserRedeemableAPW(address _user) external view returns(uint256) {
        uint256 totalRedeemable;
        for(uint256 i=0; i<liquidityGauges.length();i++){
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(liquidityGauges.at(i)).getUserRedeemable(_user));
        }
       return totalRedeemable.sub(redeemedByUser[_user]);
    }


    /* Setters */
}
