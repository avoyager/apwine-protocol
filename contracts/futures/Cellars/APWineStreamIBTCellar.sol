pragma solidity >=0.4.22 <0.7.3;

import "./APWineCellar.sol";

abstract contract APWineStreamIBTCellar is APWineCellar{

    uint256 private scaledTotal;
    uint256[] private scaledCellars;


    function initialize(address _vineyardAddress, address _adminAddress) public initializer override{
        super.initialize(_vineyardAddress,_adminAddress);
    }

    function registerExpiredFuture(uint256 _amount) public override{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 currentTotal = ibt.balanceOf(address(this));

        if(scaledCellars.length>1){
            uint256 scaledInput = APWineMaths.getScaledInput(_amount,scaledTotal,currentTotal);
            scaledCellars.push(scaledInput);
            scaledTotal = scaledTotal.add(scaledInput);
        }else{
            scaledCellars.push(_amount);
            scaledTotal = scaledTotal.add(_amount);
        }
    }

    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view override returns(uint256){
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        uint256 scaledOutput = (senderTokenBalance.mul(scaledCellars[_periodIndex]));
       return APWineMaths.getActualOutput(scaledOutput,scaledTotal,ibt.balanceOf(address(this))).div(fyt.totalSupply());
    }

    function _updateYieldBalances(uint256 _periodIndex, uint256 _cavistFYT, uint256 _totalFYT) internal override returns(uint256){
        uint256 scaledOutput = (_cavistFYT.mul(scaledCellars[_periodIndex])).div(_totalFYT);
        uint256 claimableYield =  APWineMaths.getActualOutput(scaledOutput,scaledTotal,ibt.balanceOf(address(this)));
        scaledCellars[_periodIndex] = scaledCellars[_periodIndex].sub(scaledOutput);
        scaledTotal = scaledTotal.sub(scaledOutput);
        return claimableYield;
    }


}