pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "contracts/interfaces/apwine/IFuture.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *  - modified logic for transfer that claims apwibt on both ends if claimable
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to aother accounts
 */
contract APWineIBT is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public future;

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
        future = _futureAddress;
    }

    function __ERC20PresetMinterPauser_init(
        string memory name,
        string memory symbol
    ) internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20PresetMinterPauser_init_unchained(name, symbol);
    }

    function __ERC20PresetMinterPauser_init_unchained(
        string memory name,
        string memory symbol
    ) internal initializer {
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
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have minter role to mint"
        );
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
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to pause"
        );
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
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to unpause"
        );
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);

        // sender and receiver state update
        if (from != future && to != future) {
            if (IFuture(future).hasClaimableFYT(from)) {
                IFuture(future).claimFYT(from);
            }
            if (IFuture(future).hasClaimableFYT(to)) {
                IFuture(future).claimFYT(to);
            }
        }
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if (recipient != future) {
            _approve(
                sender,
                _msgSender(),
                allowance(sender, _msgSender()).sub(
                    amount,
                    "ERC20: transfer amount exceeds allowance"
                )
            );
        }
        return true;
    }

    uint256[50] private __gap;
}
