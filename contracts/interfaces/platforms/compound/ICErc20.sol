pragma solidity >=0.7.0 <0.8.0;

import "contracts/interfaces/ERC20.sol";

interface CErc20 is ERC20{
    function exchangeRateStored() external view returns (uint);
}