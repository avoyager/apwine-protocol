pragma solidity >=0.4.22 <0.7.3;

import "../../interfaces/ERC20.sol";

interface CErc20 is ERC20{
    function exchangeRateStored() virtual external view returns (uint);
}