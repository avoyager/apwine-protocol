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

abstract contract APWineRateIBTVineyard is Initializable, AccessControlUpgradeSafe{

    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAVIST_ROLE = keccak256("CAVIST_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");


    IAPWineFutureWallet private futureWallet;
    IAPWineCellar private cellar;
    ERC20 internal ibt;
    APWineIBT private apwibt;
    IAPWineController private controller;

    uint256 apwibtRate;

    /* Settings */
    uint256 public PERIOD;
    bool public PAUSED;

    RegistrationsTotal[] private registrationsTotal;
    FutureYieldToken[] public fyts;


    struct RegistrationsTotal{
        uint256 totalLMT;
        uint256 total; // not scaled here
        uint256 IBTRate;
    }

    mapping(address=>Registration) private registrations;
    mapping(address=>uint256) private lastPeriodClaimed;

    uint256[] private nextPeriodTimestamp;

    struct Registration{
        uint256 startIndex;
        uint256 scaledBalance;
    }

    /* Events */
    event UserRegistered(address _userAddress,uint256 _amount, uint256 _periodIndex);
    event NewPeriodStarted(uint256 _newPeriodIndex);

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

        registrationsTotal.push(); // empty period
        fyts.push();
        nextPeriodTimestamp.push();

        registrationsTotal.push(); // new period

        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        apwibt = APWineIBT(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.APWineIBTLogic(), payload));
    }

    function setFutureWallet(address _futureWalletAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        futureWallet = IAPWineFutureWallet(_futureWalletAddress);
    }

    function setCellar(address _cellarAddress) public{ //TODO check if set before start
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        cellar = IAPWineCellar(_cellarAddress);
    }

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

    function _register(address _winegrower, uint256 _initialScaledBalance) internal{
        registrations[_winegrower] = Registration({
                startIndex:getNextPeriodIndex(),
                scaledBalance:_initialScaledBalance
        });
    }

    function unregister(uint256 _amount) public virtual{
        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[msg.sender].startIndex == nextIndex, "The is not ongoing registration for the next period");
        uint256 currentRegistered = registrations[msg.sender].scaledBalance;
        require(currentRegistered>=_amount,"Invalid amount to unregister");

        registrations[msg.sender].scaledBalance = registrations[msg.sender].scaledBalance.sub(currentRegistered);
    }

    // function withdrawLockFunds(uint _amount) public virtual{
    //     require(apwibt.balanceOf(msg.sender)!=0,"Sender does not have any funds");
    // }

    function claimAPWIBT(address _winemaker) public virtual{
        uint256 nextIndex = getNextPeriodIndex();
        uint256 claimStartIndex = registrations[_winemaker].startIndex;
        uint256 claimableAPWIBT = getClaimableAPWIBT(_winemaker);
        require(claimableAPWIBT>0, "There are no ibt claimable at the moment for this address");
        if(hasClaimableFYT(_winemaker)){
            claimFYT(_winemaker); 
        }
        apwibt.transfer(_winemaker, claimableAPWIBT);
        for (uint i = claimStartIndex; i<nextIndex; i++){ // get not claimed fyt
            fyts[i].transfer(_winemaker,claimableAPWIBT);
        }
        lastPeriodClaimed[_winemaker] = nextIndex-1;
        delete registrations[_winemaker];
    }

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

    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual nextPeriodAvailable periodsActive{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();
        uint256 currentRate = getIBTRate();
        
        registrationsTotal[nextPeriodID].IBTRate = currentRate;
        registrationsTotal[nextPeriodID].total = ibt.balanceOf(address(this));

        /* Yield */
        uint256 yield = ibt.balanceOf(address(futureWallet)).mul((currentRate.sub(registrationsTotal[nextPeriodID-1].IBTRate)).div(currentRate));
        assert(ibt.transferFrom(address(futureWallet), address(cellar), yield));
        cellar.registerExpiredFuture(yield); // Yield deposit in the cellar contract

        /* Period Switch*/
        // registrationsTotal[nextPeriodID].totalLMT = ibt.balanceOf(address(this));
        apwibt.mint(address(this), registrationsTotal[nextPeriodID].total.mul(registrationsTotal[nextPeriodID].IBTRate)); // Mint new APWIBTs

        ibt.transfer(address(futureWallet), registrationsTotal[nextPeriodID].total); // Send ibt to future for the new period
        nextPeriodTimestamp.push(block.timestamp+PERIOD); // Program next switch

        registrationsTotal.push();

        /* Future Yield Token*/
        address futureTokenAddress = deployFutureYieldToken(_tokenName,_tokenSymbol);
        FutureYieldToken futureYieldToken = FutureYieldToken(futureTokenAddress);
        fyts.push(futureYieldToken);
        futureYieldToken.mint(address(this),apwibt.totalSupply().mul(10**( uint256(18-ibt.decimals()) ))); 

        emit NewPeriodStarted(nextPeriodID);
    }

    function deployFutureYieldToken(string memory _tokenName, string memory _tokenSymbol) internal returns(address){
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        FutureYieldToken Newtoken = FutureYieldToken(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.FutureYieldTokenLogic(), payload));
        return address(Newtoken);
    }

    function setNextPeriodTimestamp(uint256 _nextPeriodTimestamp) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to set the future wallet address");
        nextPeriodTimestamp[nextPeriodTimestamp.length-1]=_nextPeriodTimestamp;
    }


    function getRegisteredAmount(address _winemaker) public view returns(uint256){
        uint256 periodID = registrations[_winemaker].startIndex;
        uint256 winemakerRegisteredBalance = registrations[_winemaker].scaledBalance;
        if (winemakerRegisteredBalance== 0){
            return 0;
        }else if (periodID==getNextPeriodIndex()){
            return winemakerRegisteredBalance;
        }else{
            return scaleIBTAmount(winemakerRegisteredBalance, registrationsTotal[registrations[_winemaker].startIndex].IBTRate,registrationsTotal[getNextPeriodIndex()-1].IBTRate);
        }
    }


    function hasClaimableFYT(address _winemaker) public view returns(bool){
        return lastPeriodClaimed[_winemaker]!=0  && lastPeriodClaimed[_winemaker]<getNextPeriodIndex();
    }

    function hasClaimableAPWIBT(address _winemaker) public view returns(bool){
        return (registrations[_winemaker].startIndex < getNextPeriodIndex()) && (registrations[_winemaker].scaledBalance>0);
    }

    function getNextPeriodIndex() public view returns(uint256){
        return registrationsTotal.length-1;
    }

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

    function getIBTRate() public view virtual returns(uint256);

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


    function scaleIBTAmount(uint256 _initialAmount, uint256 _initialRate, uint256 _newRate) public view returns(uint256){
        uint256 newRate = getIBTRate();
        return _initialAmount.mul(_initialRate).div(newRate);
    }


    function getClaimableAPWIBT(address _winemaker) public view returns(uint256){
        if(!hasClaimableAPWIBT(_winemaker)) return 0;
        return scaleIBTAmount(registrations[_winemaker].scaledBalance, registrationsTotal[registrations[_winemaker].startIndex].IBTRate,registrationsTotal[getNextPeriodIndex()-1].IBTRate);
    }





    /* Security functions */



    
}