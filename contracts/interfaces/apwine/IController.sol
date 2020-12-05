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
     * @notice Adds a vineyard for everyone to use
     * @param _vineyardAddress the address of the vineyard
     */
    function addVineyard(address _vineyardAddress) external;

    /**
     * @notice Removes a vineyard from the registered vineyards list
     * @param _vineyardAddress the address of the vineyard
     */
    function delVineyard(address _vineyardAddress) external;

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

    /* Vineyard Settings Setters */

    /**
     * @notice Change the delay for starting a new period
     * @param _startingDelay the new delay (+-) to start the next period
     */
    function setPeriodStartingDelay(uint256 _startingDelay) external;

    /* User Methods */

    /**
     * @notice Register the sender to the corresponding vineyard
     * @param _vineyardAddress the address of the vineyard to be registered to
     * @param _amount the amount to register
     */
    function register(address _vineyardAddress, uint256 _amount) external;

    /**
     * @notice Register the sender to the corresponding vineyard
     * @param _winemaker the address of the winemaker
     * @param _vineyardAddress the addresses of the vineyards to claim the fyts from
     */
    function claimSelectedYield(address _winemaker, address[] memory _vineyardAddress) external; 

    /* Views */

    /**
     * @notice Checks whether the address is a valid vineyard
     * @return bool true if the given vineyard is valid
     */
    function isRegisteredVineyard(address _vineyardAddress) external view returns (bool);


    /**
     * @notice Checks whether the address is a valid future
     * @param _winemaker the address of the winemaker
     * @return array of vineyards addresses where the winemaker can claim fyt
     * @dev shouldn't be called in a contract
     */
    function getVineyardWithClaimableFYT(address _winemaker) external view returns (address[] memory);


    /**
     * @notice Checks whether the address is a valid future
     * @param _winemaker the address of the winemaker
     * @return array of vineyards addresses where the winemaker can claim ibt
     * @dev shouldn't be called in a contract
     */
    function getVineyardWithClaimableAPWIBT(address _winemaker) external view returns (address[] memory);

    /**
     * @notice Number of vineyard
     * @return uint256 the number of vineyard
     */
    function vineyardCount() external view returns (uint256);

    /**
     * @notice View available vineyard
     * @param _index index of the future to retrieve
     * @return address the vineyard address at index
     */
    function vineyard(uint256 _index) external view returns (address);


}