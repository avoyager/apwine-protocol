pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableMapUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "contracts/interfaces/apwine/IRegistry.sol";

import "contracts/interfaces/apwine/utils/IAPWineNaming.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

/**
 * @title Controller contract
 * @author Gaspard Peduzzi
 * @notice The controller dictate the future mecanisms and serves as an interfaces for main user interaction with futures
 */
contract Controller is Initializable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using SafeMathUpgradeable for uint256;

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* Attributes */

    IRegistry public registry;
    mapping(uint256 => uint256) private nextPeriodSwitchByDuration;

    mapping(string => EnumerableSetUpgradeable.UintSet) private platformNames;

    EnumerableSetUpgradeable.UintSet private durations;
    mapping(uint256 => EnumerableSetUpgradeable.AddressSet) private futuresByDuration;
    mapping(uint256 => uint256) private periodIndexByDurations;

    /* Events */

    event PlatformRegistered(address _platformControllerAddress);
    event PlatformUnregistered(address _platformControllerAddress);
    event NextPeriodSwitchSet(uint256 _periodDuration, uint256 _nextSwitchTimestamp);
    event FutureRegistered(address _newFutureAddress);
    event FutureUnregistered(address _future);

    /* PlatformController Settings */
    uint256 public STARTING_DELAY;

    /* Modifiers */

    modifier futureIsValid(address _future) {
        require(registry.isRegisteredFuture(_future), "incorrect future address");
        _;
    }

    modifier futureFactoryIsValid(address _futureFactoryAddress) {
        require(registry.isRegisteredFutureFactory(_futureFactoryAddress), "incorrect futurePlatform address");
        _;
    }

    /* Initializer */

    /**
     * @notice Initializer of the Controller contract
     * @param _admin the address of the admin
     */
    function initialize(address _admin, address _registry) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
        registry = IRegistry(_registry);
    }

    /**
     * @notice Change the delay for starting a new period
     * @param _startingDelay the new delay (+-) to start the next period
     */
    function setPeriodStartingDelay(uint256 _startingDelay) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        STARTING_DELAY = _startingDelay;
    }

    /**
     * @notice Set the next period switch timestamp for the future with corresponding duration
     * @param _periodDuration the periods duration
     * @param _nextPeriodTimestamp the next period switch timsetamp
     */
    function setNextPeriodSwitchTimestamp(uint256 _periodDuration, uint256 _nextPeriodTimestamp) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set next period timestamp");
        nextPeriodSwitchByDuration[_periodDuration] = _nextPeriodTimestamp;
        emit NextPeriodSwitchSet(_periodDuration, _nextPeriodTimestamp);
    }

    /* User Methods */

    /**
     * @notice Register an amount of ibt from the sender to the corresponding future
     * @param _future the address of the future to be registered to
     * @param _amount the amount to register
     */
    function register(address _future, uint256 _amount) public futureIsValid(_future) {
        require(ERC20(IFuture(_future).getIBTAddress()).transferFrom(msg.sender, _future, _amount), "invalid amount");
        IFuture(_future).register(msg.sender, _amount);
    }

    /**
     * @notice Unregister an amount of ibt from the sender to the corresponding future
     * @param _future the address of the future to be unregistered from
     * @param _amount the amount to unregister
     */
    function unregister(address _future, uint256 _amount) public futureIsValid(_future) {
        IFuture(_future).unregister(msg.sender, _amount);
    }

    /**
     * @notice Withdraw deposited funds from apwine
     * @param _future the address of the future to be withdraw the ibt from
     * @param _amount the amount to withdraw
     */
    function withdrawLockFunds(address _future, uint256 _amount) public futureIsValid(_future) {
        IFuture(_future).withdrawLockFunds(msg.sender, _amount);
    }

    /**
     * @notice Claim fyt of the msg.sender
     * @param _future the future from which to claim the ibts
     */
    function claimFYT(address _future) public futureIsValid(_future) {
        IFuture(_future).claimFYT(msg.sender);
    }

    /**
     * @notice Register the sender to the corresponding platformController
     * @param _user the address of the user
     * @param futuresAddresses the addresses of the futures to claim the fyts from
     */
    function claimSelectedYield(address _user, address[] memory futuresAddresses) public {
        for (uint256 i = 0; i < futuresAddresses.length; i++) {
            require(registry.isRegisteredFuture(futuresAddresses[i]), "Incorrect future address");
            IFuture(futuresAddresses[i]).claimFYT(_user);
        }
    }

    /* User Getter */
    /**
     * @notice Get the list of future from which on user can claim FYT
     * @param _user the user to claim de FYT from
     */
    function getFuturesWithClaimableFYT(address _user) external view returns (address[] memory) {
        address[] memory selectedFutures = new address[](registry.futureCount());
        uint8 index = 0;
        for (uint256 i = 0; i < registry.futureCount(); i++) {
            if (IFuture(registry.getFutureAt(i)).hasClaimableFYT(_user)) {
                selectedFutures[i] = registry.getFutureAt(i);
                index += 1;
            }
        }
        return selectedFutures;
    }

    /* Getter */

    /**
     * @notice Getter for the registry address of the protocol
     * @return the address of the protocol registry
     */
    function getRegistryAddress() external view returns (address) {
        return address(registry);
    }

    /**
     * @notice Getter for the symbol of the apwine ibt of one future
     * @param _ibtSymbol the ibt of the external protocol
     * @param _platfrom the external protocol name
     * @param _periodDuration the duration of the periods for the future
     * @return the generated symbol of the apwine ibt
     */
    function getFutureIBTSymbol(
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) public view returns (string memory) {
        return IAPWineNaming(registry.getNamingUtils()).genIBTSymbol(_ibtSymbol, _platfrom, _periodDuration);
    }

    /**
     * @notice Getter for the symbol of the fyt of one future
     * @param _apwibtSymbol the apwine ibt symbole  for this future
     * @param _periodDuration the duration of the periods for this future
     * @return the generated symbol of the fyt
     */
    function getFYTSymbol(string memory _apwibtSymbol, uint256 _periodDuration) public view returns (string memory) {
        return
            IAPWineNaming(registry.getNamingUtils()).genFYTSymbolFromIBT(
                uint8(periodIndexByDurations[_periodDuration]),
                _apwibtSymbol
            );
    }

    /**
     * @notice Getter for the period index depending on the period duration of the future
     * @param _periodDuration the periods duration
     * @return the period index
     */
    function getPeriodIndex(uint256 _periodDuration) public view returns (uint256) {
        return periodIndexByDurations[_periodDuration];
    }

    /**
     * @notice Getter for beginning timestamp of the next period for the futures with a defined periods duration
     * @param _periodDuration the periods duration
     * @return the timestamp of the beginning of the next period
     */
    function getNextPeriodStart(uint256 _periodDuration) public view returns (uint256) {
        return nextPeriodSwitchByDuration[_periodDuration];
    }

    /**
     * @notice Getter for the list of future durations registered in the contract
     * @return the list of futures duration
     */
    function getDurations() public view returns (uint256[] memory) {
        uint256[] memory durationsList = new uint256[](durations.length());
        for (uint256 i = 0; i < durations.length(); i++) {
            durationsList[i] = durations.at(i);
        }
        return durationsList;
    }

    /**
     * @notice Getter for the futures by periods duration
     * @param _periodDuration the periods duration of the futures to returns
     */
    function getFuturesWithDuration(uint256 _periodDuration) public view returns (address[] memory) {
        uint256 listLength = futuresByDuration[_periodDuration].length();
        address[] memory filteredFutures = new address[](listLength);
        for (uint256 i = 0; i < listLength; i++) {
            filteredFutures[i] = futuresByDuration[_periodDuration].at(i);
        }
        return filteredFutures;
    }

    /* future admin function*/
    /**
     * @notice Register a newly created future in the registry
     * @param _newFuture the address of the new future
     */
    function registerNewFuture(address _newFuture) public futureFactoryIsValid(msg.sender) {
        registry.addFuture(_newFuture);
        uint256 futureDuration = IFuture(_newFuture).PERIOD_DURATION();
        if (!durations.contains(futureDuration)) durations.add(futureDuration);
        futuresByDuration[futureDuration].add(_newFuture);
        emit FutureRegistered(_newFuture);
    }

    /**
     * @notice Unregister a future from the registry
     * @param _future the address of the future to unregister
     */
    function unregisterFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        registry.removeFuture(_future);

        uint256 futureDuration = IFuture(_future).PERIOD_DURATION();
        if (!durations.contains(futureDuration)) durations.remove(futureDuration);
        futuresByDuration[futureDuration].remove(_future);
        emit FutureUnregistered(_future);
    }

    /**
     * @notice Start all the future that have a defined periods duration to synchronize them
     * @param _periodDuration the periods duration of the future to start
     */
    function startFuturesByPeriodDuration(uint256 _periodDuration) public {
        for (uint256 i = 0; i < futuresByDuration[_periodDuration].length(); i++) {
            IFuture(registry.getFutureAt(i)).startNewPeriod();
        }
        nextPeriodSwitchByDuration[_periodDuration] = nextPeriodSwitchByDuration[_periodDuration].add(_periodDuration);
        periodIndexByDurations[_periodDuration] = periodIndexByDurations[_periodDuration].add(1);
    }

    /* Security functions */

    /**
     * @notice Interrupt a future avoiding news registrations
     * @param _future the address of the future to pause
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function pauseFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IFuture(_future).pausePeriods();
    }

    /**
     * @notice Resume a future that has been paused
     * @param _future the address of the future to resume
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function resumeFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IFuture(_future).resumePeriods();
    }
}
