pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

import '../interfaces/compound/IComptroller.sol';
import '../interfaces/compound/ICErc20.sol';
import '../interfaces/apwine/IFutureYieldToken.sol';
import './APWineFuture.sol';


contract APWineCompound is APWineFuture{

    CErc20 public IBToken;
    CErc20 COMP;

    Comptroller comptroller;

    struct CompoundFuturesParams{
        uint256 initialRate;
        uint256 finalRate;
        uint256 initialCompBalance;
        uint256 totalCompBalance;
    }
    
    CompoundFuturesParams[] public CFP;

    function initialize(address _controllerAddress, address _futureYieldTokenFactoryAddress, address _IBTokenAddress, string memory _name, uint256 _period, address _COMPAddress, address _comptrollerAddress,address _adminAddress)initializer public {
        super.initialize(_controllerAddress, _futureYieldTokenFactoryAddress, _IBTokenAddress, _name, _period,_adminAddress);

        COMP = CErc20(_COMPAddress);
        IBToken = CErc20(_IBTokenAddress);
        comptroller =  Comptroller(_comptrollerAddress);
    }

    //function startFuture(uint index) periodNotStarted(index) periodNotExpired(index) previousPeriodEnded(index) public{ TODO CHECK BEGIN
    //function startFuture(uint index) periodNotStarted(index) previousPeriodEnded(index) public {
    function startFuture(uint _index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");


        CFP.push(CompoundFuturesParams({
            initialRate: 0,
            finalRate: 0,
            initialCompBalance: 0,
            totalCompBalance:0
        }));

        //require(futures[index].beginning>=block.timestamp);
        futures[_index].period_started = true;

        CFP[_index].initialRate = uint256(IBToken.exchangeRateStored());
        comptroller.claimComp(address(this));
        CFP[_index].initialCompBalance = COMP.balanceOf(address(this));
        super.startFuture(_index);
    }

    function endFuture(uint _index) periodIsMature(_index) public override{
        require(hasRole(TIMING_CONTROLLER_ROLE, msg.sender), "Caller is not a timing controller");

        comptroller.claimComp(address(this));
        CFP[_index].totalCompBalance = COMP.balanceOf(address(this)).sub(CFP[_index].initialCompBalance);

        CFP[_index].finalRate = IBToken.exchangeRateStored();
        super.endFuture(_index);
    }

    function getNewLenderBalance(uint _futureIndex, address _proxy) internal override returns(uint256) {
        uint256 registeredBalance = futures[_futureIndex].registeredBalances[_proxy];
        uint256 inflationRate = SafeMath.div(CFP[_futureIndex].initialRate,CFP[_futureIndex].finalRate);
        return SafeMath.mul(registeredBalance,inflationRate);
    }

    function claimYield(uint _index) periodHasEnded(_index) public override {
        uint256 senderTokenBalance = futureYieldTokens[_index].balanceOf(msg.sender);
        require(senderTokenBalance > 0);
        require(futureYieldTokens[_index].transferFrom(msg.sender, address(this), senderTokenBalance));
        uint256 TokenShare = senderTokenBalance.div(futureYieldTokens[_index].totalSupply());
        uint256 senderTokenShare = TokenShare.mul(uint256(10**18).sub(CFP[_index].initialRate.div(CFP[_index].finalRate)));
        IBToken.transfer(msg.sender, senderTokenShare.mul(futures[_index].totalRegisteredBalance));
        futureYieldTokens[_index].burn(senderTokenBalance);
        COMP.transfer(msg.sender, TokenShare.mul(CFP[_index].totalCompBalance));
    }


}

