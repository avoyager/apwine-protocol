pragma solidity >=0.7.0 <0.8.0;

import "contracts/interfaces/apwine/IGaugeController.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "contracts/interfaces/apwine/tokens/IAPWineIBT.sol";

/**
 * @title Liquidity Gauge Contract
 * @author Gaspard Peduzzi
 * @notice The liquidity gauge is deployed at the creation of the future and track user liquidity provision
 */
contract LiquidityGauge is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant FUTURE_ROLE = keccak256("FUTURE_ROLE");
    bytes32 public constant GAUGE_CONTROLLER_ROLE = keccak256("GAUGE_CONTROLLER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    IGaugeController private gaugeController;
    IFuture private future;
    IAPWineIBT private apwibt;

    uint256 private epochStart;
    uint256 private supplyStart;

    uint256[] internal newInflatedVolume;
    uint256[] internal totalDepositedSupply;
    uint256[] internal updatesTimestamp;

    mapping(address => uint256) internal userRedeemTimestampIndex;
    mapping(address => uint256) internal userLiquidityCollected;

    mapping(address => uint256) internal liquidityRegistrationsPeriodIndex;
    mapping(address => uint256) internal lastLiquidityAmountRecorded;

    uint256[] internal periodsSwitchesIndexes;
    mapping(address => uint256) internal userRedeemable;

    event LiquidityAdded(uint256 _amout, uint256 _current);
    event LiquidityRemoved(uint256 _amout, uint256 _current);

    /**
     * @notice Contract Initializer
     * @param _gaugeController the address of the gauge controller
     * @param _future the address of the corresponding future
     */
    function initialize(address _gaugeController, address _future) public initializer {
        gaugeController = IGaugeController(_gaugeController);
        future = IFuture(_future);
        apwibt = IAPWineIBT(future.getIBTAddress());
        _setupRole(GAUGE_CONTROLLER_ROLE, _gaugeController);
        _setupRole(FUTURE_ROLE, _future);
        epochStart = block.timestamp;
        newInflatedVolume.push(0);
        updatesTimestamp.push(epochStart);
        totalDepositedSupply.push(0);
    }

    /**
     * @notice Register new liquidity added to the future
     * @param _amount the liquidity amount added
     * @dev must be called from the future contract
     */
    function registerNewFutureLiquidity(uint256 _amount) public {
        require(hasRole(FUTURE_ROLE, msg.sender), "Caller is not the corresponding future");
        updateInflatedVolume();
        totalDepositedSupply[totalDepositedSupply.length - 1] = totalDepositedSupply[totalDepositedSupply.length - 1].add(
            _amount
        );
        periodsSwitchesIndexes.push(totalDepositedSupply.length-1);
        emit LiquidityAdded(_amount, totalDepositedSupply[totalDepositedSupply.length - 1]);
    }

    /**
     * @notice Unregister liquidity withdrawn from to the future
     * @param _amount the liquidity amount withdrawn
     * @dev must be called from the future contract
     */
    function unregisterFutureLiquidity(uint256 _amount) public {
        require(_amount > 0, "Amount must not be zero");
        require(hasRole(FUTURE_ROLE, msg.sender), "Caller is not the corresponding future");
        updateInflatedVolume();
        totalDepositedSupply[totalDepositedSupply.length - 1] = totalDepositedSupply[totalDepositedSupply.length - 1].sub(
            _amount
        );
        emit LiquidityRemoved(_amount, totalDepositedSupply[totalDepositedSupply.length - 1]);
    }

    /**
     * @notice update gauge and user liquidity state then return the new redeemable
     * @param _user the user to who update and return the redeemable of
     */
    function updateAndGetRedeemable(address _user) public returns (uint256) {
        updateUserLiquidity(_user);
        return userLiquidityCollected[_user];
    }

    /**
     * @notice Log an update of the inflated volume
     */
    function updateInflatedVolume() public {
        newInflatedVolume.push(getLastInflatedAmount());
        updatesTimestamp.push(block.timestamp);
        totalDepositedSupply.push(totalDepositedSupply[totalDepositedSupply.length - 1]);
    }

    /**
     * @notice Getter fot the last inflated amount
     * @return the last inflated amount
     */
    function getLastInflatedAmount() public view returns (uint256) {
        return
            (
                (gaugeController.getLastEpochInflationRate().mul(supplyStart))
                    .mul(block.timestamp.sub(updatesTimestamp[updatesTimestamp.length - 1]))
                    .mul(gaugeController.getGaugeWeight(address(this)))
            )
                .div(gaugeController.getEpochLength());
    }

    /**
     * @notice Getter for redeemable APWs of one user
     * @param _user the user to check the redeemable APW of
     * @return the amount of redeemable APW
     */
    function getUserRedeemable(address _user) external view returns (uint256) {
        return _getRedeemableLiquidityRegistrationOnly(_user).add(_getUserNewRedeemable(_user));
    }

    function _getUserNewRedeemable(address _user) internal view returns (uint256) {
        if (userRedeemTimestampIndex[_user] == 0) return 0;
        uint256 redeemable;
        uint256 userLiquidity = apwibt.balanceOf(_user);
        for (uint256 i = userRedeemTimestampIndex[_user]; i < updatesTimestamp.length; i++) {
            redeemable = redeemable.add((newInflatedVolume[i].mul(userLiquidity)).div(totalDepositedSupply[i]));
        }
        return redeemable;
    }

    function _getRedeemableLiquidityRegistrationOnly(address _user) internal view returns (uint256) {
        if (!hasActiveLiquidityRegistraiton(_user)) return 0;
        uint256 redeemable;
        uint256 newLiquidity = apwibt.balanceOf(_user).sub(lastLiquidityAmountRecorded[_user]);
        for (
            uint256 i = periodsSwitchesIndexes[liquidityRegistrationsPeriodIndex[_user]];
            i < totalDepositedSupply.length;
            i++
        ) {
            redeemable = redeemable.add((newInflatedVolume[i].mul(newLiquidity)).div(totalDepositedSupply[i]));
        }
        return redeemable;
    }

    /**
     * @notice Register new user liquidity
     * @param _user the user to register the liquidity of
     */
    function registerUserLiquidity(address _user) public {
        require(hasRole(FUTURE_ROLE, msg.sender), "Caller is not the corresponding future");
        if (liquidityRegistrationsPeriodIndex[_user] == future.getNextPeriodIndex()) return; // return if registration already done
        updateUserLiquidity(_user);
        liquidityRegistrationsPeriodIndex[_user] = future.getNextPeriodIndex(); // append registration for next future
    }

    /**
     * @notice Delete a user liquidity registration
     * @param _user the user to delete the liquidity registration of
     */
    function deleteUserLiquidityRegistration(address _user) public {
        require(hasRole(FUTURE_ROLE, msg.sender), "Caller is not the corresponding future");
        assert(liquidityRegistrationsPeriodIndex[_user] == future.getNextPeriodIndex());
        delete liquidityRegistrationsPeriodIndex[_user];
    }

    /**
     * @notice Remove liquidity from on user address
     * @param _user the user to remove the liquidity from
     * @param _amount the amount of liquidity to remove
     */
    function removeUserLiquidity(address _user, uint256 _amount) public {
        require(hasRole(FUTURE_ROLE, msg.sender), "Caller is not the corresponding future");
        updateUserLiquidity(_user);
        assert(lastLiquidityAmountRecorded[_user] >= _amount);
        lastLiquidityAmountRecorded[_user] = lastLiquidityAmountRecorded[_user].sub(_amount);
        unregisterFutureLiquidity(_amount);
    }

    /**
     * @notice Register new user liquidity
     * @param _sender the user to transfer the liquidity from
     * @param _receiver the user to transfer the liquidity to
     * @param _amount the amount of liquditiy to transfer
     */
    function transferUserLiquidty(
        address _sender,
        address _receiver,
        uint256 _amount
    ) public {
        require(hasRole(TRANSFER_ROLE, msg.sender), "Caller cannot transfer liquidity");
        updateInflatedVolume();
        _updateUserLiquidity(_sender);
        _updateUserLiquidity(_receiver);
        lastLiquidityAmountRecorded[_sender] = lastLiquidityAmountRecorded[_sender].sub(_amount);
        lastLiquidityAmountRecorded[_receiver] = lastLiquidityAmountRecorded[_receiver].add(_amount);
    }

    function hasActiveLiquidityRegistraiton(address _user) internal view returns (bool) {
        if (
            liquidityRegistrationsPeriodIndex[_user] < future.getNextPeriodIndex() &&
            liquidityRegistrationsPeriodIndex[_user] != 0
        ) return true;
        return false;
    }

    /**
     * @notice Update the current stored liquidity of one user
     * @param _user the user to update the liquidity of
     */
    function updateUserLiquidity(address _user) public {
        updateInflatedVolume();
        _updateUserLiquidity(_user);
    }

    function _updateUserLiquidity(address _user) internal {
        if (hasActiveLiquidityRegistraiton(_user)) {
            redeemLiquidityRegistration(_user);
        } else {
            uint256 newReedamble = _getUserNewRedeemable(_user);
            if (newReedamble == 0) return;
            userRedeemTimestampIndex[_user] = updatesTimestamp.length - 1;
            userLiquidityCollected[_user] = userLiquidityCollected[_user].add(newReedamble);
        }
        lastLiquidityAmountRecorded[_user] = apwibt.balanceOf(_user);
    }

    function redeemLiquidityRegistration(address _user) internal {
        // update registration and current liquidity counter
        uint256 registered = _getRedeemableLiquidityRegistrationOnly(_user);
        require(registered != 0, "no active registration");
        if (userRedeemTimestampIndex[_user] != 0) {
            registered = registered.add(_getUserNewRedeemable(_user));
        }
        userRedeemTimestampIndex[_user] = updatesTimestamp.length - 1;
        delete liquidityRegistrationsPeriodIndex[_user];
    }
}
