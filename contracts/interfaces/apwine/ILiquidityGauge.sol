pragma solidity >=0.7.0 <0.8.0;

interface ILiquidityGauge {
    /**
     * @notice Contract Initializer
     * @param _gaugeController the address of the gauge controller
     * @param _future the address of the corresponding future
     */
    function initialize(address _gaugeController, address _future) external;

    /**
     * @notice Register new liquidity added to the future
     * @param _amount the liquidity amount added
     * @dev must be called from the future contract
     */
    function registerNewFutureLiquidity(uint256 _amount) external;

    /**
     * @notice Unregister liquidity withdrawn from to the future
     * @param _amount the liquidity amount withdrawn
     * @dev must be called from the future contract
     */
    function unregisterFutureLiquidity(uint256 _amount) external;

    /**
     * @notice update gauge and user liquidity state then return the new redeemable
     * @param _user the user to who update and return the redeemable of
     */
    function updateAndGetRedeemable(address _user) external returns(uint256);

    /**
     * @notice Log an update of the inflated volume
     */
    function updateInflatedVolume() external;

    /**
     * @notice Getter fot the last inflated amount
     * @return the last inflated amount
     */
    function getLastInflatedAmount() external view returns (uint256);

    /**
     * @notice Getter for redeemable APWs of one user
     * @param _user the user to check the redeemable APW of
     * @return the amount of redeemable APW
     */
    function getUserRedeemable(address _user) external view returns (uint256);

    /**
     * @notice Register new user liquidity
     * @param _user the user to register the liquidity of
     */
    function registerUserLiquidity(address _user) external;


    function deleteUserLiquidityRegistration(address _user) external;


    function transferUserLiquidty(address _sender, address _receiver, uint256 _amount) external;

    function updateUserLiquidity(address _user) external;

    function removeUserLiquidity(address _user, uint256 _amount) external;



}
