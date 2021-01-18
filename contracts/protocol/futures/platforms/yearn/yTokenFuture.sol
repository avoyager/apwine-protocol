pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/RateFuture.sol";
import "contracts/interfaces/platforms/yearn/IyToken.sol";

contract yTokenFuture is RateFuture {
    function getIBTRate() public view override returns (uint256) {
        return yToken(address(ibt)).getPricePerFullShare();
    }
}
