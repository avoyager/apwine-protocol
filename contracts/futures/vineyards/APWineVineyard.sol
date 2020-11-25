
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

    /* Utilitaries functions */
    function deployFutureYieldToken(string memory _tokenName, string memory _tokenSymbol) internal returns(address){
        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        FutureYieldToken Newtoken = FutureYieldToken(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.FutureYieldTokenLogic(), payload));
        return address(Newtoken);
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

    function getNextPeriodIndex() public view virtual returns(uint256);

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

    // function getClaimableAPWIBT(address _winemaker) public view returns(uint256);


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