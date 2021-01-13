pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "contracts/protocol/futures/Future.sol";

abstract contract RateFuture is Future {
    using SafeMathUpgradeable for uint256;

    uint256[] private IBTRates;

    function initialize(
        address _controllerAddress,
        address _ibt,
        uint256 _periodLength,
        string memory _platform,
        address _deployerAddress,
        address _adminAddress
    ) public virtual override initializer {
        super.initialize(_controllerAddress, _ibt, _periodLength, _platform, _deployerAddress, _adminAddress);
        IBTRates.push();
        IBTRates.push();
    }

    function unregister(address _user, uint256 _amount) public virtual override {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to unregister");

        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[_user].startIndex == nextIndex, "The is not ongoing registration for the next period");

        uint256 currentRegistered = registrations[_user].scaledBalance;
        uint256 toRefund;

        if (_amount == 0){
            require(currentRegistered >= 0, "Invalid amount to unregister");
            delete registrations[_user];
            toRefund = currentRegistered;
        }else{
            require(currentRegistered >= _amount, "Invalid amount to unregister");
            registrations[_user].scaledBalance = registrations[_user].scaledBalance.sub(currentRegistered);
            toRefund = _amount;
        }

        ibt.transfer(_user, toRefund);
        if (toRefund==currentRegistered){
            liquidityGauge.deleteUserLiquidityRegistration(_user);
        }

    }

    function startNewPeriod() public virtual override nextPeriodAvailable periodsActive {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();
        uint256 currentRate = getIBTRate();

        IBTRates[nextPeriodID] = currentRate;
        registrationsTotals[nextPeriodID] = ibt.balanceOf(address(this));

        /* Yield */
        uint256 yield =
            (ibt.balanceOf(address(futureVault)).mul(currentRate.sub(IBTRates[nextPeriodID - 1]))).div(currentRate);
        if (yield > 0) assert(ibt.transferFrom(address(futureVault), address(futureWallet), yield));
        futureWallet.registerExpiredFuture(yield); // Yield deposit in the futureWallet contract

        /* Period Switch*/
        if (registrationsTotals[nextPeriodID] > 0) {
            apwibt.mint(address(this), registrationsTotals[nextPeriodID].mul(IBTRates[nextPeriodID])); // Mint new APWIBTs
            ibt.transfer(address(futureVault), registrationsTotals[nextPeriodID]); // Send ibt to future for the new period
        }
        liquidityGauge.registerNewFutureLiquidity(registrationsTotals[nextPeriodID]);

        registrationsTotals.push();
        IBTRates.push();

        /* Future Yield Token*/
        address fytAddress = deployFutureYieldToken();
        emit NewPeriodStarted(nextPeriodID, fytAddress);
    }

    function getRegisteredAmount(address _user) public view override returns (uint256) {
        uint256 periodID = registrations[_user].startIndex;
        if (periodID == getNextPeriodIndex()) {
            return registrations[_user].scaledBalance;
        } else {
            return 0;
        }
    }

    function scaleIBTAmount(
        uint256 _initialAmount,
        uint256 _initialRate,
        uint256 _newRate
    ) public pure returns (uint256) {
        return (_initialAmount.mul(_initialRate)).div(_newRate);
    }

    function getClaimableAPWIBT(address _user) public view override returns (uint256) {
        if (!hasClaimableAPWIBT(_user)) return 0;
        return
            scaleIBTAmount(
                registrations[_user].scaledBalance,
                IBTRates[registrations[_user].startIndex],
                IBTRates[getNextPeriodIndex() - 1]
            );
    }

    function getUnlockableFunds(address _user) public view override returns (uint256) {
        return scaleIBTAmount(super.getUnlockableFunds(_user), IBTRates[getNextPeriodIndex() - 1], getIBTRate());
    }

    function getUnrealisedYield(address _user) public view override returns (uint256) {
        return
            apwibt.balanceOf(_user).sub(
                scaleIBTAmount(apwibt.balanceOf(_user), IBTRates[getNextPeriodIndex() - 1], getIBTRate())
            );
    }

    function getIBTRate() public view virtual returns (uint256);
}
