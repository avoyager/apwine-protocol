pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "contracts/interfaces/apwine/IFuture.sol";

/**
 * @title Future Yield Token erc20
 * @author Gaspard Peduzzi
 * @notice ERC20 mintabble pausable
 * @dev future yield tokens are minted at the beginning of one period and can be burned against their underlying yield at the expiration of the period
 */
contract FutureYieldToken is ERC20PresetMinterPauserUpgradeable {
    using SafeMathUpgradeable for uint256;

    address public future;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _futureAddress
    ) public initializer {
        super.initialize(_tokenName, _tokenSymbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _futureAddress);
        _setupRole(MINTER_ROLE, _futureAddress);
        _setupRole(PAUSER_ROLE, _futureAddress);
        future = _futureAddress;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if (recipient != future && recipient != IFuture(future).getFutureWalletAddress()) {
            _approve(
                sender,
                _msgSender(),
                allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance")
            );
        }
        return true;
    }
}
