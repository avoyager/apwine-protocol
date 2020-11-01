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


        YEFP[_index].finalRate = IBToken.getPricePerFullShare();
        futures[_index].period_ended = true;
        uint proxiesLength = futures[_index].registeredProxies.length;

        for (uint i = 0; i < proxiesLength; ++i) {
            address proxyAddress = address(futures[_index].registeredProxies[i]);
            if (futures[_index].registeredBalances[proxyAddress] > 0){
                uint256 newLenderBalance = getNewLenderBalance(_index, proxyAddress);
                IBToken.transfer(proxyAddress,newLenderBalance);
                if (autoRegistered.contains(proxyAddress) && _index<futures.length-1){
                    registerBalanceToPeriod(_index+1, newLenderBalance, proxyAddress);
                }
            }
        }
        futures[_index].finalBalance = IBToken.balanceOf(address(this));
        emit FuturePeriodEnded(_index);
    }

    function getNewLenderBalance(uint _futureIndex, address _proxy) private returns(uint256) {
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

