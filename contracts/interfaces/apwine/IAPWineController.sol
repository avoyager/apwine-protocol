pragma solidity >=0.4.22 <0.7.3;


import "./IFutureYieldToken.sol";
import "./IAPWineProxy.sol";
import "./IAPWineFuture.sol";

interface IAPWineController {
    /* Getters */

    function APWineTreasuryAddress() external view returns(address);

    function  FutureYieldTokenLogic() external view returns(address);

    /**
     * @notice Initializer of the APWineController contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) external;

    /* Public methods */

    /**
     * @notice Deploys a proxy for the caller
     */
    function createProxy() external;

    /**
     * @notice Adds a future for everyone to use
     * @param _futureAddress the address of the future
     */
    function addFuture(address _futureAddress) external;

    /* Views */

    /**
     * @notice Checks whether the address is a valid proxy
     * @return bool true if the given proxy is valid
     */
    function isRegisteredProxy(address _proxyAddress) external returns (bool);

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _futureAddress) external returns (bool);

    /**
     * @notice Number of futures
     * @return uint256 the number of futures
     */
    function futuresCount() external view returns (uint256);

    /**
     * @notice View available futures
     * @param _index index of the future to retrieve
     * @return address the future address at index
     */
    function future(uint256 _index) external view returns (address);

}
