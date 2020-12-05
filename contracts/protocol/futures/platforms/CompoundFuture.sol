pragma solidity >=0.4.22 <0.7.3;

import "../RateFuture.sol";
import "contracts/interfaces/platforms/compound/ICErc20.sol";


contract CompoundFuture is RateFuture{

    function getIBTRate() public view override returns(uint256){
        return CErc20(address(ibt)).exchangeRateStored();
    }

}