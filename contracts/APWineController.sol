pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "./oz-upgradability-solc6/upgradeability/ProxyFactory.sol";


import "./interfaces/apwine/IFutureYieldToken.sol";
import "./interfaces/apwine/IAPWineVineyard.sol";



contract APWineController is Initializable, AccessControlUpgradeSafe{

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* Attributes */

    address public APWineTreasury;
    address public APWineProxyFactory;
    address public APWineIBTLogic;
    address public FutureYieldTokenLogic;


    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private vineyards;

    /* Events */

    event VineyardRegistered(address _vineyardAddress);
    event VineyardUnregistered(address _vineyardAddress);


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
     * @notice Adds a future for everyone to use
     * @param _vineyardAddress the address of the future
     */
    function addVineyard(address _vineyardAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(vineyards.add(_vineyardAddress), "Future already registered");
        emit VineyardRegistered(_vineyardAddress);
    }

    /**
     * @notice Removes a future from the registered future list
     * @param _vineyardAddress the address of the future
     */
    function delFuture(address _vineyardAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(vineyards.remove(_vineyardAddress), "Future not registered");
        emit VineyardUnregistered(_vineyardAddress);
    }


    /* Admin methods */

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
     * @param _FutureYieldTokenLogic the address of the new proxy logic
     */
    function setFutureYieldTokenLogic(address _FutureYieldTokenLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        FutureYieldTokenLogic = _FutureYieldTokenLogic;
    }

    /**
     * @notice Change the APWineIBT contract logic address
     * @param _APWineIBTLogic the address of the new APWineIBTlogic
     */
    function setAPWineIBTLogic(address _APWineIBTLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        APWineIBTLogic = _APWineIBTLogic;
    }


    /* User Methods */

    /**
     * @notice Register the sender to the corresponding vineyard
     * @param _vineyardAddress the address of the vineyard to be registered to
     * @param _amount the amount to register
     */
    function register(address _vineyardAddress, uint256 _amount) public {
        require(vineyards.contains(_vineyardAddress), "Invalid vineyard address");
        IAPWineVineyard vineyard = IAPWineVineyard(_vineyardAddress);
        require(ERC20(vineyard.getIBTAddress()).transferFrom(msg.sender, address(this),_amount), "Insufficient funds");
        IAPWineVineyard(_vineyardAddress).register(msg.sender,_amount);
    }

    /* Views */

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _vineyardAddress) public view returns (bool) {
       return vineyards.contains(_vineyardAddress);
    }

    /**
     * @notice Number of vineyard
     * @return uint256 the number of vineyard
     */
    function vineyardCount() external view returns (uint256) {
        return vineyards.length();
    }

    /**
     * @notice View available vineyard
     * @param _index index of the future to retrieve
     * @return address the vineyard address at index
     */
    function vineyard(uint256 _index) external view returns (address) {
        return vineyards.at(_index);
    }

}
