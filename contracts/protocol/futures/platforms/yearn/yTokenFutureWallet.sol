pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/futureWallets/RateFutureWallet.sol";

/**
 * @title Contract for yToken Future Wallet
 * @author Gaspard Peduzzi
 * @notice Handles the future wallet mecanisms for the yearn platform
 * @dev Implement directly the rate future wallet abstraction as its fits the yToken ibt
 */
contract yTokenFutureWallet is RateFutureWallet {

}
