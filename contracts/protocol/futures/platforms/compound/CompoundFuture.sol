pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/RateFuture.sol";
import "contracts/interfaces/platforms/compound/ICErc20.sol";


contract CompoundFuture is RateFuture{

    function getIBTRate() public view override returns(uint256){
        return CErc20(address(ibt)).exchangeRateStored();
    }

}