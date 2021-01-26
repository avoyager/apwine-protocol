pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "contracts/protocol/futures/Future.sol";

/**
 * @title Main future abstraction contract for the rate futures
 * @author Gaspard Peduzzi
 * @notice Handles the rates future mecanisms
 * @dev The future contract is the basis of all the mecanisms of the future with the from the registration to the period switch
 */
abstract contract RateFuture is Future {
    using SafeMathUpgradeable for uint256;

    uint256[] private IBTRates;

    /**
     * @notice Intializer
     * @param _controller the address of the controller
     * @param _ibt the address of the corresponding ibt
     * @param _periodDuration the length of the period (in days)
     * @param _platformName the name of the platform and tools
     * @param _admin the address of the ACR admin
     */
    function initialize(
        address _controller,
        address _ibt,
        uint256 _periodDuration,
        string memory _platformName,
        address _deployerAddress,
        address _admin
    ) public virtual override initializer {
        super.initialize(_controller, _ibt, _periodDuration, _platformName, _deployerAddress, _admin);
        IBTRates.push();
        IBTRates.push();
    }

    /**
     * @notice Sender unregisters an amount of ibt for the next period
     * @param _user user addresss
     * @param _amount amount of ibt to be unregistered
     * @dev 0 unregister all
     */
    function unregister(address _user, uint256 _amount) public virtual override {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to unregister");

        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[_user].startIndex == nextIndex, "The is not ongoing registration for the next period");

        uint256 currentRegistered = registrations[_user].scaledBalance;
        uint256 toRefund;

        if (_amount == 0) {
            delete registrations[_user];
            toRefund = currentRegistered;
        } else {
            require(currentRegistered >= _amount, "Invalid amount to unregister");
            registrations[_user].scaledBalance = registrations[_user].scaledBalance.sub(currentRegistered);
            toRefund = _amount;
        }

        ibt.transfer(_user, toRefund);
        if (toRefund == currentRegistered) {
            liquidityGauge.deleteUserLiquidityRegistration(_user);
        }
    }

    /**
     * @notice Start a new period
     * @dev needs corresponding permissions for sender
     */
    function startNewPeriod() public virtual override nextPeriodAvailable periodsActive {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to start the next period");

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

    /**
     * @notice Getter for user registered amount
     * @param _user user to return the registered funds of
     * @return the registered amount, 0 if no registrations
     * @dev the registration can be older than for the next period
     */
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

    /**
     * @notice Getter for the amount of apwibt that the user can claim
     * @param _user user to check the check the claimable apwibt of
     * @return the amount of apwibt claimable by the user
     */
    function getClaimableAPWIBT(address _user) public view override returns (uint256) {
        if (!hasClaimableAPWIBT(_user)) return 0;
        return
            scaleIBTAmount(
                registrations[_user].scaledBalance,
                IBTRates[registrations[_user].startIndex],
                IBTRates[getNextPeriodIndex() - 1]
            );
    }

    /**
     * @notice Getter for user ibt amount that is unlockable
     * @param _user user to unlock the ibt from
     * @return the amount of ibt the user can unlock
     */
    function getUnlockableFunds(address _user) public view override returns (uint256) {
        return scaleIBTAmount(super.getUnlockableFunds(_user), IBTRates[getNextPeriodIndex() - 1], getIBTRate());
    }

    /**
     * @notice Getter for yield that is generated by the user funds during the current period
     * @param _user user to check the unrealised yield of
     * @return the yield (amout of ibt) currently generated by the locked funds of the user
     */
    function getUnrealisedYield(address _user) public view override returns (uint256) {
        return
            apwibt.balanceOf(_user).sub(
                scaleIBTAmount(apwibt.balanceOf(_user), IBTRates[getNextPeriodIndex() - 1], getIBTRate())
            );
    }

    /**
     * @notice Getter for the rate of the ibt
     * @return the uint256 rate, ibt x rate must be equal to the quantity of underlying tokens
     */
    function getIBTRate() public view virtual returns (uint256);
}
