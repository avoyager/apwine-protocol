pragma solidity >=0.7.0 <0.8.0;

import "contracts/interfaces/apwine/IGaugeController.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract LiquidityGauge is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant FUTURE_ROLE = keccak256("FUTURE_ROLE");
    bytes32 public constant GAUGE_CONTROLLER_ROLE =
        keccak256("GAUGE_CONTROLLER_ROLE");

    IGaugeController private gaugeController;
    IFuture private future;

    uint256 private epochStart;
    uint256 private supplyStart;

    uint256[] internal newInflatedVolume;
    uint256[] internal totalDepositedSupply;
    uint256[] internal updatesTimestamp;

    mapping(address => uint256) private userRedeemTimestampIndex;
    mapping(address => uint256) private userLiquidityRegistered;
    mapping(address => uint256) internal liquidityRegistrations;
    mapping(address => uint256) internal userRedeemable;

    uint256[] internal periodsSwitchesIndexes;

    event LiquidityAdded(uint256 _amout, uint256 _current);
    event LiquidityRemoved(uint256 _amout, uint256 _current);
    event APWRedeemed(address _user, uint256 _amount);

    function initialize(address _gaugeController, address _future)
        public
        initializer
    {
        gaugeController = IGaugeController(_gaugeController);
        future = IFuture(_future);
        _setupRole(GAUGE_CONTROLLER_ROLE, _gaugeController);
        _setupRole(FUTURE_ROLE, _future);
        epochStart = block.timestamp;
    }

    function registerNewFutureLiquidity(uint256 _amount) public {
        require(_amount > 0, "Amount must not be zero");
        require(
            hasRole(FUTURE_ROLE, msg.sender),
            "Caller is not the corresponding future"
        );
        updateInflatedVolume();
        totalDepositedSupply[
            totalDepositedSupply.length - 1
        ] = totalDepositedSupply[totalDepositedSupply.length - 1].add(_amount);
        emit LiquidityAdded(
            _amount,
            totalDepositedSupply[totalDepositedSupply.length - 1]
        );
    }

    function unregisterFutureLiquidity(uint256 _amount) public {
        require(_amount > 0, "Amount must not be zero");
        require(
            hasRole(FUTURE_ROLE, msg.sender),
            "Caller is not the corresponding future"
        );
        updateInflatedVolume();
        totalDepositedSupply[
            totalDepositedSupply.length - 1
        ] = totalDepositedSupply[totalDepositedSupply.length - 1].sub(_amount);
        emit LiquidityRemoved(
            _amount,
            totalDepositedSupply[totalDepositedSupply.length - 1]
        );
    }

    function redeemAPW(address _user) public {
        updateInflatedVolume();
        updateUserLiquidity(_user);
        uint256 redeemable = userRedeemable[_user];
        require(redeemable != 0, "User doesnt have any withdrawable APW atm");
        gaugeController.mint(_user, redeemable);
        userRedeemable[_user] = 0;
        emit APWRedeemed(_user, redeemable);
    }

    function updateInflatedVolume() public {
        newInflatedVolume.push(getLastInflatedAmount());
        updatesTimestamp.push(block.timestamp);
        totalDepositedSupply.push(
            totalDepositedSupply[totalDepositedSupply.length - 1]
        );
    }

    function getLastInflatedAmount() public view returns (uint256) {
        return
            (
                (gaugeController.getLastEpochInflationRate().mul(supplyStart))
                    .mul(
                    block.timestamp.sub(
                        updatesTimestamp[updatesTimestamp.length - 1]
                    )
                )
                    .mul(gaugeController.getGaugeWeight())
                    .mul(gaugeController.getGaugeTypeWeight())
            )
                .div(gaugeController.getEpochLength());
    }

    function getUserRedeemable(address _user) external view returns (uint256) {
        return
            _getRedeemableLiquidityRegistrationOnly(_user)
                .add(_getUserNewRedeemable(_user))
                .add(userLiquidityRegistered[_user]);
    }

    function _getUserNewRedeemable(address _user)
        internal
        view
        returns (uint256)
    {
        if (userRedeemTimestampIndex[_user] == 0) return 0;
        uint256 redeemable;
        uint256 liquidityRegistered = userLiquidityRegistered[_user];
        for (
            uint256 i = userRedeemTimestampIndex[_user];
            i < updatesTimestamp.length;
            i++
        ) {
            redeemable = redeemable.add(
                (newInflatedVolume[i].mul(liquidityRegistered)).div(
                    totalDepositedSupply[i]
                )
            );
        }
        return redeemable;
    }

    function _getRedeemableLiquidityRegistrationOnly(address _user)
        internal
        view
        returns (uint256)
    {
        if (!hasActiveLiquidityRegistraiton(_user)) return 0;
        uint256 redeemable;
        uint256 claimableLiquidity = future.getClaimableAPWIBT(_user);
        for (
            uint256 i = periodsSwitchesIndexes[liquidityRegistrations[_user]];
            i < totalDepositedSupply.length;
            i++
        ) {
            redeemable = redeemable.add(
                (newInflatedVolume[i].mul(claimableLiquidity)).div(
                    totalDepositedSupply[i]
                )
            );
        }
        return redeemable;
    }

    function registerUserLiquidity(address _user) public {
        require(
            hasRole(FUTURE_ROLE, msg.sender),
            "Caller is not the corresponding future"
        );
        if (liquidityRegistrations[_user] == future.getNextPeriodIndex())
            return; // return if registration already done
        updateUserLiquidity(_user);
        liquidityRegistrations[_user] = future.getNextPeriodIndex(); // append registration for next future
    }

    function unregisterUserLiquidity(address _user) public {
        require(
            hasRole(FUTURE_ROLE, msg.sender),
            "Caller is not the corresponding future"
        );
        if (liquidityRegistrations[_user] == future.getNextPeriodIndex()) {
            delete liquidityRegistrations[_user];
        } // return if registration already done
        updateUserLiquidity(_user);
    }

    function hasActiveLiquidityRegistraiton(address _user)
        internal
        view
        returns (bool)
    {
        if (
            liquidityRegistrations[_user] < future.getNextPeriodIndex() ||
            liquidityRegistrations[_user] != 0
        ) return true;
        return false;
    }

    function updateUserLiquidity(address _user) internal {
        if (hasActiveLiquidityRegistraiton(_user)) {
            redeemLiquidityRegistration(_user);
        } else {
            uint256 newReedamble = _getUserNewRedeemable(_user);
            if (newReedamble == 0) return;
            userRedeemTimestampIndex[_user] = updatesTimestamp.length - 1;
            userRedeemable[_user] = userRedeemable[_user].add(newReedamble);
        }
    }

    function redeemLiquidityRegistration(address _user) internal {
        uint256 redeemable = _getRedeemableLiquidityRegistrationOnly(_user);
        require(redeemable != 0, "no active registration");
        if (userRedeemTimestampIndex[_user] != 0) {
            redeemable = redeemable.add(_getUserNewRedeemable(_user));
        }
        userRedeemTimestampIndex[_user] = updatesTimestamp.length - 1;
        userRedeemable[_user] = userRedeemable[_user].add(redeemable);
        delete liquidityRegistrations[_user];
    }
}
