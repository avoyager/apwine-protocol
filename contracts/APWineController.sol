pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";


import "./interfaces/apwine/IFutureYieldToken.sol";
import "./interfaces/apwine/IAPWineFuture.sol";

import "./APWineProxy.sol";


contract APWineController is Initializable, AccessControlUpgradeSafe{

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* Attributes */

    address public APWineTreasuryAddress;

    using EnumerableSet for EnumerableSet.AddressSet;

    mapping (address => address) public proxiesByUser;
    mapping (address => address) public usersByProxy;

    EnumerableSet.AddressSet private futures;

    /* Events */

    event ProxyCreated(address proxy);
    event FutureRegistered(address future);

    /* Modifiers */

    /* Initializer */

    /**
     * @notice Initializer of the APWineController contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) initializer public {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }

    /* Public methods */

    /**
     * @notice Deploys a proxy for the caller
     */
    function createProxy() public {
        require(proxiesByUser[msg.sender] == address(0), "User already has proxy");
        APWineProxy proxy = new APWineProxy(address(this));
        proxy.transferOwnership(msg.sender);
        proxiesByUser[address(msg.sender)] = address(proxy);
        usersByProxy[address(proxy)] = address(msg.sender);
        emit ProxyCreated(address(proxy));
    }

    /**
     * @notice Adds a future for everyone to use
     * @param _futureAddress the address of the future
     */
    function addFuture(address _futureAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(!futures.contains(_futureAddress), "Future already registered");
        futures.add(_futureAddress);
        emit FutureRegistered(_futureAddress);
    }



    /**
     * @notice Change the APWine treasury contract address
     * @param _APWineTreasuryAddress the address of the new treasury contract
     */
    function setTreasuryAddress(address _APWineTreasuryAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        APWineTreasuryAddress = _APWineTreasuryAddress;
    }


    /* Views */

    /**
     * @notice Checks whether the address is a valid proxy
     * @return bool true if the given proxy is valid
     */
    function isRegisteredProxy(address _proxyAddress) public returns (bool) {
       return usersByProxy[_proxyAddress] != address(0);
    }

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _futureAddress) public returns (bool) {
       return futures.contains(_futureAddress);
    }

    /**
     * @notice Number of futures
     * @return uint256 the number of futures
     */
    function futuresCount() external view returns (uint256) {
        return futures.length();
    }

    /**
     * @notice View available futures
     * @param _index index of the future to retrieve
     * @return address the future address at index
     */
    function future(uint256 _index) external view returns (address) {
        return futures.at(_index);
    }

}
