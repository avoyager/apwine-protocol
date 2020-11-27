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
import "./APWineVineyard.sol";

abstract contract APWineRateIBTVineyard is APWineVineyard{

    using SafeMath for uint256;

    uint256 apwibtRate;

    RegistrationsTotal[] private registrationsTotal;


    struct RegistrationsTotal{
        uint256 totalLMT;
        uint256 total; // not scaled here
        uint256 IBTRate;
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

    function register(address _winegrower ,uint256 _amount) public virtual override periodsActive{   
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

    function unregister(uint256 _amount) public virtual override{
        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[msg.sender].startIndex == nextIndex, "The is not ongoing registration for the next period");
        uint256 currentRegistered = registrations[msg.sender].scaledBalance;
        require(currentRegistered>=_amount,"Invalid amount to unregister");

        registrations[msg.sender].scaledBalance = registrations[msg.sender].scaledBalance.sub(currentRegistered);

        ibt.transfer(msg.sender, _amount);

    }

    // function withdrawLockFunds(uint _amount) public virtual{
    //     require(apwibt.balanceOf(msg.sender)!=0,"Sender does not have any funds");
    // }



    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual override nextPeriodAvailable periodsActive{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();
        uint256 currentRate = getIBTRate();
        
        registrationsTotal[nextPeriodID].IBTRate = currentRate;
        registrationsTotal[nextPeriodID].total = ibt.balanceOf(address(this));

        /* Yield */
        uint256 yield = ibt.balanceOf(address(futureWallet)).mul((currentRate.sub(registrationsTotal[nextPeriodID-1].IBTRate)).div(currentRate));
        if(yield>0) assert(ibt.transferFrom(address(futureWallet), address(cellar), yield));
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

    function getRegisteredAmount(address _winemaker) public view override returns(uint256){
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

    function scaleIBTAmount(uint256 _initialAmount, uint256 _initialRate, uint256 _newRate) public view returns(uint256){
        return _initialAmount.mul(_initialRate).div(_newRate);
    }

    function getClaimableAPWIBT(address _winemaker) public view override returns(uint256){
        if(!hasClaimableAPWIBT(_winemaker)) return 0;
        return scaleIBTAmount(registrations[_winemaker].scaledBalance, registrationsTotal[registrations[_winemaker].startIndex].IBTRate,registrationsTotal[getNextPeriodIndex()-1].IBTRate);
    }

    function getUnlockableFunds(address _winemaker) public view override returns(uint256){
        return scaleIBTAmount(apwibt.balanceOf(_winemaker),registrationsTotal[getNextPeriodIndex()-1].IBTRate, getIBTRate());
    }

    function getUnrealisedYield(address _winemaker) public view override returns(uint256){
        return apwibt.balanceOf(_winemaker).sub(scaleIBTAmount(apwibt.balanceOf(_winemaker),registrationsTotal[getNextPeriodIndex()-1].IBTRate, getIBTRate()));
    }


    function getNextPeriodIndex() public view override returns(uint256){
        return registrationsTotal.length-1;
    }

    function getIBTRate() public view virtual returns(uint256);

}