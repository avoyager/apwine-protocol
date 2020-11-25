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

        uint256 currentTotal = ERC20(vineyard.getIBTAddress()).totalSupply();

        if(scaledCellars.length>1){
            uint256 scaledInput = APWineMaths.getScaledInput(_amount,scaledTotal,currentTotal);
            scaledTotal = scaledTotal.add(scaledInput);
        }else{
            scaledCellars.push(_amount);
            scaledTotal = scaledTotal.add(_amount);
        }
    }

    function redeemYield(uint256 _periodIndex) public override{
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);

        require(senderTokenBalance > 0,"FYT sender balance should not be null");
        require(fyt.transferFrom(msg.sender, address(this), senderTokenBalance),"Failed transfer");

        ERC20 ibt = ERC20(vineyard.getIBTAddress());

        uint256 scaledOutput = (senderTokenBalance.div(fyt.totalSupply())).mul(scaledCellars[_periodIndex]);

        uint256 claimableYield =  APWineMaths.getActualOutput(scaledOutput,scaledTotal,ibt.balanceOf(address(this)));
        
        scaledCellars[_periodIndex].sub(scaledOutput);
        scaledTotal = scaledTotal.sub(scaledOutput);

        ibt.transfer(msg.sender, claimableYield);
        fyt.burn(senderTokenBalance);
    }   

    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view override returns(uint256){
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        ERC20 ibt = ERC20(vineyard.getIBTAddress());
        uint256 scaledOutput = (senderTokenBalance.div(fyt.totalSupply())).mul(scaledCellars[_periodIndex]);
        return  APWineMaths.getActualOutput(scaledOutput,scaledTotal,ibt.balanceOf(address(this)));
    }

}