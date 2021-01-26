pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "contracts/interfaces/IProxyFactory.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "contracts/interfaces/apwine/utils/IAPWineMath.sol";

import "contracts/interfaces/apwine/tokens/IAPWineIBT.sol";
import "contracts/interfaces/apwine/IFutureWallet.sol";
import "contracts/interfaces/apwine/IFuture.sol";

import "contracts/interfaces/apwine/IController.sol";
import "contracts/interfaces/apwine/IFutureVault.sol";
import "contracts/interfaces/apwine/ILiquidityGauge.sol";
import "contracts/interfaces/apwine/IRegistry.sol";

/**
 * @title Main future abstraction contract
 * @author Gaspard Peduzzi
 * @notice Handles the future mecanisms
 * @dev The future contract is the basis of all the mecanisms of the future with the from the registration to the period switch
 */
abstract contract Future is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    /* Structs */
    struct Registration {
        uint256 startIndex;
        uint256 scaledBalance;
    }

    uint256[] internal registrationsTotals;

    /* ACR */
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant FUTURE_PAUSER = keccak256("FUTURE_PAUSER");
    bytes32 public constant FUTURE_DEPLOYER = keccak256("FUTURE_DEPLOYER");

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
    ) public virtual initializer {
        controller = IController(_controller);
        ibt = ERC20(_ibt);
        PERIOD_DURATION = _periodDuration * (1 days);
        PLATFORM_NAME = _platformName;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(CONTROLLER_ROLE, _controller);
        _setupRole(FUTURE_PAUSER, _controller);
        _setupRole(FUTURE_DEPLOYER, _deployerAddress);

        registrationsTotals.push();
        registrationsTotals.push();
        fyts.push();

        IRegistry registry = IRegistry(controller.getRegistryAddress());
        string memory ibtSymbol = controller.getFutureIBTSymbol(ibt.symbol(), _platformName, _periodDuration);
        bytes memory payload =
            abi.encodeWithSignature("initialize(string,string,address)", ibtSymbol, ibtSymbol, address(this));
        apwibt = IAPWineIBT(
            IProxyFactory(registry.getProxyFactoryAddress()).deployMinimal(registry.getAPWineIBTLogicAddress(), payload)
        );
    }

    /* Period functions */
    /**
     * @notice Start a new period
     * @dev needs corresponding permissions for sender
     */
    function startNewPeriod() public virtual;

    /**
     * @notice Sender registers an amount of ibt for the next period
     * @param _user address to register to the future
     * @param _amount amount of ibt to be registered
     * @dev called by the controller only
     */
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

    /**
     * @notice Sender unregisters an amount of ibt for the next period
     * @param _user user addresss
     * @param _amount amount of ibt to be unregistered
     */
    function unregister(address _user, uint256 _amount) public virtual;

    /* Claim functions */
    /**
     * @notice Send the user its owed fyt (and apwibt if there are some claimable)
     * @param _user address of the user to send the fyt to
     */
    function claimFYT(address _user) public virtual {
        require(hasClaimableFYT(_user), "The is not fyt claimable for this address");
        if (hasClaimableAPWIBT(_user)) claimAPWIBT(_user);
        else _claimFYT(_user);
    }

    function _claimFYT(address _user) internal virtual {
        uint256 nextIndex = getNextPeriodIndex();
        for (uint256 i = lastPeriodClaimed[_user] + 1; i < nextIndex; i++) {
            claimFYTforPeriod(_user, i);
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

        for (uint256 i = registrations[_user].startIndex; i < nextIndex; i++) {
            // get not claimed fyt
            fyts[i].transfer(_user, claimableAPWIBT);
        }

        lastPeriodClaimed[_user] = nextIndex - 1;
        delete registrations[_user];
    }

    /**
     * @notice Sender unlock the locked funds corresponding to its apwibt holding
     * @param _user user adress
     * @param _amount amount of funds to unlocked
     * @dev will require transfer of fyt of the oingoing period corresponding to the funds unlocked
     */
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

        uint256 yieldToBeRedeemed = unrealisedYield.mul(controller.getUnlockYieldFactor(PERIOD_DURATION));

        ibt.transferFrom(address(futureVault), _user, fundsToBeUnlocked.add(yieldToBeRedeemed));

        ibt.transferFrom(
            address(futureVault),
            IRegistry(controller.getRegistryAddress()).getTreasuryAddress(),
            unrealisedYield.sub(yieldToBeRedeemed)
        );
        liquidityGauge.removeUserLiquidity(_user, fundsToBeUnlocked);
    }

    /* Utilitaries functions */
    function deployFutureYieldToken() internal returns (address) {
        IRegistry registry = IRegistry(controller.getRegistryAddress());
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
                IProxyFactory(registry.getProxyFactoryAddress()).deployMinimal(registry.getFYTLogicAddress(), payload)
            );
        fyts.push(newToken);
        newToken.mint(address(this), apwibt.totalSupply().mul(10**(uint256(18 - ibt.decimals()))));
        return address(newToken);
    }

    /* Getters */
    /**
     * @notice Check if a user has fyt not claimed
     * @param _user the user to check
     * @return true if the user can claim some fyt, false otherwise
     */
    function hasClaimableFYT(address _user) public view returns (bool) {
        return hasClaimableAPWIBT(_user) || _hasOnlyClaimableFYT(_user);
    }

    function _hasOnlyClaimableFYT(address _user) internal view returns (bool) {
        return lastPeriodClaimed[_user] != 0 && lastPeriodClaimed[_user] < getNextPeriodIndex() - 1;
    }

    /**
     * @notice Check if a user has ibt not claimed
     * @param _user the user to check
     * @return true if the user can claim some ibt, false otherwise
     */
    function hasClaimableAPWIBT(address _user) public view returns (bool) {
        return (registrations[_user].startIndex < getNextPeriodIndex()) && (registrations[_user].scaledBalance > 0);
    }

    /**
     * @notice Getter for next period index
     * @return next period index
     * @dev index starts at 1
     */
    function getNextPeriodIndex() public view virtual returns (uint256) {
        return registrationsTotals.length - 1;
    }

    /**
     * @notice Getter for the amount of apwibt that the user can claim
     * @param _user user to check the check the claimable apwibt of
     * @return the amount of apwibt claimable by the user
     */
    function getClaimableAPWIBT(address _user) public view virtual returns (uint256);

    /**
     * @notice Getter for user ibt amount that is unlockable
     * @param _user user to unlock the ibt from
     * @return the amount of ibt the user can unlock
     */
    function getUnlockableFunds(address _user) public view virtual returns (uint256) {
        return apwibt.balanceOf(_user);
    }

    /**
     * @notice Getter for user registered amount
     * @param _user user to return the registered funds of
     * @return the registered amount, 0 if no registrations
     * @dev the registration can be older than for the next period
     */
    function getRegisteredAmount(address _user) public view virtual returns (uint256);

    /**
     * @notice Getter for yield that is generated by the user funds during the current period
     * @param _user user to check the unrealised yield of
     * @return the yield (amout of ibt) currently generated by the locked funds of the user
     */
    function getUnrealisedYield(address _user) public view virtual returns (uint256);

    /**
     * @notice Getter for controller  address
     * @return the controller  address
     */
    function getControllerAddress() public view returns (address) {
        return address(controller);
    }

    /**
     * @notice Getter for future wallet address
     * @return future wallet address
     */
    function getFutureVaultAddress() public view returns (address) {
        return address(futureVault);
    }

    /**
     * @notice Getter for futureWallet address
     * @return futureWallet address
     */
    function getFutureWalletAddress() public view returns (address) {
        return address(futureWallet);
    }

    /**
     * @notice Getter for liquidityGauge address
     * @return liquidity gauge address
     */
    function getLiquidityGaugeAddress() public view returns (address) {
        return address(liquidityGauge);
    }

    /**
     * @notice Getter for the ibt address
     * @return ibt address
     */
    function getIBTAddress() public view returns (address) {
        return address(ibt);
    }

    /**
     * @notice Getter for future apwibt address
     * @return apwibt address
     */
    function getAPWIBTAddress() public view returns (address) {
        return address(apwibt);
    }

    /**
     * @notice Getter for fyt address of a particular period
     * @param _periodIndex period index
     * @return fyt address
     */
    function getFYTofPeriod(uint256 _periodIndex) public view returns (address) {
        require(_periodIndex < getNextPeriodIndex(), "The isnt any fyt for this period yet");
        return address(fyts[_periodIndex]);
    }

    /* Admin function */
    /**
     * @notice Pause registrations and the creation of new periods
     */
    function pausePeriods() public {
        require(hasRole(FUTURE_PAUSER, msg.sender), "Caller is not allowed to pause future");
        PAUSED = true;
    }

    /**
     * @notice Resume registrations and the creation of new periods
     */
    function resumePeriods() public {
        require(hasRole(FUTURE_PAUSER, msg.sender), "Caller is not allowed to resume future");
        PAUSED = false;
    }

    /**
     * @notice Set future wallet address
     * @param _futureVault the address of the new future wallet
     * @dev needs corresponding permissions for sender
     */
    function setFutureVault(address _futureVault) public {
        require(hasRole(FUTURE_DEPLOYER, msg.sender), "Caller is not allowed to set the future vault address");
        futureVault = IFutureVault(_futureVault);
    }

    /**
     * @notice Set futureWallet address
     * @param _futureWallet the address of the new futureWallet
     * @dev needs corresponding permissions for sender
     */
    function setFutureWallet(address _futureWallet) public {
        require(hasRole(FUTURE_DEPLOYER, msg.sender), "Caller is not allowed to set the future wallet address");
        futureWallet = IFutureWallet(_futureWallet);
    }

    /**
     * @notice Set liquidity gauge address
     * @param _liquidityGauge the address of the new liquidity gauge
     * @dev needs corresponding permissions for sender
     */
    function setLiquidityGauge(address _liquidityGauge) public {
        require(hasRole(FUTURE_DEPLOYER, msg.sender), "Caller is not allowed to set the liquidity gauge address");
        liquidityGauge = ILiquidityGauge(_liquidityGauge);
    }
}
