pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "./oz-upgradability-solc6/upgradeability/ProxyFactory.sol";


import "./interfaces/apwine/IFutureYieldToken.sol";
import "./interfaces/apwine/IAPWineFuture.sol";

import "./APWineProxy.sol";


contract APWineController is Initializable, AccessControlUpgradeSafe{

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* Attributes */

    address public APWineTreasury;
    address public APWineProxyFactory;
    address public APWineProxyLogic;    
    address public FutureYieldTokenLogic;


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
        bytes memory payload = abi.encodeWithSignature("initialize(address)", address(this));
        address NewProxy = ProxyFactory(APWineProxyFactory).deployMinimal(APWineProxyLogic, payload);
        proxiesByUser[address(msg.sender)] = NewProxy;
        usersByProxy[NewProxy] = address(msg.sender);
        emit ProxyCreated(NewProxy);
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
     * @param _APWineTreasury the address of the new treasury contract
     */
    function setTreasuryAddress(address _APWineTreasury) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        APWineTreasury = _APWineTreasury;
    }

    /**
     * @notice Change the APWineProxyFactory contract address
     * @param _APWineProxyFactory the address of the new APWineProxyFactory contract
     */
    function setAPWineProxyFactoryAddress(address _APWineProxyFactory) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        APWineProxyFactory = _APWineProxyFactory;
    }

    /**
     * @notice Change the APWineProxy contract logic address
     * @param _APWineProxyLogic the address of the new proxy logic
     */
    function setAPWineProxyLogic(address _APWineProxyLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        APWineProxyLogic = _APWineProxyLogic;
    }



    /* Views */

    /**
     * @notice Checks whether the address is a valid proxy
     * @return bool true if the given proxy is valid
     */
    function isRegisteredProxy(address _proxyAddress) public view returns (bool) {
       return usersByProxy[_proxyAddress] != address(0);
    }

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _futureAddress) public view returns (bool) {
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
