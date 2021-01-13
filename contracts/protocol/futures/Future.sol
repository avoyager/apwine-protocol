pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

// import "../../interfaces/ERC20.sol";
import "../../interfaces/IProxyFactory.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "../../libraries/APWineMaths.sol";
import "../../libraries/APWineNaming.sol";

import "contracts/interfaces/apwine/tokens/IAPWineIBT.sol";
import "../../interfaces/apwine/IFutureWallet.sol";
import "contracts/interfaces/apwine/IController.sol";
import "../../interfaces/apwine/IFutureVault.sol";
import "contracts/interfaces/apwine/ILiquidityGauge.sol";
import "contracts/interfaces/apwine/IRegistry.sol";

abstract contract Future is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    /* Structs */
    struct Registration {
        uint256 startIndex;
        uint256 scaledBalance;
    }

    uint256[] internal registrationsTotals;

    /* ACR ROLE */
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant FUTURE_PAUSER = keccak256("FUTURE_PAUSER");

    /* State variables */
    mapping(address => uint256) internal lastPeriodClaimed;
    mapping(address => Registration) internal registrations;
    IFutureYieldToken[] public fyts;

    /* External contracts */
    IFutureVault internal futureVault;
    IFutureWallet internal futureWallet;
    ILiquidityGauge internal liquidityGauge;
    ERC20 internal ibt;
    IAPWineIBT internal apwibt;
    IController internal controller;

    /* Settings */
    uint256 public PERIOD_DURATION;
    string public PLATFORM_NAME;
    bool public PAUSED;

    /* Events */
    event UserRegistered(address _userAddress, uint256 _amount, uint256 _periodIndex);
    event NewPeriodStarted(uint256 _newPeriodIndex, address _fytAddress);

    /* Modifiers */
    modifier nextPeriodAvailable() {
        uint256 controllerDelay = controller.STARTING_DELAY();
        require(
            controller.getNextPeriodStart(PERIOD_DURATION) < block.timestamp.add(controllerDelay),
            "Next period start range not reached yet"
        );
        _;
    }

    modifier periodsActive() {
        require(!PAUSED, "New periods are currently paused");
        _;
    }

    /* Initializer */
    function initialize(
        address _controller,
        address _ibt,
        uint256 _periodDuration,
        string memory _platformName,
        address _admin
    ) public virtual initializer {
        controller = IController(_controller);
        ibt = ERC20(_ibt);
        PERIOD_DURATION = _periodDuration * (1 days);
        PLATFORM_NAME = _platformName;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(CONTROLLER_ROLE, _controller);
        _setupRole(FUTURE_PAUSER, _controller);

        registrationsTotals.push();
        registrationsTotals.push();
        fyts.push();

        IRegistry registery = IRegistry(controller.getRegistery());
        string memory ibtSymbol = controller.getFutureIBTSymbol(ibt.symbol(), _platformName, _periodDuration);
        bytes memory payload =
            abi.encodeWithSignature("initialize(string,string,address)", ibtSymbol, ibtSymbol, address(this));
        apwibt = IAPWineIBT(
            IProxyFactory(registery.getProxyFactoryAddress()).deployMinimal(registery.getAPWineIBTLogicAddress(), payload)
        );
    }

    /* Period functions */
    function startNewPeriod() public virtual;

    function register(address _user, uint256 _amount) public virtual periodsActive {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to register");
        uint256 nextIndex = getNextPeriodIndex();
        if (registrations[_user].scaledBalance == 0) {
            // User has no record
            _register(_user, _amount);
        } else {
            if (registrations[_user].startIndex == nextIndex) {
                // User has already an existing registration for the next period
                registrations[_user].scaledBalance = registrations[_user].scaledBalance.add(_amount);
            } else {
                // User had an unclaimed registation from a previous period
                claimAPWIBT(_user);
                _register(_user, _amount);
            }
        }
        emit UserRegistered(_user, _amount, nextIndex);
    }

    function _register(address _user, uint256 _initialScaledBalance) internal virtual {
        registrations[_user] = Registration({startIndex: getNextPeriodIndex(), scaledBalance: _initialScaledBalance});
        liquidityGauge.registerUserLiquidity(_user);
    }

    function unregister(address _user, uint256 _amount) public virtual; // todo need to unregister liquidity if no registration left

    /* Claim functions */
    function claimFYT(address _user) public virtual {
        require(hasClaimableFYT(_user), "The is not fyt claimable for this address");
        if (hasClaimableAPWIBT(_user)) claimAPWIBT(_user);
        else _claimFYT(_user);
    }

    function _claimFYT(address _user) internal virtual {
        uint256 nextIndex = getNextPeriodIndex();
        for (uint256 i = lastPeriodClaimed[_user] + 1; i < nextIndex; i++) {
            claimFYTforPeriod(_user, i); // TODO gas cost can be optimized
        }
    }

    function claimFYTforPeriod(address _user, uint256 _periodIndex) internal virtual {
        assert((lastPeriodClaimed[_user] + 1) == _periodIndex);
        assert(_periodIndex < getNextPeriodIndex());
        assert(_periodIndex != 0);
        lastPeriodClaimed[_user] = _periodIndex;
        fyts[_periodIndex].transfer(_user, apwibt.balanceOf(_user));
    }

    function claimAPWIBT(address _user) internal virtual {
        uint256 nextIndex = getNextPeriodIndex();
        uint256 claimableAPWIBT = getClaimableAPWIBT(_user);
        // require(claimableAPWIBT>0, "There are no ibt claimable at the moment for this address");

        if (_hasOnlyClaimableFYT(_user)) _claimFYT(_user);
        apwibt.transfer(_user, claimableAPWIBT);
        // TODO register liquidity

        for (uint256 i = registrations[_user].startIndex; i < nextIndex; i++) {
            // get not claimed fyt
            fyts[i].transfer(_user, claimableAPWIBT);
        }

        lastPeriodClaimed[_user] = nextIndex - 1;
        delete registrations[_user];
    }

    function withdrawLockFunds(address _user, uint256 _amount) public virtual {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to whithdraw locked funds");
        require(_amount > 0, "Amount to withdraw must be positive");
        if (hasClaimableAPWIBT(_user)) {
            claimAPWIBT(_user);
        } else if (hasClaimableFYT(_user)) {
            claimFYT(_user);
        }

        uint256 fundsToBeUnlocked = getUnlockableFunds(_user);
        uint256 unrealisedYield = getUnrealisedYield(_user);
        require(apwibt.transferFrom(_user, address(this), _amount), "Invalid amount of APWIBT");
        require(
            fyts[getNextPeriodIndex() - 1].transferFrom(_user, address(this), _amount),
            "Invalid amount of FYT of last period"
        );
        apwibt.burn(_amount);
        fyts[getNextPeriodIndex() - 1].burn(_amount);

        ibt.transferFrom(address(futureVault), _user, fundsToBeUnlocked); // only send locked, TODO Send Yield
        ibt.transferFrom(address(futureVault), IRegistry(controller.getRegistery()).getTreasuryAddress(), unrealisedYield);
        liquidityGauge.removeUserLiquidity(_user, fundsToBeUnlocked);
    }

    /* Utilitaries functions */
    function deployFutureYieldToken() internal returns (address) {
        IRegistry registery = IRegistry(controller.getRegistery());
        string memory tokenDenomination = controller.getFYTSymbol(apwibt.symbol(), PERIOD_DURATION);
        bytes memory payload =
            abi.encodeWithSignature(
                "initialize(string,string,address)",
                tokenDenomination,
                tokenDenomination,
                address(this)
            );
        IFutureYieldToken newToken =
            IFutureYieldToken(
                IProxyFactory(registery.getProxyFactoryAddress()).deployMinimal(registery.getFYTLogicAddress(), payload)
            );
        fyts.push(newToken);
        newToken.mint(address(this), apwibt.totalSupply().mul(10**(uint256(18 - ibt.decimals()))));
        return address(newToken);
    }

    /* Getters */
    function hasClaimableFYT(address _user) public view returns (bool) {
        return hasClaimableAPWIBT(_user) || _hasOnlyClaimableFYT(_user);
    }

    function _hasOnlyClaimableFYT(address _user) internal view returns (bool) {
        return lastPeriodClaimed[_user] != 0 && lastPeriodClaimed[_user] < getNextPeriodIndex() - 1;
    }

    function hasClaimableAPWIBT(address _user) public view returns (bool) {
        return (registrations[_user].startIndex < getNextPeriodIndex()) && (registrations[_user].scaledBalance > 0);
    }

    function getNextPeriodIndex() public view virtual returns (uint256) {
        return registrationsTotals.length - 1;
    }

    function getClaimableAPWIBT(address _user) public view virtual returns (uint256);

    function getUnlockableFunds(address _user) public view virtual returns (uint256) {
        return getClaimableAPWIBT(_user).add(apwibt.balanceOf(_user));
    }

    function getRegisteredAmount(address _user) public view virtual returns (uint256);

    function getUnrealisedYield(address _user) public view virtual returns (uint256);

    function getFutureVaultAddress() public view returns (address) {
        return address(futureVault);
    }

    function getFutureWalletAddress() public view returns (address) {
        return address(futureWallet);
    }

    function getIBTAddress() public view returns (address) {
        return address(ibt);
    }

    function getAPWIBTAddress() public view returns (address) {
        return address(apwibt);
    }

    function getFYTofPeriod(uint256 _periodIndex) public view returns (address) {
        require(_periodIndex < getNextPeriodIndex(), "The isnt any fyt for this period yet");
        return address(fyts[_periodIndex]);
    }

    /* Admin function */
    function pausePeriods() public {
        require(hasRole(FUTURE_PAUSER, msg.sender), "Caller is not allowed to pause future");
        PAUSED = true;
    }

    function resumePeriods() public {
        require(hasRole(FUTURE_PAUSER, msg.sender), "Caller is not allowed to resume future");
        PAUSED = false;
    }

    function setFutureVault(address _futureVault) public {
        //TODO check if set before start
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to set the future vault address");
        futureVault = IFutureVault(_futureVault);
    }

    function setFutureWallet(address _futureWallet) public {
        //TODO check if set before start
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        futureWallet = IFutureWallet(_futureWallet);
    }

    function setLiquidityGauge(address _liquidityGauge) public {
        //TODO check if set before start
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to set the liquidity gauge address");
        liquidityGauge = ILiquidityGauge(_liquidityGauge);
    }

    /* Security functions */
}
