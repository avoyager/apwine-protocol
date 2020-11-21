pragma solidity >=0.4.22 <0.7.3;


interface IAPWineController {
    /* Getters */

    function APWineTreasuryAddress() external view returns(address);

    function FutureYieldTokenLogic() external view returns(address);

    function APWineProxyFactory() external view returns(address);

    function APWineIBTLogic() external view returns(address);


    /* Initializer */

    /**
     * @notice Initializer of the APWineController contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) external;

    /* Public methods */

    /**
     * @notice Adds a future for everyone to use
     * @param _vineyardAddress the address of the future
     */
    function addVineyard(address _vineyardAddress) external;

    /**
     * @notice Removes a future from the registered future list
     * @param _vineyardAddress the address of the future
     */
    function delFuture(address _vineyardAddress) external;

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

    /* User Methods */

    /**
     * @notice Register the sender to the corresponding vineyard
     * @param _vineyardAddress the address of the vineyard to be registered to
     * @param _amount the amount to register
     */
    function register(address _vineyardAddress, uint256 _amount) external;

    /* Views */

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _vineyardAddress) external view returns (bool);

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
