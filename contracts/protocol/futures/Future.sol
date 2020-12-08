
pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

import "../../interfaces/ERC20.sol";
import "../../interfaces/IProxyFactory.sol";

import "../tokens/FutureYieldToken.sol";
import "../../libraries/APWineMaths.sol";
import "../../libraries/APWineNaming.sol";

import "../tokens/APWineIBT.sol";

import "../../interfaces/apwine/IFutureWallet.sol";
import "../../interfaces/apwine/IController.sol";
import "../../interfaces/apwine/IFutureVault.sol";


abstract contract Future is Initializable,AccessControlUpgradeSafe{

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
    IFutureVault internal futureVault;
    IFutureWallet internal futureWallet;
    ERC20 internal ibt;
    APWineIBT internal apwibt;
    IController internal controller;

    /* Settings */
    uint256 public PERIOD;
    string public PLATFORM;
    bool public PAUSED;
    string public PERIOD_DENOMINATOR;

    /* Events */
    event UserRegistered(address _userAddress,uint256 _amount, uint256 _periodIndex);
    event NewPeriodStarted(uint256 _newPeriodIndex, address _fytAddress);

    /* Modifiers */
    modifier nextPeriodAvailable(){
        uint256 controllerDelay = controller.STARTING_DELAY();
        require(getNextPeriodTimestamp()<block.timestamp.add(controllerDelay), "Next period start range not reached yet");
        _;
    }

    modifier periodsActive(){
        require(!PAUSED, "New periods are currently paused");
        _;
    }

    /* Initializer */
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength,string memory _periodDenominator,string memory _platform, string memory _tokenName, string memory _tokenSymbol,address _adminAddress) public initializer virtual{
        controller =  IController(_controllerAddress);
        ibt = ERC20(_ibt);
        PERIOD = _periodLength * (1 days);
        PLATFORM = _platform;
        PERIOD_DENOMINATOR = _periodDenominator;

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(CAVIST_ROLE, _adminAddress);
        _setupRole(CONTROLLER_ROLE, _controllerAddress);
        
        registrationsTotals.push();
        registrationsTotals.push();
        fyts.push();
        nextPeriodTimestamp.push();
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        apwibt = APWineIBT(IProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.APWineIBTLogic(), payload));
    }

    /* Period functions */
    function startNewPeriod() public virtual;

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
    function claimFYT(address _user) public virtual{
        require(hasClaimableFYT(_user),"The is not fyt claimable for this address");
        if(hasClaimableAPWIBT(_user)) claimAPWIBT(_user);
        else _claimFYT(_user);   
    }

    function _claimFYT(address _user) internal virtual{
        uint256 nextIndex = getNextPeriodIndex();
        for(uint256 i = lastPeriodClaimed[_user]+1; i<nextIndex;i++){
            claimFYTforPeriod(_user, i); // TODO gas cost can be optimized
        }
    }

    function claimFYTforPeriod(address _user, uint256 _periodIndex) internal virtual{
        assert((lastPeriodClaimed[_user]+1)==_periodIndex);
        assert(_periodIndex<getNextPeriodIndex());
        assert(_periodIndex!=0);
        lastPeriodClaimed[_user] = _periodIndex;
        fyts[_periodIndex].transfer(_user,apwibt.balanceOf(_user));
    }

    function claimAPWIBT(address _user) internal virtual{
        uint256 nextIndex = getNextPeriodIndex();
        uint256 claimableAPWIBT = getClaimableAPWIBT(_user);
        // require(claimableAPWIBT>0, "There are no ibt claimable at the moment for this address");

        if(_hasOnlyClaimableFYT(_user)) _claimFYT(_user);
        apwibt.transfer(_user, claimableAPWIBT);

        for (uint i = registrations[_user].startIndex; i<nextIndex; i++){ // get not claimed fyt
            fyts[i].transfer(_user,claimableAPWIBT);
        }

        lastPeriodClaimed[_user] = nextIndex-1;
        delete registrations[_user];
    }

    function withdrawLockFunds(uint _amount) public virtual{
        require(_amount>0, "Amount to withdraw must be positive");
        if(hasClaimableAPWIBT(msg.sender)){
            claimAPWIBT(msg.sender);
        }else if(hasClaimableFYT(msg.sender)){
            claimFYT(msg.sender);
        }

        uint256 fundsToBeUnlocked = getUnlockableFunds(msg.sender);
        uint256 unrealisedYield = getUnrealisedYield(msg.sender);
        require(apwibt.transferFrom(msg.sender,address(this),_amount),"Invalid amount of APWIBT");
        require(fyts[getNextPeriodIndex()-1].transferFrom(msg.sender,address(this),_amount),"Invalid amount of FYT of last period");

        apwibt.burn(_amount);
        fyts[getNextPeriodIndex()-1].burn(_amount);

        ibt.transferFrom(address(futureVault), msg.sender, fundsToBeUnlocked); // only send locked, TODO Send Yield
        ibt.transferFrom(address(futureVault), controller.APWineTreasury(),unrealisedYield);

    }

    /* Utilitaries functions */
    function deployFutureYieldToken() internal returns(address){
        string memory tokenDenomination = APWineNaming.genTokenSymbol(uint8(getNextPeriodIndex()), ibt.symbol(),PLATFORM, PERIOD_DENOMINATOR);
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", tokenDenomination, tokenDenomination, address(this));
        FutureYieldToken newToken = FutureYieldToken(IProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.FutureYieldTokenLogic(), payload));
        fyts.push(newToken);
        newToken.mint(address(this),apwibt.totalSupply().mul(10**( uint256(18-ibt.decimals()) ))); 
        return address(newToken);
    }

    /* Setters */
    function setFutureVault(address _futureVaultAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future vault address");
        futureVault = IFutureVault(_futureVaultAddress);
    }

    function setFutureWallet(address _futureWalletAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        futureWallet = IFutureWallet(_futureWalletAddress);
    }

    function setNextPeriodTimestamp(uint256 _nextPeriodTimestamp) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set next period timestamp");
        nextPeriodTimestamp[nextPeriodTimestamp.length-1]=_nextPeriodTimestamp;
    }

    function setPeriodDenominator(string memory _periodDenominator) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set period denominator");
        PERIOD_DENOMINATOR = _periodDenominator;
    }

    /* Getters */
    function hasClaimableFYT(address _user) public view returns(bool){
        return hasClaimableAPWIBT(_user) || _hasOnlyClaimableFYT(_user);
    }

    function _hasOnlyClaimableFYT(address _user) internal view returns(bool){
        return lastPeriodClaimed[_user]!=0  && lastPeriodClaimed[_user]<getNextPeriodIndex()-1;
    }

    function hasClaimableAPWIBT(address _user) public view returns(bool){
        return (registrations[_user].startIndex < getNextPeriodIndex()) && (registrations[_user].scaledBalance>0);
    }

    function getNextPeriodIndex() public view virtual returns(uint256){
        return registrationsTotals.length-1;
    }

    function getClaimableAPWIBT(address _user) public view virtual returns(uint256);

    function getUnlockableFunds(address _user) public view virtual returns(uint256){
        return getClaimableAPWIBT(_user).add(apwibt.balanceOf(_user));
    }

    function getRegisteredAmount(address _user) public view virtual returns(uint256);
    function getUnrealisedYield(address _user) public view virtual returns(uint256);

    function getNextPeriodTimestamp() public view returns(uint256){
        return nextPeriodTimestamp[nextPeriodTimestamp.length-1];
    }

    function getFutureVaultAddress() public view returns(address){
        return address(futureVault);
    }

    function getFutureWalletAddress() public view returns(address){
        return address(futureWallet);
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
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to pause future");
        PAUSED = true;
    }

    function resumePeriods() public{
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to resume future");
        PAUSED = false;
    }

    /* Security functions */

}