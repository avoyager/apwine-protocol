pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/RateFuture.sol";
import "contracts/interfaces/platforms/yearn/IyToken.sol";

/**
 * @title Contract for yToken Future
 * @author Gaspard Peduzzi
 * @notice Handles the future mecanisms for the Aave platform
 * @dev Implement directly the stream future abstraction as its fits the aToken ibt
 */
contract yTokenFuture is RateFuture {
    /**
     * @notice Getter for the rate of the ibt
     * @return the uint256 rate, ibt x rate must be equal to the quantity of underlying tokens
     */
    function getIBTRate() public view override returns (uint256) {
        return yToken(address(ibt)).getPricePerFullShare();
    }
}
