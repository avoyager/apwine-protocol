pragma solidity >=0.7.0 <0.8.0;

interface IController {
    /* Getters */

    function STARTING_DELAY() external view returns (uint256);

    /* Initializer */

    /**
     * @notice Initializer of the Controller contract
     * @param _admin the address of the admin
     */
    function initialize(address _admin) external;

    /* Future Settings Setters */

    /**
     * @notice Change the delay for starting a new period
     * @param _startingDelay the new delay (+-) to start the next period
     */
    function setPeriodStartingDelay(uint256 _startingDelay) external;

    /**
     * @notice Set the next period switch timestamp for the future with corresponding duration
     * @param _periodDuration the periods duration
     * @param _nextPeriodTimestamp the next period switch timsetamp
     */
    function setNextPeriodSwitchTimestamp(uint256 _periodDuration, uint256 _nextPeriodTimestamp) external;


    /**
     * @notice Set a new factor for the portion of the yield that is claimable when withdrawing funds during an ongoing period 
     * @param _periodDuration the periods duration
     * @param _claimableYieldFactor the portion of the yield that is claimable
     */
    function setUnlockClaimableFactor(uint256 _periodDuration, uint256 _claimableYieldFactor) external;

    /* User Methods */

    /**
     * @notice Register an amount of ibt from the sender to the corresponding future
     * @param _future the address of the future to be registered to
     * @param _amount the amount to register
     */
    function register(address _future, uint256 _amount) external;

    /**
     * @notice Unregister an amount of ibt from the sender to the corresponding future
     * @param _future the address of the future to be unregistered from
     * @param _amount the amount to unregister
     */
    function unregister(address _future, uint256 _amount) external;

    /**
     * @notice Withdraw deposited funds from apwine
     * @param _future the address of the future to be withdraw the ibt from
     * @param _amount the amount to withdraw
     */
    function withdrawLockFunds(address _future, uint256 _amount) external;

    /**
     * @notice Claim fyt of the msg.sender
     * @param _future the future from which to claim the ibts
     */
    function claimFYT(address _future) external;

    /**
     * @notice Get the list of future from which on user can claim FYT
     * @param _user the user to claim de FYT from
     */
    function getFuturesWithClaimableFYT(address _user) external view returns (address[] memory);

    /**
     * @notice Getter for the registry address of the protocol
     * @return the address of the protocol registry
     */
    function getRegistryAddress() external view returns (address);

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
    ) external pure returns (string memory);

    /**
     * @notice Getter for the symbol of the fyt of one future
     * @param _apwibtSymbol the apwine ibt symbole  for this future
     * @param _periodDuration the duration of the periods for this future
     * @return the generated symbol of the fyt
     */
    function getFYTSymbol(string memory _apwibtSymbol, uint256 _periodDuration) external view returns (string memory);

    /**
     * @notice Getter for the period index depending on the period duration of the future
     * @param _periodDuration the periods duration
     * @return the period index
     */
    function getPeriodIndex(uint256 _periodDuration) external view returns (uint256);

    /**
     * @notice Getter for beginning timestamp of the next period for the futures with a defined periods duration
     * @param _periodDuration the periods duration
     * @return the timestamp of the beginning of the next period
     */
    function getNextPeriodStart(uint256 _periodDuration) external view returns (uint256);

    /**
     * @notice Getter for the factor of claimable yield when unlocking
     * @param _periodDuration the periods duration
     * @return the factor of claimable yield of the last period
     */
    function getUnlockYieldFactor(uint256 _periodDuration) external view returns (uint256);

    /**
     * @notice Getter for the list of future durations registered in the contract
     * @return the list of futures duration
     */
    function getDurations() external view returns (uint256[] memory);

    /**
     * @notice Register a newly created future in the registry
     * @param _newFuture the address of the new future
     */
    function registerNewFuture(address _newFuture) external;

    /**
     * @notice Unregister a future from the registry
     * @param _future the address of the future to unregister
     */
    function unregisterFuture(address _future) external;

    /**
     * @notice Start all the future that have a defined periods duration to synchronize them
     * @param _periodDuration the periods duration of the future to start
     */
    function startFuturesByPeriodDuration(uint256 _periodDuration) external;

    /**
     * @notice Getter for the futures by periods duration
     * @param _periodDuration the periods duration of the futures to returns
     */
    function getFuturesWithDuration(uint256 _periodDuration) external view returns (address[] memory);

    /**
     * @notice Register the sender to the corresponding future
     * @param _user the address of the user
     * @param _futureAddress the addresses of the futures to claim the fyts from
     */
    function claimSelectedYield(address _user, address[] memory _futureAddress) external;

    function getRoleMember(bytes32 role, uint256 index) external view returns (address); // OZ ACL getter

    /**
     * @notice Interrupt a future avoiding news registrations
     * @param _future the address of the future to pause
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function pauseFuture(address _future) external;

    /**
     * @notice Resume a future that has been paused
     * @param _future the address of the future to resume
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function resumeFuture(address _future) external;
}
