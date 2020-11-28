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
    event TreasuryAddressChanged(address _treasuryAddress);


    /* Vineyard Settings */
    uint256 public STARTING_DELAY;

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
     * @notice Adds a vineyard for everyone to use
     * @param _vineyardAddress the address of the vineyard
     */
    function addVineyard(address _vineyardAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(vineyards.add(_vineyardAddress), "Vineyard already registered");
        emit VineyardRegistered(_vineyardAddress);
    }

    /**
     * @notice Removes a vineyard from the registered vineyards list
     * @param _vineyardAddress the address of the vineyard
     */
    function delVineyard(address _vineyardAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(vineyards.remove(_vineyardAddress), "Vineyard not registered");
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
        emit TreasuryAddressChanged(_APWineTreasury);
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

    /* Vineyard Settings Setters */

    /**
     * @notice Change the delay for starting a new period
     * @param _startingDelay the new delay (+-) to start the next period
     */
    function setPeriodStartingDelay(uint256 _startingDelay) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        STARTING_DELAY = _startingDelay;
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
        IAPWineVineyard(_vineyardAddress).register(msg.sender,_amount);
        require(ERC20(vineyard.getIBTAddress()).transferFrom(msg.sender, address(_vineyardAddress),_amount), "Insufficient funds");
    }

    /**
     * @notice Register the sender to the corresponding vineyard
     * @param _winemaker the address of the winemaker
     * @param _vineyardAddress the addresses of the vineyards to claim the fyts from
     */
    function claimSelectedYield(address _winemaker, address[] memory _vineyardAddress) public {
        for(uint256 i = 0;  i<_vineyardAddress.length;i++){
            require(vineyards.contains(_vineyardAddress[i]),"Incorrect vineyard address");
            IAPWineVineyard(_vineyardAddress[i]).claimFYT(_winemaker);
        }
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
     * @notice Checks whether the address is a valid future
     * @param _winemaker the address of the winemaker
     * @return array of vineyards addresses where the winemaker can claim fyt
     * @dev shouldn't be called in a contract
     */
    function getVineyardWithClaimableFYT(address _winemaker) external view returns (address[] memory) {
        address[] memory selectedVineyards = new address[](vineyards.length());
        uint8 index = 0;
        for (uint256 i = 0; i < vineyards.length(); i++) { 
             if(IAPWineVineyard(vineyards.at(i)).hasClaimableFYT(_winemaker)){
                 selectedVineyards[i]= vineyards.at(i);
                 index +=1;
             }
        }
        return selectedVineyards;
    }

    /**
     * @notice Checks whether the address is a valid future
     * @param _winemaker the address of the winemaker
     * @return array of vineyards addresses where the winemaker can claim ibt
     * @dev shouldn't be called in a contract
     */
    function getVineyardWithClaimableAPWIBT(address _winemaker) external view returns (address[] memory) {
        address[] memory selectedVineyards = new address[](vineyards.length());
        uint8 index = 0;
        for (uint256 i = 0; i < vineyards.length(); i++) { 
             if(IAPWineVineyard(vineyards.at(i)).hasClaimableAPWIBT(_winemaker)){
                 selectedVineyards[i]= vineyards.at(i);
                index +=1;
             }
        }
        return selectedVineyards;
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
