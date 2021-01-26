pragma solidity ^0.7.6;

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

/**
 * @title Future Factory abstraction
 * @author Gaspard Peduzzi
 * @notice Handles the deployement of new futures
 * @dev Basis to build different types of futures depending on their inner functionning
 */
abstract contract FutureFactory is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    /* ACR */
    bytes32 public constant FUTURE_DEPLOYER = keccak256("FUTURE_DEPLOYER");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    IController internal controller;

    /**
     * @notice Initializer for the contract
     * @param _controller the controller for the futures
     * @param _admin the address that will have the admin right on this contract
     */
    function initialize(address _controller, address _admin) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(CONTROLLER_ROLE, _controller);
        controller = IController(_controller);
    }
}
