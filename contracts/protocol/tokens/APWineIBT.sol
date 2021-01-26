pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "contracts/protocol/tokens/ClaimableERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "contracts/interfaces/apwine/IFuture.sol";
import "contracts/interfaces/apwine/ILiquidityGauge.sol";

/**
 * @title APWine interest bearing token
 * @author Gaspard Peduzzi
 * @notice Interest bearing token for the futures liquidity provided
 * @dev the value of apwine ibt is equivalent to a fixed amount of underlying token of the future ibt
 */
contract APWineIBT is Initializable, ContextUpgradeable, AccessControlUpgradeable, ClaimableERC20 {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IFuture public future;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
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

    function __ERC20PresetMinterPauser_init(string memory name, string memory symbol) internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20PresetMinterPauser_init_unchained(name, symbol);
    }

    function __ERC20PresetMinterPauser_init_unchained(string memory name, string memory symbol) internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        // sender and receiver state update
        if (from != address(future) && to != address(future)) {
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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (future.hasClaimableFYT(sender)) future.claimFYT(sender);
        super._transfer(sender, recipient, amount);
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
