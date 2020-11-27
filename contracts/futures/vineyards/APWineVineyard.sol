
pragma solidity >=0.4.22 <0.7.3;


import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";

import "../../interfaces/ERC20.sol";
import "../../FutureYieldToken.sol";
import "../../libraries/APWineMaths.sol";
import "../../APWineIBT.sol";
import "../../interfaces/apwine/IAPWineCellar.sol";
import "../../interfaces/apwine/IAPWineController.sol";
import "../../interfaces/apwine/IAPWineFutureWallet.sol";
import "../../oz-upgradability-solc6/upgradeability/ProxyFactory.sol";


abstract contract APWineVineyard is Initializable, AccessControlUpgradeSafe{

    using SafeMath for uint256;

    /* Structs */
    struct Registration{
        uint256 startIndex;
        uint256 scaledBalance;
    }

    uint256[] registrationsTotals;

    /* ACR ROLE */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAVIST_ROLE = keccak256("CAVIST_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* State variables */
    mapping(address=>uint256) internal lastPeriodClaimed;
    mapping(address=>Registration) internal registrations;
    uint256[] internal nextPeriodTimestamp;
    FutureYieldToken[] public fyts;


    /* External contracts */
    IAPWineFutureWallet internal futureWallet;
    IAPWineCellar internal cellar;
    ERC20 internal ibt;
    APWineIBT internal apwibt;
    IAPWineController internal controller;

    /* Settings */
    uint256 public PERIOD;
    bool public PAUSED;

    /* Events */
    event UserRegistered(address _userAddress,uint256 _amount, uint256 _periodIndex);
    event NewPeriodStarted(uint256 _newPeriodIndex, address _fytAddress);

    /* Modifiers */
    modifier nextPeriodAvailable(){
        uint256 controllerDelay = controller.STARTING_DELAY();
        require(getNextPeriodTimestamp()>block.timestamp.sub(controllerDelay), "The next period start range has not been reached yet");
        _;
    }

    modifier periodsActive(){
        require(!PAUSED, "New periods are currently paused");
        _;
    }


    /* Initializer */
    /**
    * @notice Intializer
    * @param _controllerAddress the address of the controller
    * @param _ibt the address of the corresponding ibt
    * @param _periodLength the length of the period (in days)
    * @param _tokenName the APWineIBT name
    * @param _tokenSymbol the APWineIBT symbol
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength, string memory _tokenName, string memory _tokenSymbol,address _adminAddress) public initializer virtual{
        controller =  IAPWineController(_controllerAddress);
        ibt = ERC20(_ibt);
        PERIOD = _periodLength * (1 days);

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(CAVIST_ROLE, _adminAddress);
        _setupRole(CONTROLLER_ROLE, _controllerAddress);
        
        registrationsTotals.push();
        registrationsTotals.push();
        fyts.push();
        nextPeriodTimestamp.push();
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        apwibt = APWineIBT(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.APWineIBTLogic(), payload));
    }

    /* Period functions */
    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual;


    function register(address _winegrower ,uint256 _amount) public virtual periodsActive{   
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to register a wallet");
        uint256 nextIndex = getNextPeriodIndex();
        if(registrations[_winegrower].scaledBalance==0){ // User has no record
            _register(_winegrower,_amount);
        }else{
            if(registrations[_winegrower].startIndex == nextIndex){ // User has already an existing registration for the next period
                 registrations[_winegrower].scaledBalance = registrations[_winegrower].scaledBalance.add(_amount);
            }else{ // User had an unclaimed registation from a previous period
                claimAPWIBT(_winegrower);
                _register(_winegrower,_amount);
            }
        }
        emit UserRegistered(_winegrower,_amount, nextIndex);
    }


    function _register(address _winegrower, uint256 _initialScaledBalance) virtual internal{
        registrations[_winegrower] = Registration({
                startIndex:getNextPeriodIndex(),
                scaledBalance:_initialScaledBalance
        });
    } 
    
    function unregister(uint256 _amount) public virtual;


    /* Claim functions */
    function claimFYT(address _winemaker) public virtual{
        require(hasClaimableFYT(_winemaker),"The is not fyt claimable for this address");
        uint256 nextIndex = getNextPeriodIndex();
        for(uint256 i = lastPeriodClaimed[_winemaker]+1; i<nextIndex;i++){
            claimFYTforPeriod(_winemaker, i); // TODO gas cost can be optimized
        }
    }

    function claimFYTforPeriod(address _winemaker, uint256 _periodIndex) internal virtual{
        assert((lastPeriodClaimed[_winemaker]+1)==_periodIndex);
        assert(_periodIndex<getNextPeriodIndex());
        assert(_periodIndex!=0);
        lastPeriodClaimed[_winemaker] = _periodIndex;
        fyts[_periodIndex].transfer(_winemaker,apwibt.balanceOf(_winemaker));
    }

    function claimAPWIBT(address _winemaker) public virtual{
        uint256 nextIndex = getNextPeriodIndex();
        uint256 claimableAPWIBT = getClaimableAPWIBT(_winemaker);
        require(claimableAPWIBT>0, "There are no ibt claimable at the moment for this address");
        if(hasClaimableFYT(_winemaker)){
            claimFYT(_winemaker); 
        }
        apwibt.transfer(_winemaker, claimableAPWIBT);
        for (uint i = registrations[_winemaker].startIndex; i<nextIndex; i++){ // get not claimed fyt
            fyts[i].transfer(_winemaker,claimableAPWIBT);
        }
        lastPeriodClaimed[_winemaker] = nextIndex-1;
        delete registrations[_winemaker];
    }

    function withdrawLockFunds(uint _amount) public virtual{
        require(_amount>0, "Amount to withdraw must be positive");
        if(hasClaimableAPWIBT(msg.sender)){
            claimAPWIBT(msg.sender);
        }else if(hasClaimableFYT(msg.sender)){
            claimFYT(msg.sender);
        }

        uint256 fundsToBeUnlocked = getUnlockableFunds(msg.sender);
        uint256 getUnrealisedYield = getUnrealisedYield(msg.sender);
        require(apwibt.transferFrom(msg.sender,address(this),_amount),"Invalid amount of APWIBT");
        require(fyts[getNextPeriodIndex()-1].transferFrom(msg.sender,address(this),_amount),"Invalid amount of FYT of last period");

        apwibt.burn(_amount);
        fyts[getNextPeriodIndex()-1].burn(_amount);

        ibt.transferFrom(address(futureWallet), msg.sender, fundsToBeUnlocked); // only send locked, TODO Send Yield
        ibt.transferFrom(address(futureWallet), controller.APWineTreasuryAddress(),getUnrealisedYield);

    }

    /* Utilitaries functions */
    function deployFutureYieldToken(string memory _tokenName, string memory _tokenSymbol) internal returns(address){
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        FutureYieldToken newToken = FutureYieldToken(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.FutureYieldTokenLogic(), payload));
        fyts.push(newToken);
        newToken.mint(address(this),apwibt.totalSupply().mul(10**( uint256(18-ibt.decimals()) ))); 
        return address(newToken);
    }

    /* Setters */
    function setFutureWallet(address _futureWalletAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        futureWallet = IAPWineFutureWallet(_futureWalletAddress);
    }

    function setCellar(address _cellarAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        cellar = IAPWineCellar(_cellarAddress);
    }

    function setNextPeriodTimestamp(uint256 _nextPeriodTimestamp) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        nextPeriodTimestamp[nextPeriodTimestamp.length-1]=_nextPeriodTimestamp;
    }

    /* Getters */
    function hasClaimableFYT(address _winemaker) public view returns(bool){
        return lastPeriodClaimed[_winemaker]!=0  && lastPeriodClaimed[_winemaker]<getNextPeriodIndex();
    }

    function hasClaimableAPWIBT(address _winemaker) public view returns(bool){
        return (registrations[_winemaker].startIndex < getNextPeriodIndex()) && (registrations[_winemaker].scaledBalance>0);
    }

    function getNextPeriodIndex() public view virtual returns(uint256){
        return registrationsTotals.length-1;
    }

    function getClaimableAPWIBT(address _winemaker) public view virtual returns(uint256);

    function getUnlockableFunds(address _winemaker) public view virtual returns(uint256){
        return getClaimableAPWIBT(_winemaker).add(apwibt.balanceOf(_winemaker));
    }

    function getRegisteredAmount(address _winemaker) public view virtual returns(uint256);
    function getUnrealisedYield(address _winemaker) public view virtual returns(uint256);

    function getNextPeriodTimestamp() public view returns(uint256){
        return nextPeriodTimestamp[nextPeriodTimestamp.length-1];
    }

    function getFutureWalletAddress() public view returns(address){
        return address(futureWallet);
    }

    function getCellarAddress() public view returns(address){
        return address(cellar);
    }

    function getIBTAddress() public view returns(address){
        return address(ibt);
    }

    function getAPWIBTAddress() public view returns(address){
        return address(apwibt);
    }


    function getFYTofPeriod(uint256 _periodIndex) public view returns(address){
        require(_periodIndex<getNextPeriodIndex(), "The isnt any fyt for this period yet");
        return address(fyts[_periodIndex]);
    }

    /* Admin function */
    function pausePeriods() public{
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        PAUSED = true;
    }

    function resumePeriods() public{
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        PAUSED = false;
    }

    /* Security functions */


}