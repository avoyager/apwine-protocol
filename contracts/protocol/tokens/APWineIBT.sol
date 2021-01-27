pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/tokens/MinterPauserClaimableERC20.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "contracts/interfaces/apwine/ILiquidityGauge.sol";

/**
 * @title APWine interest bearing token
 * @author Gaspard Peduzzi
 * @notice Interest bearing token for the futures liquidity provided
 * @dev the value of apwine ibt is equivalent to a fixed amount of underlying token of the future ibt
 */
contract APWineIBT is MinterPauserClaimableERC20 {
    using SafeMathUpgradeable for uint256;

    IFuture public future;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * future
     *
     * See {ERC20-constructor}.
     */

    function initialize(
        string memory name,
        string memory symbol,
        address _futureAddress
    ) public {
        __ERC20PresetMinterPauser_init(name, symbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _futureAddress);
        _setupRole(MINTER_ROLE, _futureAddress);
        _setupRole(PAUSER_ROLE, _futureAddress);
        future = IFuture(_futureAddress);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        // sender and receiver state update
        if (from != address(future) && to != address(future) && from != address(0x0) && to != address(0x0)) {
            // update apwibt and fyt balances befores executing the transfer
            if (future.hasClaimableFYT(from)) {
                future.claimFYT(from);
            }
            if (future.hasClaimableFYT(to)) {
                future.claimFYT(to);
            }
            ILiquidityGauge(future.getLiquidityGaugeAddress()).transferUserLiquidty(from, to, amount); // update the liquidity providing state of the users
        }
    }

    /**
     * @notice transfer a defined amount of apwibt from one user to another
     * @param sender sender address
     * @param recipient recipient address
     * @param amount amount of apwibt to be transfered
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if (recipient != address(future)) {
            _approve(
                sender,
                _msgSender(),
                allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance")
            );
        }
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public override {
        if (msg.sender != address(future)) {
            super.burnFrom(account, amount);
        } else {
            _burn(account, amount);
        }
    }

    /**
     * @notice returns the current balance of one user including the apwibt that were not claimed yet
     * @param account the address of the account to check the balance of
     * @return the total apwibt balance of one address
     */
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account).add(future.getClaimableAPWIBT(account));
    }

    uint256[50] private __gap;
}
