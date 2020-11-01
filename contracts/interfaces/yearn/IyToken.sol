
pragma solidity >=0.4.22 <0.7.3;

import "../../interfaces/ERC20.sol";

interface yToken is ERC20 {
    function getPricePerFullShare() virtual external view returns (uint256);
}

