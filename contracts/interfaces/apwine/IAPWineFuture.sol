
pragma solidity >=0.4.22 <0.7.3;
import "./IAPWineProxy.sol";


interface IAPWineFuture {

    /* Future struct*/
    struct Future {
        uint256 beginning;
        bool period_started;
        bool period_ended;

        mapping (address => uint256) registeredBalances;
        mapping (address => bool) registrations;
        IAPWineProxy[] registeredProxies;

        uint256 totalRegisteredBalance;
        uint256 totalFutureTokenMinted;
        uint256 initialBalance;
        uint256 finalBalance;
    }
    
    /**
    * @notice Initializer or APWIneFuture contract
    * @param _controllerAddress Address of APWineController
    * @param _futureYieldTokenFactoryAddress Address of the future yield tokens factory
    * @param _IBTokenAddress Address or the interest bearing token of the platform
    * @param _name Name of this future
    * @param _period Period of this future
    * @param _adminAddress Address of the admin for roles
    */
    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period,address _adminAddress) external;

    /**
    * @notice Initializer or APWIneFuture contract
    * @param _beginning Timestamp of the beginning of the future
    * @param _tokenName Name of the future interest token
    * @param _tokenSymbol Symbol of the future interest token
    */
    function createFuture(uint256 _beginning,string memory _tokenName, string memory _tokenSymbol) external;

    /**
    * @notice Register proxies to a future
    * @param _index Index of the future to be registered to
    * @param _amount Amount of token to register to this period
    * @param _autoRegister Switch for auto-enrolment for the next periods
    * @dev To be called by proxies
    */    
    function registerToPeriod(uint _index, uint256 _amount, bool _autoRegister) external;

    /**
    * @notice Unregister a defined amount of tokens from a period
    * @param _index Index of the future to be unregistered from
    * @param _amount Amount of tokens to unregister from this period
    */    
    function unregisterAmountToPeriod(uint _index, uint256 _amount) external;

    /**
    * @notice Unregister a the whole registered user balance from a future
    * @param _index Index of the future to be unregistered from
    */    
    function unregisterToPeriod(uint _index) external;
    /**
    * @notice Start the corresponding future 
    * @param _index Index of the future to be started
    */  
    function startFuture(uint _index) external;

    /**
    * @notice Stop the corresponding future 
    * @param _index Index of the future to be stopped
    */  
    function endFuture(uint _index) external;

    /**
     * @notice Quit an ongoing future
     * @param _index the period index to quit from
     * @param _amount the amount to withdraw
     */
    function quitFuture(uint _index, uint _amount) external;

    /**
    * @notice Claim the yield of the sender
    * @param _index Index of the future from where to claim the yield
    */  
    function claimYield(uint _index) external;

    /* Timing related setters */

    /**
    * @notice Admin setter for the registration delay
    * @param _newRegDelay new registration delay
    */  
    function setRegistrationDelay(uint256 _newRegDelay) external;

    /**
    * @notice Admin setter for the start delay
    * @param _newStartDelay new start delay
    */  
    function setStartDelay(uint256 _newStartDelay) external;
    /**
    * @notice Admin setter for the period length 
    * @param _newPeriod new period length
    */  
    function setPeriod(uint256 _newPeriod) external;


    /**
    * @notice Getter for the interest bearing token of a future
    * @return address of the interest bearing token
    */  
    function IBTokenAddress() external returns(address);

    /**
    * @notice Return the index of the next period for this future 
    * @return The inde of the next period
    */  
    function getNextPeriodIndex() external view returns(uint256);


    /**
    * @notice Return the locked balance of a proxy
    * @param _proxy the address of the proxy
    * @return The locked balance of the proxy
    */  
    function getProxyLockedBalance(address _proxy) external view returns(uint256);


}