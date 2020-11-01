pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../interfaces/IFutureYieldToken.sol';
import '../interfaces/ERC20.sol';
import './APWineFuture.sol';


contract APWineCurveSimple is APWineFuture{

    ERC20 public IBToken;
    
    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period, address _COMPAddress, address _comptrollerAddress,address _adminAddress)initializer public {
        super.initialize(_controllerAddress, _futureYieldTokenFactoryAddress, _IBTokenAddress, _name, _period,_adminAddress);
        IBToken = ERC20(_IBTokenAddress);
    }

    //function startFuture(uint index) periodNotStarted(index) periodNotExpired(index) previousPeriodEnded(index) public{ TODO CHECK BEGIN
    //function startFuture(uint index) periodNotStarted(index) previousPeriodEnded(index) public {
    function startFuture(uint _index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");
        futures[_index].period_started = true;
        futures[_index].initialBalance = IBToken.balanceOf(address(this));
        uint addressLength = futures[_index].registeredProxies.length;
        for (uint i = 0; i < addressLength; ++i) {
            if (futures[_index].registeredBalances[address(futures[_index].registeredProxies[i])] > 0) {
                futures[_index].registeredProxies[i].collect();
                futureYieldTokens[_index].mint(address(futures[_index].registeredProxies[i]),futures[_index].registeredBalances[address(futures[_index].registeredProxies[i])]*10**(18-IBTokenDecimals));
            }
        }

        futures[_index].totalFutureTokenMinted = futureYieldTokens[_index].totalSupply();
        emit FuturePeriodStarted(_index);

    }

    function endFuture(uint _index) periodIsMature(_index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");

        futures[_index].period_ended = true;
        uint proxiesLength = futures[_index].registeredProxies.length;

        for (uint i = 0; i < proxiesLength; ++i) {
            address proxyAddress = address(futures[_index].registeredProxies[i]);
            if (futures[_index].registeredBalances[proxyAddress] > 0){
                uint256 LenderBalance = futures[_index].registeredBalances[proxyAddress];
                IBToken.transfer(proxyAddress,LenderBalance);
                if (autoRegistered.contains(proxyAddress) && _index<futures.length-1){
                    registerBalanceToPeriod(_index+1, LenderBalance, proxyAddress);
                }
            }
        }

        futures[_index].finalBalance = IBToken.balanceOf(address(this));
        emit FuturePeriodEnded(_index);
    }

    function getNewLenderBalance(uint _futureIndex, address _proxy) private returns(uint256) {
    }

    function claimYield(uint _index) periodHasEnded(_index) public override {
        uint256 senderTokenBalance = futureYieldTokens[_index].balanceOf(msg.sender);
        require(senderTokenBalance > 0);
        require(futureYieldTokens[_index].transferFrom(msg.sender, address(this), senderTokenBalance));
        uint256 senderShare = SafeMath.div(senderTokenBalance,futureYieldTokens[_index].totalSupply());
        uint256 yieldShare = SafeMath.mul(senderShare,futures[_index].finalBalance);
        IBToken.transfer(msg.sender, yieldShare);
        futureYieldTokens[_index].burn(senderTokenBalance);
    }


}

