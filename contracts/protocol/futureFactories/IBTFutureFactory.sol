pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

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

import "./FutureFactory.sol";

contract IBTFutureFactory is FutureFactory {
    using SafeMathUpgradeable for uint256;

    function deployFutureWithIBT(
        string memory _futurePlatformName,
        address _ibt,
        uint256 _periodDuration
    ) public returns (address) {
        require(hasRole(FUTURE_DEPLOYER, msg.sender), "Caller is not an future admin");
        IRegistry registery = IRegistry(controller.getRegistery());
        require(registery.isRegisteredFuturePlatform(_futurePlatformName), "invalid future platform name");

        address[3] memory futurePlatformContracts = registery.getFuturePlatform(_futurePlatformName);

        IProxyFactory proxyFactory = IProxyFactory(registery.getProxyFactoryAddress());
        address controller_default_admin = controller.getRoleMember(DEFAULT_ADMIN_ROLE, 0);

        /* Deploy the new contracts */
        bytes memory payload =
            abi.encodeWithSignature(
                "initialize(address,address,uint256,string,address,address)",
                address(controller),
                _ibt,
                _periodDuration,
                _futurePlatformName,
                address(this),
                controller_default_admin
            );
        IFuture newFuture = IFuture(proxyFactory.deployMinimal(futurePlatformContracts[0], payload));

        payload = abi.encodeWithSignature("initialize(address,address)", address(newFuture), controller_default_admin);
        address newFutureWallet = proxyFactory.deployMinimal(futurePlatformContracts[1], payload);

        payload = abi.encodeWithSignature("initialize(address,address)", address(newFuture), controller_default_admin);
        address newFutureVault = proxyFactory.deployMinimal(futurePlatformContracts[2], payload);

        /* Liquidity Gauge registration */
        address newLiquidityGauge =
            IGaugeController(registery.getGaugeControllerAddress()).registerNewGauge(address(newFuture));

        /* Configure the new future */
        newFuture.setFutureWallet(newFutureWallet);
        newFuture.setFutureVault(newFutureVault);
        newFuture.setLiquidityGauge(newLiquidityGauge);

        /* Register the newly deployed future */
        controller.registerNewFuture(address(newFuture));
        return address(newFuture);
    }
}
