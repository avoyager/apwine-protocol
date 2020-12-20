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

    /* Public methods */

    /* Future Settings Setters */

    /**
     * @notice Change the delay for starting a new period
     * @param _startingDelay the new delay (+-) to start the next period
     */
    function setPeriodStartingDelay(uint256 _startingDelay) external;

    /* User Methods */

    /**
     * @notice Register the sender to the corresponding future
     * @param _futureAddress the address of the future to be registered to
     * @param _amount the amount to register
     */
    function register(address _futureAddress, uint256 _amount) external;

    function unregister(address _future, uint256 _amount) external;

    function withdrawLockFunds(address _future, uint256 _amount) external;

    function claimFYT(address _future) external;

    function getFuturesWithClaimableFYT(address _user) external view returns (address[] memory);

    function getRegistery() external view returns (address);

    function getFutureIBTSymbol(
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) external pure returns (string memory);

    function getFYTSymbol(string memory _apwibtSymbol, uint256 _periodDuration) external view returns (string memory);

    function getPeriodIndex(uint256 _periodDuration) external view returns (uint256);

    function getNextPeriodStart(uint256 _periodDuration) external view returns (uint256);

    function registerNewFuture(address _newFuture) external;

    function unregisterFuture(address _future) external;

    function startFuturesByPeriodDuration(uint256 _periodDuration) external;

    function getFuturesWithDuration(uint256 _periodDuration) external view returns (address[] memory);

    /**
     * @notice Register the sender to the corresponding future
     * @param _user the address of the user
     * @param _futureAddress the addresses of the futures to claim the fyts from
     */
    function claimSelectedYield(address _user, address[] memory _futureAddress) external;

    /* Views */

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function pauseFuture(address _future) external;

    function resumeFuture(address _future) external;
}
