
pragma solidity >=0.4.22 <0.7.3;

import "../interfaces/ERC20.sol";
import "../interfaces/IFutureYieldTokenFactory.sol";
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";


import '../interfaces/IFutureYieldToken.sol';
import '../interfaces/IAPWineProxy.sol';
import '../interfaces/IAPWineController.sol';

abstract contract APWineFuture is Initializable, AccessControlUpgradeSafe{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;


    /* Settings */
    uint256 public REGISTRATION_DELAY;
    uint256 public START_DELAY;
    uint256 public PERIOD;
    string public NAME;

    /* ACR Roles*/
    bytes32 public constant CREATION_ROLE = keccak256("CREATION_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TIMING_CONTROLLER_ROLE = keccak256("TIMING_CONTROLLER_ROLE");


    IFutureYieldToken[] public futureYieldTokens;
    IFutureYieldTokenFactory futureYieldTokenFactory;

    /* Governance */
    mapping (address => bool) public owners;
    IAPWineController public controller;

    /* Future params */
    EnumerableSet.AddressSet autoRegistered;

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
    
    Future[] public futures;

    /* Interest Bearing Token */
    address public IBTokenAddress;
    uint256 IBTokenDecimals;
    string IBTokenSymbol;
    string IBTokenName;


    /* Events */
    event FutureCreated(uint256 _beginning, address futureYieldTokenAddress, uint index); // Event
    event FuturePeriodStarted(uint index);
    event FuturePeriodEnded(uint index);

    /* Modifiers*/
    modifier onlyProxy() {
        require(controller.isRegisteredProxy(msg.sender), "Invalid proxy");
        _;
    }

    modifier periodNotStarted(uint index) {
        require(!futures[index].period_started, "Future period already started");
        _;
    }

    modifier periodNotExpired(uint index) {
        require(!((SafeMath.add(futures[index].beginning, START_DELAY)) < block.timestamp && futures[index].period_started == false), "Future period expired");
        _;
    }

    modifier previousPeriodEnded(uint index) {
        require(index == 0 || futures[index-1].period_ended, "Last future is not ended");
        _;
    }

    modifier periodIsMature(uint index) {
        require((SafeMath.add(futures[index].beginning, PERIOD)) >= block.timestamp, "Future period is not completed");
        _;
    }

    modifier periodHasEnded(uint index) {
        require(futures[index].period_ended == true, "Future period not ended");
        _;
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
    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period,address _adminAddress) initializer public virtual{

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);

        controller =  IAPWineController(_controllerAddress);
        futureYieldTokenFactory = IFutureYieldTokenFactory(_futureYieldTokenFactoryAddress);

        IBTokenAddress = _IBTokenAddress;
        IBTokenDecimals = ERC20(IBTokenAddress).decimals();
        IBTokenSymbol = ERC20(IBTokenAddress).symbol();
        IBTokenName =  ERC20(IBTokenAddress).name();

        NAME = _name;
        PERIOD = _period * (1 days);
        REGISTRATION_DELAY = 1 days;
        START_DELAY = 1 hours;

    }

    /**
    * @notice Initializer or APWIneFuture contract
    * @param _beginning Timestamp of the beginning of the future
    * @param _tokenName Name of the future interest token
    * @param _tokenSymbol Symbol of the future interest token
    */
    function createFuture(uint256 _beginning,string memory _tokenName, string memory _tokenSymbol) public {
        //require(_beginning > (block.timestamp + REGISTRATION_DELAY));
        //require(_beginning>futures[futures.length-1].beginning+PERIOD);
        require(hasRole(CREATION_ROLE, msg.sender), "Caller is not allowed to create futures");

        address futureTokenAddress = futureYieldTokenFactory.generateToken(_tokenName,_tokenSymbol);

        IFutureYieldToken futureYieldToken = IFutureYieldToken(futureTokenAddress);

        futures.push(Future({
            beginning: _beginning,
            period_started: false,
            period_ended: false,
            totalRegisteredBalance: 0,
            totalFutureTokenMinted: 0,
            registeredProxies: new IAPWineProxy[](0),
            initialBalance: 0,
            finalBalance:0
        }));
        futureYieldTokens.push(futureYieldToken);
        emit FutureCreated(_beginning, address(futureYieldToken), futures.length - 1);
    }

    /**
    * @notice Register proxies to a future
    * @param _index Index of the future to be registered to
    * @param _amount Amount of token to register to this period
    * @param _autoRegister Switch for auto-enrolment for the next periods
    * @dev To be called by proxies
    */    
    function registerToPeriod(uint _index, uint256 _amount, bool _autoRegister) periodNotStarted(_index) periodNotExpired(_index) onlyProxy public {
        if (_autoRegister){
            autoRegistered.add(msg.sender);
        }
        futures[_index].registeredBalances[msg.sender] = SafeMath.add(futures[_index].registeredBalances[msg.sender], _amount);
        futures[_index].registrations[msg.sender] = true;
        futures[_index].totalRegisteredBalance = SafeMath.add(futures[_index].totalRegisteredBalance ,_amount);
        futures[_index].registeredProxies.push(IAPWineProxy(address(msg.sender)));
    }

    /**
    * @notice Internal function to register proxies that are on the auto-registration list
    * @param _index Index of the future to be registered to
    * @param _amount Amount of token to register to this period
    * @param _proxy Address of the proxy to register automatically
    */    
    function registerBalanceToPeriod(uint _index, uint256 _amount, address _proxy) periodNotStarted(_index) periodNotExpired(_index) internal {
        futures[_index].registeredBalances[_proxy] = SafeMath.add(futures[_index].registeredBalances[_proxy],_amount);
        futures[_index].registrations[_proxy] = true;
        futures[_index].totalRegisteredBalance = SafeMath.add(futures[_index].totalRegisteredBalance,_amount);
        futures[_index].registeredProxies.push(IAPWineProxy(_proxy));
    }

    /**
    * @notice Unregister a defined amount of tokens from a period
    * @param _index Index of the future to be unregistered from
    * @param _amount Amount of tokens to unregister from this period
    */    
    function unregisterAmountToPeriod(uint _index, uint256 _amount) periodNotStarted(_index) public {
        require(_amount > 0, "Invalid amount to unregister");
        require(_amount <= futures[_index].registeredBalances[msg.sender], "Insufficient balance");

        futures[_index].registeredBalances[msg.sender] = SafeMath.sub(futures[_index].registeredBalances[msg.sender],_amount);
        futures[_index].totalRegisteredBalance = SafeMath.sub(futures[_index].totalRegisteredBalance,_amount);

        if (futures[_index].registeredBalances[msg.sender] == 0){
            futures[_index].registrations[msg.sender] = false;
        }
    }

    /**
    * @notice Unregister a the whole registered user balance from a future
    * @param _index Index of the future to be unregistered from
    */    
    function unregisterToPeriod(uint _index) periodNotStarted(_index) public {
        require(futures[_index].registrations[msg.sender] == true, "User not registered for this future");

        uint256 balance = futures[_index].registeredBalances[msg.sender];
        futures[_index].registeredBalances[msg.sender] = 0;
        futures[_index].totalRegisteredBalance = SafeMath.sub(futures[_index].totalRegisteredBalance,balance);

        futures[_index].registrations[msg.sender] = false;

        autoRegistered.remove(msg.sender);
    }

    /**
    * @notice Start the corresponding future 
    * @param _index Index of the future to be started
    */  
    function startFuture(uint _index) public virtual;

    /**
    * @notice Stop the corresponding future 
    * @param _index Index of the future to be stopped
    */  
    function endFuture(uint _index) public virtual;

    /**
    * @notice Claim the yield of the sender
    * @param _index Index of the future from where to claim the yield
    */  
    function claimYield(uint _index) public virtual;

    /* Timing related setters */

    /**
    * @notice Admin setter for the registration delay
    * @param _newRegDelay new registration delay
    */  
    function setRegistrationDelay(uint256 _newRegDelay) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        REGISTRATION_DELAY = _newRegDelay;
    }

    /**
    * @notice Admin setter for the start delay
    * @param _newStartDelay new start delay
    */  
    function setStartDelay(uint256 _newStartDelay) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        START_DELAY = _newStartDelay;
    }

    /**
    * @notice Admin setter for the period length 
    * @param _newPeriod new period length
    */  
    function setPeriod(uint256 _newPeriod) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        PERIOD = _newPeriod;
    }

}