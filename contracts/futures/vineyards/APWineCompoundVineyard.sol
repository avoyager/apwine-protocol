pragma solidity >=0.4.22 <0.7.3;

import "./APWineRateIBTVineyard.sol";
import "../../interfaces/compound/ICerc20.sol";


contract APWineCompoundVineyard is APWineRateIBTVineyard{

    function getIBTRate() public view override returns(uint256){
        return CErc20(address(ibt)).exchangeRateStored();
    }

}