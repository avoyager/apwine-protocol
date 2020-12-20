pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Treasury is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function initialize(address _adminAddress) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }

    function sendToken(
        address _erc20,
        address _recipient,
        uint256 _amount
    ) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        IERC20Upgradeable(_erc20).transfer(_recipient, _amount);
    }

    function sendEther(address payable _recipient, uint256 _amount)
        public
        payable
    {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _recipient.transfer(_amount);
    }
}
