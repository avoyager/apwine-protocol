
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


abstract contract APWineStreamIBTVineyard is APWineVineyard{

    RegistrationsTotal[] private registrationsTotal;

    struct RegistrationsTotal{
        uint256 scaled;
        uint256 actual;
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

        registrationsTotal.push(); // TODO verify
        fyts.push();
        nextPeriodTimestamp.push();

        registrationsTotal.push(RegistrationsTotal({
            scaled: 0,
            actual:0
        }));

        bytes memory payload = abi.encodeWithSignature("initialize(string,string,address)", _tokenName, _tokenSymbol, address(this));
        apwibt = APWineIBT(ProxyFactory(controller.APWineProxyFactory()).deployMinimal(controller.APWineIBTLogic(), payload));
    }

    function register(address _winegrower ,uint256 _amount) public virtual periodsActive{   
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to register a wallet");
        uint256 nextIndex = getNextPeriodIndex();
        uint256 scaledInput = APWineMaths.getScaledInput(_amount,registrationsTotal[nextIndex].scaled, ibt.balanceOf(address(this)));

        if(registrations[_winegrower].scaledBalance==0){ // User has no record
            _register(_winegrower,scaledInput);
        }else{
            if(registrations[_winegrower].startIndex == nextIndex){ // User has already an existing registration for the next period
                 registrations[_winegrower].scaledBalance = registrations[_winegrower].scaledBalance.add(scaledInput);
            }else{ // User had an unclaimed registation from a previous period
                claimAPWIBT(_winegrower);
                _register(_winegrower,scaledInput);
            }
        }
        registrationsTotal[nextIndex].scaled = registrationsTotal[nextIndex].scaled.add(scaledInput);
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
        require(registrations[msg.sender].startIndex == nextIndex, "There is no ongoing registration for the next period");

        uint256 currentRegistered = APWineMaths.getActualOutput(registrations[msg.sender].scaledBalance, registrationsTotal[nextIndex].scaled, ibt.balanceOf(address(this)));
        require(currentRegistered>=_amount,"Invalid amount to unregister");

        uint256 scaledToUnregister = registrations[msg.sender].scaledBalance.mul(_amount.div(currentRegistered));

        registrations[msg.sender].scaledBalance = registrations[msg.sender].scaledBalance.sub(scaledToUnregister);
        registrationsTotal[nextIndex].scaled= registrationsTotal[nextIndex].scaled.sub(scaledToUnregister);

    }

    // function withdrawLockFunds(uint _amount) public virtual{
    //     require(apwibt.balanceOf(msg.sender)!=0,"Sender does not have any funds");
    // }

    function claimAPWIBT(address _winemaker) public virtual{
        uint256 nextIndex = getNextPeriodIndex();
        uint256 claimStartIndex = registrations[_winemaker].startIndex;
        require(hasClaimableAPWIBT(_winemaker), "There aren't any ibt claimable for this address"); // TODO verify
        uint256 claimableIBT = APWineMaths.getActualOutput(registrations[_winemaker].scaledBalance, registrationsTotal[claimStartIndex].scaled, registrationsTotal[claimStartIndex].actual);
        require(claimableIBT>0, "There are no ibt claimable at the moment for this address");
        if(hasClaimableFYT(_winemaker)){
            claimFYT(_winemaker); 
        }
        apwibt.transfer(_winemaker, claimableIBT);
        for (uint i = claimStartIndex; i<nextIndex; i++){ // get not claimed fyt
            fyts[i].transfer(_winemaker,claimableIBT);
        }
        lastPeriodClaimed[_winemaker] = nextIndex-1;
        delete registrations[_winemaker];
    }

    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual nextPeriodAvailable periodsActive{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();

        /* Yield */
        uint256 yield = ibt.balanceOf(address(futureWallet)).sub(apwibt.totalSupply());
        if(yield>0) assert(ibt.transferFrom(address(futureWallet), address(cellar), yield));
        cellar.registerExpiredFuture(yield); // Yield deposit in the cellar contract

        /* Period Switch*/
        registrationsTotal[nextPeriodID].actual = ibt.balanceOf(address(this));
        apwibt.mint(address(this), registrationsTotal[nextPeriodID].actual); // Mint new APWIBTs

        ibt.transfer(address(futureWallet), registrationsTotal[nextPeriodID].actual); // Send ibt to future for the new period
        nextPeriodTimestamp.push(block.timestamp+PERIOD); // Program next switch

        registrationsTotal.push();

        /* Future Yield Token*/
        address futureTokenAddress = deployFutureYieldToken(_tokenName,_tokenSymbol);
        FutureYieldToken futureYieldToken = FutureYieldToken(futureTokenAddress);
        fyts.push(futureYieldToken);
        futureYieldToken.mint(address(this),apwibt.totalSupply().mul(10**( uint256(18-ibt.decimals()) ))); 

        emit NewPeriodStarted(nextPeriodID);
    }


    function getRegisteredAmount(address _winemaker) public view returns(uint256){
        uint256 periodID = registrations[_winemaker].startIndex;
        if (registrations[_winemaker].scaledBalance == 0){
            return 0;
        }else if (periodID==getNextPeriodIndex()){
            return APWineMaths.getActualOutput(registrations[_winemaker].scaledBalance, registrationsTotal[periodID].scaled, ibt.balanceOf(address(this)));
        }else{
            return APWineMaths.getActualOutput(registrations[_winemaker].scaledBalance, registrationsTotal[periodID].scaled, registrationsTotal[periodID].actual);
        }
    }

    function getNextPeriodIndex() public view override returns(uint256){
        return registrationsTotal.length-1;
    }
}