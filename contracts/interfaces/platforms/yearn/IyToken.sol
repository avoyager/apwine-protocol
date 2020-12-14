
pragma solidity >=0.7.0 <0.8.0;

import "contracts/interfaces/ERC20.sol";

interface yToken is ERC20 {
    function getPricePerFullShare() external view returns (uint256);
}

