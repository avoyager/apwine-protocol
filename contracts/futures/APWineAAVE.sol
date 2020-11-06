pragma solidity >=0.4.22 <0.7.3;


import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import './APWineFuture.sol';
import '../interfaces/aave/IAToken.sol';
import '../interfaces/apwine/IFutureYieldToken.sol';
import '../interfaces/apwine/IAPWineProxy.sol';
import '../interfaces/apwine/IAPWineController.sol';

contract APWineAave is APWineFuture {
    
    AToken public IBToken;

    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period,address _adminAddress) initializer public override{
        super.initialize(_controllerAddress, _futureYieldTokenFactoryAddress, _IBTokenAddress, _name, _period, _adminAddress);
        IBToken = AToken(_IBTokenAddress);
    }

    //function startFuture(uint index) periodNotStarted(index) periodNotExpired(index) previousPeriodEnded(index) public{ TODO CHECK BEGIN
    function startFuture(uint _index) periodNotStarted(_index) previousPeriodEnded(_index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");
        //require(futures[index].beginning>=block.timestamp);
        futures[_index].period_started = true;
        futures[_index].initialBalance = IBToken.balanceOf(address(this));
        uint addressLength = futures[_index].registeredProxies.length;
        super.startFuture(_index);
    }

    function endFuture(uint _index) periodIsMature(_index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");
        super.endFuture(_index);
    }

    function getNewLenderBalance(uint _futureIndex, address _proxy) internal override returns(uint256) {
        return futures[_futureIndex].registeredBalances[_proxy];
    }

    function claimYield(uint _index) periodHasEnded(_index) public override{
        uint256 senderTokenBalance = futureYieldTokens[_index].balanceOf(msg.sender);
        require(senderTokenBalance > 0);
        require(futureYieldTokens[_index].transferFrom(msg.sender, address(this), senderTokenBalance));
        uint256 senderShare = SafeMath.div(senderTokenBalance,futureYieldTokens[_index].totalSupply());
        uint256 yieldShare = SafeMath.mul(senderShare,futures[_index].finalBalance);
        IBToken.transfer(msg.sender, yieldShare);
        futureYieldTokens[_index].burn(senderTokenBalance);
    }

}