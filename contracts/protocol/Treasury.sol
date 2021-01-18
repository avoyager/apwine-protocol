pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Treasury Contract
 * @author Gaspard Peduzzi
 * @notice the treasury of the protocols, allow to store and transfer funds
 */
contract Treasury is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @notice Initializer of the contract
     * @param _adminAddress the address the admin of the contract
     */
    function initialize(address _adminAddress) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }

    /**
     * @notice send erc20 tokens to an address
     * @param _erc20 the address of the erc20 token
     * @param _recipient the address of the recipient
     * @param _amount the amount of token to send
     */
    function sendToken(
        address _erc20,
        address _recipient,
        uint256 _amount
    ) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IERC20Upgradeable(_erc20).transfer(_recipient, _amount);
    }

    /**
     * @notice send ether to an address
     * @param _recipient the address of the recipient
     * @param _amount the amount of ether to send
     */
    function sendEther(address payable _recipient, uint256 _amount) public payable {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _recipient.transfer(_amount);
    }
}
