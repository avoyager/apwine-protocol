pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableMapUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "contracts/interfaces/apwine/IRegistry.sol";

import "contracts/libraries/APWineNaming.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

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

    function setNextPeriodSwitchTimestamp(uint256 _periodDuration, uint256 _nextPeriodTimestamp) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set next period timestamp");
        nextPeriodSwitchByDuration[_periodDuration] = _nextPeriodTimestamp;
        emit NextPeriodSwitchSet(_periodDuration, _nextPeriodTimestamp);
    }

    /* User Methods */

    function register(address _future, uint256 _amount) public futureIsValid(_future) {
        IFuture(_future).register(msg.sender, _amount);
    }

    function unregister(address _future, uint256 _amount) public futureIsValid(_future) {
        IFuture(_future).unregister(msg.sender, _amount);
    }

    function withdrawLockFunds(address _future, uint256 _amount) public futureIsValid(_future) {
        IFuture(_future).withdrawLockFunds(msg.sender, _amount);
    }

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

    function getRegistery() external view returns (address) {
        return address(registry);
    }

    function getFutureIBTSymbol(
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) public pure returns (string memory) {
        return APWineNaming.genIBTSymbol(_ibtSymbol, _platfrom, _periodDuration);
    }

    function getFYTSymbol(string memory _apwibtSymbol, uint256 _periodDuration) public view returns (string memory) {
        return APWineNaming.genFYTSymbolFromIBT(uint8(periodIndexByDurations[_periodDuration]), _apwibtSymbol);
    }

    function getPeriodIndex(uint256 _periodDuration) public view returns (uint256) {
        return periodIndexByDurations[_periodDuration];
    }

    function getNextPeriodStart(uint256 _periodDuration) public view returns (uint256) {
        return nextPeriodSwitchByDuration[_periodDuration];
    }

    /* future admin function*/
    function registerNewFuture(address _newFuture) public futureFactoryIsValid(msg.sender) {
        registry.addFuture(_newFuture);
        uint256 futureDuration = IFuture(_newFuture).PERIOD_DURATION();
        if (!durations.contains(futureDuration)) durations.add(futureDuration);
        futuresByDuration[futureDuration].add(_newFuture);
        emit FutureRegistered(_newFuture);
    }

    function unregisterFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(registry.removeFuture(_future), "invalid future");

        uint256 futureDuration = IFuture(_future).PERIOD_DURATION();
        if (!durations.contains(futureDuration)) durations.remove(futureDuration);
        futuresByDuration[futureDuration].remove(_future);
        emit FutureUnregistered(_future);
    }

    function startFuturesByPeriodDuration(uint256 _periodDuration) public {
        for (uint256 i = 0; i < futuresByDuration[_periodDuration].length(); i++) {
            IFuture(registry.getFutureAt(i)).startNewPeriod();
        }
        nextPeriodSwitchByDuration[_periodDuration] = nextPeriodSwitchByDuration[_periodDuration].add(_periodDuration);
        periodIndexByDurations[_periodDuration] = periodIndexByDurations[_periodDuration].add(1);
    }

    function getFuturesWithDuration(uint256 _periodDuration) public view returns (address[] memory) {
        address[] memory filteredFutures = new address[](futuresByDuration[_periodDuration].length());
        for (uint256 i = 0; i < filteredFutures.length; i++) {
            filteredFutures[i] = futuresByDuration[_periodDuration].at(i);
        }
        return filteredFutures;
    }

    /* Security functions */
    function pauseFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IFuture(_future).pausePeriods();
    }

    function resumeFuture(address _future) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IFuture(_future).resumePeriods();
    }
}
