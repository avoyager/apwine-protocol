pragma solidity >=0.4.22 <0.7.3;


import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";

import "../../interfaces/ERC20.sol";


import "../tokens/FutureYieldToken.sol";
import "../tokens/APWineIBT.sol";
import "../../libraries/APWineMaths.sol";

import "contracts/interfaces/apwine/IFutureWallet.sol";
import "contracts/interfaces/apwine/IController.sol";
import "contracts/interfaces/apwine/IFutureWallet.sol";
import "../../oz-upgradability-solc6/upgradeability/ProxyFactory.sol";
import "./Future.sol";

abstract contract RateFuture is Future{

    using SafeMath for uint256;

    uint256[] IBTRates;

    /**
    * @notice Intializer
    * @param _controllerAddress the address of the controller
    * @param _ibt the address of the corresponding ibt
    * @param _periodLength the length of the period (in days)
    * @param _tokenName the APWineIBT name
    * @param _tokenSymbol the APWineIBT symbol
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength,string memory _platform, string memory _tokenName, string memory _tokenSymbol,address _adminAddress) public initializer virtual override{
        super.initialize(_controllerAddress,_ibt,_periodLength,_platform,_tokenName,_tokenSymbol,_adminAddress);
        IBTRates.push();
        IBTRates.push();
    }

    function unregister(uint256 _amount) public virtual override{
        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[msg.sender].startIndex == nextIndex, "The is not ongoing registration for the next period");
        uint256 currentRegistered = registrations[msg.sender].scaledBalance;
        require(currentRegistered>=_amount,"Invalid amount to unregister");

        registrations[msg.sender].scaledBalance = registrations[msg.sender].scaledBalance.sub(currentRegistered);

        ibt.transfer(msg.sender, _amount);

    }


    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual override nextPeriodAvailable periodsActive{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();
        uint256 currentRate = getIBTRate();
        
        IBTRates[nextPeriodID] = currentRate;
        registrationsTotals[nextPeriodID] = ibt.balanceOf(address(this));

        /* Yield */
        uint256 yield = (ibt.balanceOf(address(futureVault)).mul(currentRate.sub(IBTRates[nextPeriodID-1]))).div(currentRate);
        if(yield>0) assert(ibt.transferFrom(address(futureVault), address(futureWallet), yield));
        futureWallet.registerExpiredFuture(yield); // Yield deposit in the futureWallet contract

        /* Period Switch*/
        if(registrationsTotals[nextPeriodID] >0){
            apwibt.mint(address(this), registrationsTotals[nextPeriodID].mul(IBTRates[nextPeriodID])); // Mint new APWIBTs
            ibt.transfer(address(futureVault), registrationsTotals[nextPeriodID]); // Send ibt to future for the new period
        }

        nextPeriodTimestamp.push(block.timestamp+PERIOD); // Program next switch
        registrationsTotals.push();
        IBTRates.push();

        /* Future Yield Token*/
        address fytAddress = deployFutureYieldToken(_tokenName,_tokenSymbol);
        emit NewPeriodStarted(nextPeriodID,fytAddress);
    }

    function getRegisteredAmount(address _user) public view override returns(uint256){
        uint256 periodID = registrations[_user].startIndex;
        if (periodID==getNextPeriodIndex()){
            return registrations[_user].scaledBalance;
        }else{
            return 0;
        }
    }

    function scaleIBTAmount(uint256 _initialAmount, uint256 _initialRate, uint256 _newRate) public view returns(uint256){
        return (_initialAmount.mul(_initialRate)).div(_newRate);
    }

    function getClaimableAPWIBT(address _user) public view override returns(uint256){
        if(!hasClaimableAPWIBT(_user)) return 0;
        return scaleIBTAmount(registrations[_user].scaledBalance, IBTRates[registrations[_user].startIndex],IBTRates[getNextPeriodIndex()-1]);
    }

    function getUnlockableFunds(address _user) public view override returns(uint256){
        return scaleIBTAmount(super.getUnlockableFunds(_user),IBTRates[getNextPeriodIndex()-1], getIBTRate());
    }

    function getUnrealisedYield(address _user) public view override returns(uint256){
        return apwibt.balanceOf(_user).sub(scaleIBTAmount(apwibt.balanceOf(_user),IBTRates[getNextPeriodIndex()-1], getIBTRate()));
    }

    function getIBTRate() public view virtual returns(uint256);

}