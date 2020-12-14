pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "contracts/interfaces/apwine/IFuture.sol";


contract Controller is Initializable, AccessControlUpgradeable{

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /* Attributes */

    address public APWineTreasury;
    address public APWineProxyFactory;
    address public APWineIBTLogic;
    address public FutureYieldTokenLogic;


    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private futures;

    /* Events */

    event FutureRegistered(address _futureAddress);
    event FutureUnregistered(address _futureAddress);
    event TreasuryAddressChanged(address _treasuryAddress);


    /* Future Settings */
    uint256 public STARTING_DELAY;

    /* Modifiers */

    /* Initializer */

    /**
     * @notice Initializer of the Controller contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) initializer public {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }

    /* Public methods */

    /**
     * @notice Adds a future for everyone to use
     * @param _futureAddress the address of the future
     */
    function addFuture(address _futureAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(futures.add(_futureAddress), "Future already registered");
        emit FutureRegistered(_futureAddress);
    }

    /**
     * @notice Removes a future from the registered futures list
     * @param _futureAddress the address of the future
     */
    function delFuture(address _futureAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(futures.remove(_futureAddress), "Future not registered");
        emit FutureUnregistered(_futureAddress);
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

    /* Future Settings Setters */

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
     * @notice Register the sender to the corresponding future
     * @param _futureAddress the address of the future to be registered to
     * @param _amount the amount to register
     */
    function register(address _futureAddress, uint256 _amount) public {
        require(futures.contains(_futureAddress), "Invalid future address");
        IFuture future = IFuture(_futureAddress);
        IFuture(_futureAddress).register(msg.sender,_amount);
        require(ERC20(future.getIBTAddress()).transferFrom(msg.sender, address(_futureAddress),_amount), "Insufficient funds");
    }

    /**
     * @notice Register the sender to the corresponding future
     * @param _user the address of the user
     * @param _futureAddress the addresses of the futures to claim the fyts from
     */
    function claimSelectedYield(address _user, address[] memory _futureAddress) public {
        for(uint256 i = 0;  i<_futureAddress.length;i++){
            require(futures.contains(_futureAddress[i]),"Incorrect future address");
            IFuture(_futureAddress[i]).claimFYT(_user);
        }
    }

    /* Views */

    /**
     * @notice Checks whether the address is a valid future
     * @return bool true if the given future is valid
     */
    function isRegisteredFuture(address _futureAddress) public view returns (bool) {
       return futures.contains(_futureAddress);
    }

    /**
     * @notice Checks whether the address is a valid future
     * @param _user the address of the user
     * @return array of futures addresses where the user can claim fyt
     * @dev shouldn't be called in a contract
     */
    function getFutureWithClaimableFYT(address _user) external view returns (address[] memory) {
        address[] memory selectedFutures = new address[](futures.length());
        uint8 index = 0;
        for (uint256 i = 0; i < futures.length(); i++) { 
             if(IFuture(futures.at(i)).hasClaimableFYT(_user)){
                 selectedFutures[i]= futures.at(i);
                 index +=1;
             }
        }
        return selectedFutures;
    }

    /**
     * @notice Checks whether the address is a valid future
     * @param _user the address of the user
     * @return array of futures addresses where the user can claim ibt
     * @dev shouldn't be called in a contract
     */
    function getFutureWithClaimableAPWIBT(address _user) external view returns (address[] memory) {
        address[] memory selectedFutures = new address[](futures.length());
        uint8 index = 0;
        for (uint256 i = 0; i < futures.length(); i++) { 
             if(IFuture(futures.at(i)).hasClaimableAPWIBT(_user)){
                 selectedFutures[i]= futures.at(i);
                index +=1;
             }
        }
        return selectedFutures;
    }

    /**
     * @notice Number of future
     * @return uint256 the number of future
     */
    function futureCount() external view returns (uint256) {
        return futures.length();
    }

    /**
     * @notice View available future
     * @param _index index of the future to retrieve
     * @return address the future address at index
     */
    function future(uint256 _index) external view returns (address) {
        return futures.at(_index);
    }

}
