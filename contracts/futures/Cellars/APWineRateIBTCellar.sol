pragma solidity >=0.4.22 <0.7.3;

import "./APWineCellar.sol";

abstract contract APWineRateIBTCellar is APWineCellar{

    uint256[] private cellars;

    function initialize(address _vineyardAddress, address _adminAddress) public initializer override{
        super.initialize(_vineyardAddress,_adminAddress);
        cellars.push(0);
    }

    function registerExpiredFuture(uint256 _amount) public override{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");
        cellars.push(_amount);
    }

    function redeemYield(uint256 _periodIndex) public override{
        require(_periodIndex<vineyard.getNextPeriodIndex()-1,"Invalid period index");

        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);

        require(senderTokenBalance > 0,"FYT sender balance should not be null");
        require(fyt.transferFrom(msg.sender, address(this), senderTokenBalance),"Failed transfer");

        ERC20 ibt = ERC20(vineyard.getIBTAddress());

        uint256 claimableYield = (senderTokenBalance.mul(cellars[_periodIndex])).div(fyt.totalSupply());
        
        cellars[_periodIndex].sub(claimableYield);

        ibt.transfer(msg.sender, claimableYield);
        fyt.burn(senderTokenBalance);
    }   

    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view override returns(uint256){
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        return (senderTokenBalance.mul(cellars[_periodIndex])).div(fyt.totalSupply());
    }

}