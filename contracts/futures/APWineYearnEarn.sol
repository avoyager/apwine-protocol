pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../interfaces/apwine/IFutureYieldToken.sol';
import '../interfaces/yearn/IyToken.sol';
import './APWineFuture.sol';


contract APWineCompound is APWineFuture{

    yToken public IBToken;

    struct YearnEarnFuturesParams{
        uint256 initialRate;
        uint256 finalRate;
    }
    
    YearnEarnFuturesParams[] public YEFP;

    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period,address _adminAddress)initializer public override {
        super.initialize(_controllerAddress, _futureYieldTokenFactoryAddress, _IBTokenAddress, _name, _period,_adminAddress);

        IBToken = yToken(_IBTokenAddress);
    }

    //function startFuture(uint index) periodNotStarted(index) periodNotExpired(index) previousPeriodEnded(index) public{ TODO CHECK BEGIN
    //function startFuture(uint index) periodNotStarted(index) previousPeriodEnded(index) public {
    function startFuture(uint _index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");


        YEFP.push(YearnEarnFuturesParams({
            initialRate: 0,
            finalRate: 0
        }));

        //require(futures[index].beginning>=block.timestamp);
        futures[_index].period_started = true;

        YEFP[_index].initialRate = uint256(IBToken.getPricePerFullShare());

        super.startFuture(_index);

    }

    function endFuture(uint _index) periodIsMature(_index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");
        YEFP[_index].finalRate = IBToken.getPricePerFullShare();
        super.endFuture(_index);
    }

    function quitFuture(uint _index, uint _amount) public override{
        YEFP[_index].finalRate = IBToken.getPricePerFullShare();
        super.quitFuture(_index, _amount);
    }

    function getNewLenderBalance(uint _futureIndex, address _proxy) internal override returns(uint256) {
        uint256 registeredBalance = futures[_futureIndex].registeredBalances[_proxy];
        uint256 inflationRate = SafeMath.div(YEFP[_futureIndex].initialRate,YEFP[_futureIndex].finalRate);
        return SafeMath.mul(registeredBalance,inflationRate);
    }

    function claimYield(uint _index) periodHasEnded(_index) public override {
        uint256 senderTokenBalance = futureYieldTokens[_index].balanceOf(msg.sender);
        require(senderTokenBalance > 0);
        require(futureYieldTokens[_index].transferFrom(msg.sender, address(this), senderTokenBalance));
        uint256 TokenShare = senderTokenBalance.div(futureYieldTokens[_index].totalSupply());
        uint256 senderTokenShare = TokenShare.mul(uint256(10**18).sub(YEFP[_index].initialRate.div(YEFP[_index].finalRate)));
        IBToken.transfer(msg.sender, senderTokenShare.mul(futures[_index].totalRegisteredBalance));
        futureYieldTokens[_index].burn(senderTokenBalance);
    }


}

