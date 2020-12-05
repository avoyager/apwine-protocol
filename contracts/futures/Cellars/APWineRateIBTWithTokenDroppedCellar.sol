pragma solidity >=0.4.22 <0.7.3;

import "./APWineRateIBTCellar.sol";
import "./APWineTokenDroppedCellar.sol";


abstract contract APWineRateIBTWithTokenDoppedCellar is APWineRateIBTCellar, APWineTokenDroppedCellar{

    function initialize(address _vineyardAddress,address _adminAddress, address _droppedToken) public virtual initializer{
        super.initialize(_vineyardAddress,_adminAddress);
        _tokenDroppedinitialize(_droppedToken);
    }

    function redeemYield(uint256 _periodIndex) public override{
        super.redeemYield(_periodIndex);
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);
        _redeemRegistration(_periodIndex,senderTokenBalance,fyt.totalSupply());
    }

    function _updateDroppedTokenBalances() internal override{
     uint256 nextTotal = getNewTotal();
       for(uint256 i=0;i<droppedTokenBalance.length;i++){
            droppedTokenBalance[i] = droppedTokenBalance[i].add(((nextTotal.sub(totalTokensAccounted)).mul(cellars[i]).mul(nextTotal)).div(totalTokensAccounted.mul(ibt.balanceOf(address(this)))));
       }
       totalTokensAccounted = nextTotal;
    }

}