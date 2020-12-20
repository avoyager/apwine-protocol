pragma solidity >=0.7.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableMapUpgradeable.sol";

import "contracts/interfaces/apwine/IFuture.sol";
import "contracts/interfaces/apwine/IFutureVault.sol";
import "contracts/interfaces/apwine/IFutureWallet.sol";
import "contracts/interfaces/IProxyFactory.sol";
import "contracts/interfaces/apwine/IRegistry.sol";
import "contracts/interfaces/apwine/IController.sol";
import "contracts/interfaces/apwine/IGaugeController.sol";

abstract contract FutureFactory is Initializable, AccessControlUpgradeable{
    using SafeMathUpgradeable for uint256;

    /* ACR */
    bytes32 public constant FUTURE_DEPLOYER = keccak256("FUTURE_DEPLOYER");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    IController internal controller;

    function initialize(address _controller, address _admin) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(CONTROLLER_ROLE, _controller);
        controller = IController(_controller);
    }

}
