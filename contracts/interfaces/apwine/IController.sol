pragma solidity >=0.4.22 <0.7.3;


interface IController {
    /* Getters */

    function APWineTreasury() external view returns(address);

    function FutureYieldTokenLogic() external view returns(address);

    function APWineProxyFactory() external view returns(address);

    function APWineIBTLogic() external view returns(address);

    function STARTING_DELAY() external view returns(uint256);


    /* Initializer */

    /**
     * @notice Initializer of the Controller contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) external;

    /* Public methods */

    /**
     * @notice Adds a future for everyone to use
     * @param _futureAddress the address of the future
     */
    function addFuture(address _futureAddress) external;

    /**
     * @notice Removes a future from the registered futures list
     * @param _futureAddress the address of the future
     */
    function delFuture(address _futureAddress) external;

    /**
     * @notice Change the APWine treasury contract address
     * @param _APWineTreasury the address of the new treasury contract
     */
    function setTreasuryAddress(address _APWineTreasury) external;

    /**
     * @notice Change the APWineProxyFactory contract address
     * @param _APWineProxyFactory the address of the new APWineProxyFactory contract
     */
    function setAPWineProxyFactoryAddress(address _APWineProxyFactory) external;

    /**
     * @notice Change the APWineProxy contract logic address
     * @param _FutureYieldTokenLogic the address of the new proxy logic
     */
    function setFutureYieldTokenLogic(address _FutureYieldTokenLogic) external;

    /**
     * @notice Change the APWineIBT contract logic address
     * @param _APWineIBTLogic the address of the new APWineIBTlogic
     */
    function setAPWineIBTLogic(address _APWineIBTLogic) external;

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

    /**
     * @notice Register the sender to the corresponding future
     * @param _user the address of the user
     * @param _futureAddress the addresses of the futures to claim the fyts from
     */
    function claimSelectedYield(address _user, address[] memory _futureAddress) external; 

    /* Views */

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _futureAddress) external view returns (bool);


    /**
     * @notice Checks whether the address is a valid future
     * @param _user the address of the user
     * @return array of futures addresses where the user can claim fyt
     * @dev shouldn't be called in a contract
     */
    function getFutureWithClaimableFYT(address _user) external view returns (address[] memory);


    /**
     * @notice Checks whether the address is a valid future
     * @param _user the address of the user
     * @return array of futures addresses where the user can claim ibt
     * @dev shouldn't be called in a contract
     */
    function getFutureWithClaimableAPWIBT(address _user) external view returns (address[] memory);

    /**
     * @notice Number of future
     * @return uint256 the number of future
     */
    function futureCount() external view returns (uint256);

    /**
     * @notice View available future
     * @param _index index of the future to retrieve
     * @return address the future address at index
     */
    function future(uint256 _index) external view returns (address);


}
