pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

import "contracts/interfaces/apwine/ILiquidityGauge.sol";
import "contracts/interfaces/apwine/tokens/IAPWToken.sol";
import "contracts/interfaces/apwine/IRegistry.sol";
import "contracts/interfaces/IProxyFactory.sol";

/**
 * @title Gauge Controller contract
 * @author Gaspard Peduzzi
 * @notice The Gauge Controller regulate the weight of the liquidity gauge and the emission of the APW token against liquidity provision
 */
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

    /**
     * @notice Intializer of the contract
     * @param _ADMIN the address of the admin of the contract
     * @param _registry the address of the registry
     */
    function initialize(address _ADMIN, address _registry) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _ADMIN);
        _setupRole(ADMIN_ROLE, _ADMIN);
        registry = IRegistry(_registry);
    }

    /**
     * @notice Deploy a new liquidity gauge for a newly created future and register in in the registry
     * @param _future the address of the new future
     * @return the address of the new liquidity gauge
     */
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

    /**
     * @notice Claim all claimable APW rewards for the sender
     * @dev not gas efficient, claim function with specified liquidity gauges saves gas
     */
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

    /**
     * @notice Claim all claimable APW rewards for the sender for a specified list of liquidity gauges
     * @param _liquidityGauges the the list of liquidity gauges to claim the rewards of
     */
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
    /**
     * @notice Getter for the inflation rate of the current epoch
     * @return the inflation rate of the current epoch
     */
    function getLastEpochInflationRate() external view returns (uint256) {
        return inflationRate;
    }

    /**
     * @notice Getter for weight of one gauge
     * @param _liquidityGauge the address of the liquidity gauge to get the weight of
     * @return the weight of the gauge
     */
    function getGaugeWeight(address _liquidityGauge) external view returns (uint256) {
        return gaugesWeights[_liquidityGauge];
    }

    /**
     * @notice Getter for duration of one epoch
     * @return the duration of one epoch
     */
    function getEpochLength() external view returns (uint256) {
        return epochLength;
    }

    /**
     * @notice Getter for duration of one epoch
     * @param _future the address of the future to check the liquidity gauge of
     * @return the address of the liquidity gauge of the future
     */
    function getLiquidityGaugeOfFuture(address _future) public view returns (address) {
        return futureGauges[_future];
    }

    /**
     * @notice Getter for the total redeemable APW of one user
     * @param _user the address of the user to get the redeemable APW of
     * @return the total amount of APW redeemable
     */
    function getUserRedeemableAPW(address _user) external view returns (uint256) {
        uint256 totalRedeemable;
        for (uint256 i = 0; i < liquidityGauges.length(); i++) {
            totalRedeemable = totalRedeemable.add(ILiquidityGauge(liquidityGauges.at(i)).getUserRedeemable(_user));
        }
        return totalRedeemable.sub(redeemedByUser[_user]);
    }

    /**
     * @notice Getter for the current state of rewards withdrawal availability
     * @return true if the users can withdraw their redeemable APW, false otherwise
     */
    function getWithdrawableState() external view returns (bool) {
        return isAPWClaimable;
    }

    /* Setters */

    /**
     * @notice Setter for the inflation rate of the epoch
     * @param _inflationRate the new inflation rate of the epoch
     */
    function setEpochInflationRate(uint256 _inflationRate) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        inflationRate = _inflationRate;
    }

    /**
     * @notice Setter for the weight of one liquidity gauge
     * @param _liquidityGauge the address of the liquidity gauge
     * @param _gaugeWeight the new weight of the liquidity gauge
     */
    function setGaugeWeight(address _liquidityGauge, uint256 _gaugeWeight) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        gaugesWeights[_liquidityGauge] = _gaugeWeight;
    }

    /**
     * @notice Setter for the length of the epochs
     * @param _epochLength the new length of the epochs
     */
    function setEpochLength(uint256 _epochLength) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        epochLength = _epochLength;
    }

    function setAPW(address _APW) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(address(apw) != address(0), "Token already set");
        apw = IAPWToken(_APW);
    }

    /**
     * @notice Admin function to pause APW whitdrawals
     */
    function pauseAPWWithdraw() public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isAPWClaimable, "apw rewards already paused");
        isAPWClaimable = false;
    }

    /**
     * @notice Admin function to resume APW whitdrawals
     */
    function resumeAPWWithdraw() public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(!isAPWClaimable, "apw rewards already resumed");
        isAPWClaimable = true;
    }
}
