pragma solidity >=0.4.22 <0.7.3;

import "./APWineCellar.sol";

abstract contract APWineStreamedCellar is APWineCellar{

    uint256 private scalledTotal;
    uint256[] private scalledCellars;

    function registerExpiredFuture(uint256 _amount) public override{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");

        uint256 currentTotal = ERC20(future.IBTokenAddress()).totalSupply();

        if(scalledCellars.length != 0){
            uint256 scalledInput = _amount.mul(scalledTotal).div((uint256(1e18).sub(_amount.div(_amount.add(currentTotal)))).mul(_amount.add(currentTotal)));
            scalledCellars.push(scalledInput);
            scalledTotal = scalledTotal.add(scalledInput);
        }else{
            scalledCellars.push(_amount);
            scalledTotal = scalledTotal.add(_amount);
        }
    }

    function claimYield(uint256 _periodIndex) public override{
        IFutureYieldToken fyt = IFutureYieldToken(future.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);

        require(senderTokenBalance > 0,"FYT sender balance should not be null");
        require(fyt.transferFrom(msg.sender, address(this), senderTokenBalance),"Failed transfer");

        uint256 senderShare = senderTokenBalance.div(fyt.totalSupply()).mul(scalledCellars[_periodIndex]);
        ERC20 ibt = ERC20(future.IBTokenAddress());
        uint256 claimableShare = senderShare.mul(ibt.totalSupply()).div(scalledTotal);
        
        scalledTotal = scalledTotal.sub(senderShare);

        ibt.transfer(msg.sender, claimableShare);
        fyt.burn(senderTokenBalance);
    }   

    function getClaimableYield(uint256 _periodIndex, address _tokenHolder) public view override returns(uint256){
        IFutureYieldToken fyt = IFutureYieldToken(future.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        uint256 senderShare = senderTokenBalance.div(fyt.totalSupply()).mul(scalledCellars[_periodIndex]);
        ERC20 ibt = ERC20(future.IBTokenAddress());
        return senderShare.mul(ibt.totalSupply()).div(scalledTotal);
    }

}