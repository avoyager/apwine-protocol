
pragma solidity >=0.7.0 <0.8.0;
import "./Future.sol";


abstract contract StreamFuture is Future{
    using SafeMathUpgradeable for uint256;

    uint256[] scaledTotals;
  
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength, string memory _platform,address _adminAddress) public initializer virtual override{
        super.initialize(_controllerAddress,_ibt,_periodLength,_platform,_adminAddress);
        scaledTotals.push();
        scaledTotals.push();
    }

    function register(address _winegrower ,uint256 _amount) public virtual override periodsActive{   
        uint256 scaledInput = APWineMaths.getScaledInput(_amount,scaledTotals[getNextPeriodIndex()], ibt.balanceOf(address(this)));
        super.register(_winegrower,scaledInput);
        scaledTotals[getNextPeriodIndex()] = scaledTotals[getNextPeriodIndex()].add(scaledInput);
    }

    function unregister(address _user,uint256 _amount) public virtual override{
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to unregister");

        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[_user].startIndex == nextIndex, "There is no ongoing registration for the next period");
        uint256 userScaledBalance = registrations[_user].scaledBalance;
        uint256 currentRegistered = APWineMaths.getActualOutput(userScaledBalance, scaledTotals[nextIndex], ibt.balanceOf(address(this)));
        uint256 scaledToUnregister;
        if(_amount == 0){
            require(currentRegistered>0,"Invalid amount to unregister");
            scaledToUnregister = userScaledBalance;
            delete registrations[_user];
            ibt.transfer(_user, currentRegistered);
        }else{
            require(currentRegistered>=_amount,"Invalid amount to unregister");
            scaledToUnregister = (registrations[_user].scaledBalance.mul(_amount)).div(currentRegistered);
            registrations[_user].scaledBalance = registrations[_user].scaledBalance.sub(scaledToUnregister);
            ibt.transfer(_user, _amount);
        }
        scaledTotals[nextIndex]= scaledTotals[nextIndex].sub(scaledToUnregister);
    }

    function startNewPeriod() public virtual override nextPeriodAvailable periodsActive{
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();

        /* Yield */
        uint256 yield = ibt.balanceOf(address(futureVault)).sub(apwibt.totalSupply());
        if(yield>0) assert(ibt.transferFrom(address(futureVault), address(futureWallet), yield));
        futureWallet.registerExpiredFuture(yield); // Yield deposit in the futureWallet contract

        /* Period Switch*/
        registrationsTotals[nextPeriodID] = ibt.balanceOf(address(this));
        if(registrationsTotals[nextPeriodID] >0){
            apwibt.mint(address(this), registrationsTotals[nextPeriodID]); // Mint new APWIBTs
            ibt.transfer(address(futureVault), registrationsTotals[nextPeriodID]); // Send ibt to future for the new period
        }
       
        registrationsTotals.push();
        scaledTotals.push();

        /* Future Yield Token*/
        address fytAddress = deployFutureYieldToken();
        emit NewPeriodStarted(nextPeriodID,fytAddress);
    }


    function getRegisteredAmount(address _user) public view virtual override returns(uint256){
        uint256 periodID = registrations[_user].startIndex;
        if (periodID==getNextPeriodIndex()){
            return APWineMaths.getActualOutput(registrations[_user].scaledBalance, scaledTotals[periodID], ibt.balanceOf(address(this)));
        }else{
            return 0;
        }
    }

    function getClaimableAPWIBT(address _user) public view override returns(uint256){
        if(!hasClaimableAPWIBT(_user)) return 0;
        return APWineMaths.getActualOutput(registrations[_user].scaledBalance, scaledTotals[registrations[_user].startIndex], registrationsTotals[registrations[_user].startIndex]);
    }

    function getUnrealisedYield(address _user) public view override returns(uint256){
        return ((ibt.balanceOf(address(futureVault)).sub(apwibt.totalSupply())).mul(fyts[getNextPeriodIndex()-1].balanceOf(_user))).div(fyts[getNextPeriodIndex()-1].totalSupply());
    }

}