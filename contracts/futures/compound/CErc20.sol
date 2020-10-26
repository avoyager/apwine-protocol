pragma solidity >=0.4.22 <0.7.3;

import "../../interfaces/ERC20.sol";

abstract contract CErc20 is ERC20{
    function exchangeRateStored() virtual public view returns (uint);
}