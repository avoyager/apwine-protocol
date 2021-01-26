pragma solidity ^0.7.6;

import "contracts/protocol/futures/futureWallets/StreamFutureWallet.sol";

/**
 * @title Contract for Aave Future Wallet
 * @author Gaspard Peduzzi
 * @notice Handles the future wallet mecanisms for the Aave platform
 * @dev Implement directly the stream future wallet abstraction as its fits the aToken ibt
 */
contract AaveFutureWallet is StreamFutureWallet {

}
