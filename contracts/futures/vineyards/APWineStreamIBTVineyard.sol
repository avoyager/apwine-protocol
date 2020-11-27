
pragma solidity >=0.4.22 <0.7.3;
import "./APWineVineyard.sol";


abstract contract APWineStreamIBTVineyard is APWineVineyard{

    uint256[] scaledTotals;
  
    /**
    * @notice Intializer
    * @param _controllerAddress the address of the controller
    * @param _ibt the address of the corresponding ibt
    * @param _periodLength the length of the period (in days)
    * @param _tokenName the APWineIBT name
    * @param _tokenSymbol the APWineIBT symbol
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength, string memory _tokenName, string memory _tokenSymbol,address _adminAddress) public initializer virtual override{
        super.initialize(_controllerAddress,_ibt,_periodLength,_tokenName,_tokenSymbol,_adminAddress);
        scaledTotals.push();
        scaledTotals.push();
    }

    function register(address _winegrower ,uint256 _amount) public virtual override periodsActive{   
        uint256 scaledInput = APWineMaths.getScaledInput(_amount,scaledTotals[getNextPeriodIndex()], ibt.balanceOf(address(this)));
        super.register(_winegrower,scaledInput);
        scaledTotals[getNextPeriodIndex()] = scaledTotals[getNextPeriodIndex()].add(scaledInput);
    }

    function unregister(uint256 _amount) public virtual override{
        uint256 nextIndex = getNextPeriodIndex();
        require(registrations[msg.sender].startIndex == nextIndex, "There is no ongoing registration for the next period");
        uint256 currentRegistered = APWineMaths.getActualOutput(registrations[msg.sender].scaledBalance, scaledTotals[nextIndex], ibt.balanceOf(address(this)));
        require(currentRegistered>=_amount,"Invalid amount to unregister");

        uint256 scaledToUnregister = registrations[msg.sender].scaledBalance.mul(_amount.div(currentRegistered));

        registrations[msg.sender].scaledBalance = registrations[msg.sender].scaledBalance.sub(scaledToUnregister);
        scaledTotals[nextIndex]= scaledTotals[nextIndex].sub(scaledToUnregister);

        ibt.transfer(msg.sender, _amount);

    }


    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) public virtual override nextPeriodAvailable periodsActive{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 nextPeriodID = getNextPeriodIndex();

        /* Yield */
        uint256 yield = ibt.balanceOf(address(futureWallet)).sub(apwibt.totalSupply());
        if(yield>0) assert(ibt.transferFrom(address(futureWallet), address(cellar), yield));
        cellar.registerExpiredFuture(yield); // Yield deposit in the cellar contract

        /* Period Switch*/
        registrationsTotals[nextPeriodID] = ibt.balanceOf(address(this));
        apwibt.mint(address(this), registrationsTotals[nextPeriodID]); // Mint new APWIBTs
        ibt.transfer(address(futureWallet), registrationsTotals[nextPeriodID]); // Send ibt to future for the new period
        nextPeriodTimestamp.push(block.timestamp+PERIOD); // Program next switch
        registrationsTotals.push();
        scaledTotals.push();

        /* Future Yield Token*/
        address fytAddress = deployFutureYieldToken(_tokenName,_tokenSymbol);
        emit NewPeriodStarted(nextPeriodID,fytAddress);
    }


    function getRegisteredAmount(address _winemaker) public view virtual override returns(uint256){
        uint256 periodID = registrations[_winemaker].startIndex;
        if (periodID==getNextPeriodIndex()){
            return APWineMaths.getActualOutput(registrations[_winemaker].scaledBalance, scaledTotals[periodID], ibt.balanceOf(address(this)));
        }else{
            return 0;
        }
    }

    function getClaimableAPWIBT(address _winemaker) public view override returns(uint256){
        if(!hasClaimableAPWIBT(_winemaker)) return 0;
        return APWineMaths.getActualOutput(registrations[_winemaker].scaledBalance, scaledTotals[registrations[_winemaker].startIndex], registrationsTotals[registrations[_winemaker].startIndex]);
    }

    function getUnrealisedYield(address _winemaker) public view override returns(uint256){
        uint256 yieldShare = (ibt.balanceOf(address(futureWallet)).sub(apwibt.totalSupply())).div(ibt.balanceOf(address(futureWallet)));
        uint256 winemakerShare = apwibt.balanceOf(_winemaker).div(apwibt.totalSupply());
        return winemakerShare.mul(yieldShare).mul(ibt.balanceOf(address(futureWallet)));
    }


}