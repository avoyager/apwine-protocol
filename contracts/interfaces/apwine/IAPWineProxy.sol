pragma solidity >=0.4.22 <0.7.3;

interface IAPWineProxy{
    /* Public */

    /**
     * @notice Withdraws a token amount from the proxy
     * @param _token the token to withdraw
     * @param _amount the amount to withdraw
     */
    function withdraw(address _token, uint256 _amount) external;

    /**
     * @notice Registers to a future
     * @param _futureAddress the future address to register to
     * @param _index the period index to register ti
     * @param _amount the amount to register
     * @param _autoRegister whether to register again automatically when the period ends
     */

    function registerToFuture(address _futureAddress, uint256 _index, uint256 _amount, bool _autoRegister) external;

    /**
     * @notice Unregisters from a future
     * @param _futureAddress the future address to unregister from
     * @param _index the period index to unregister from
     * @param _amount the amount to unregister
     */
    function unregisterFromFuture(address _futureAddress, uint256 _index, uint256 _amount) external;

    /**
     * @notice Register funds of the proxy from the future
     * @param _amount the amount of funds to register
     */
    function registerFunds(uint256 _amount) external;

    /**
     * @notice Sends registered funds from the proxy to a future
     * @param _amount amount to be collected by the future
     * @dev The future calls this function to transfer all registered funds when the period starts
     */
    function collect(uint256 _amount) external;

}