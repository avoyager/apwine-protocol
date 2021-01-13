pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableMapUpgradeable.sol";

import "contracts/interfaces/apwine/tokens/IAPWToken.sol";

contract Registry is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;

    /* ACR ROLE */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /* Addresses */
    address private apw;
    address private vesting;
    address private controller;
    address private treasury;
    address private gaugeController;
    EnumerableSetUpgradeable.AddressSet private futures;

    /* Futures Contracts */
    EnumerableSetUpgradeable.AddressSet private futureVaultsLogic;
    EnumerableSetUpgradeable.AddressSet private futureWalletsLogic;
    EnumerableSetUpgradeable.AddressSet private futuresLogic;

    mapping(address => string) private futureVaultName;
    mapping(address => string) private futureWalletName;
    mapping(address => string) private futureName;

    /* Futures Platforms Contracts */
    EnumerableSetUpgradeable.AddressSet private futureFactories;
    mapping(address => string) private futureFactoriesNames;

    string[] private futurePlatformsNames;
    mapping(string => address) private futurePlatformToDeployer;
    mapping(string => futurePlatform) private futurePlatformsName;

    /* Struct */
    struct futurePlatform {
        address future;
        address futureVault;
        address futureWallet;
    }

    /* Proxy */
    address private proxyFactory;
    address private liquidityGaugeLogic;
    address private APWineIBTLogic;
    address private FYTLogic;

    event RegisteryUpdate(string _contractName, address _old, address _new);
    event FuturePlatformAdded(
        address _futureFactory,
        string _futurePlatformName,
        address _future,
        address _futureWallet,
        address _futureVault
    );

    function initialize(address _admin) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
    }

    /* Setters */
    function setTreasury(address _newTreasury) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("Treasury", treasury, _newTreasury);
        treasury = _newTreasury;
    }

    function setGaugeController(address _newGaugeController) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("GaugeController", gaugeController, _newGaugeController);
        gaugeController = _newGaugeController;
    }

    function setController(address _newController) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("Controller", controller, _newController);
        _setupRole(CONTROLLER_ROLE, _newController);
        revokeRole(CONTROLLER_ROLE, controller);
        controller = _newController;
    }

    function setAPW(address _newAPW) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("APW", apw, _newAPW);
        apw = _newAPW;
    }

    /* Getters */
    function getDAOAddress() public view returns (address) {
        return IAPWToken(apw).getDAO();
    }

    function getAPWAddress() public view returns (address) {
        return apw;
    }

    function getVestingAddress() public view returns (address) {
        return IAPWToken(apw).getVestingContract();
    }

    function getControllerAddress() public view returns (address) {
        return controller;
    }

    function getTreasuryAddress() public view returns (address) {
        return treasury;
    }

    function getGaugeControllerAddress() public view returns (address) {
        return gaugeController;
    }

    /* Logic setters*/
    function setProxyFactory(address _proxyFactory) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("Proxy Factory", proxyFactory, _proxyFactory);
        proxyFactory = _proxyFactory;
    }

    function setLiquidityGaugeLogic(address _liquidityGaugeLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("LiquidityGauge logic", liquidityGaugeLogic, _liquidityGaugeLogic);
        liquidityGaugeLogic = _liquidityGaugeLogic;
    }

    function setAPWineIBTLogic(address _APWineIBTLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("APWineIBT logic", APWineIBTLogic, _APWineIBTLogic);
        APWineIBTLogic = _APWineIBTLogic;
    }

    function setFYTLogic(address _FYTLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        emit RegisteryUpdate("FYT  Logic", _FYTLogic, _FYTLogic);
        FYTLogic = _FYTLogic;
    }

    /* Logic getters */
    function getProxyFactoryAddress() public view returns (address) {
        return proxyFactory;
    }

    function getLiquidityGaugeLogicAddress() public view returns (address) {
        return liquidityGaugeLogic;
    }

    function getAPWineIBTLogicAddress() public view returns (address) {
        return APWineIBTLogic;
    }

    function getFYTLogicAddress() public view returns (address) {
        return FYTLogic;
    }

    /* Futures Deployer */
    function addFutureFactory(address _futureFactory, string memory _futureFactoryName) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        futureFactories.add(_futureFactory);
        futureFactoriesNames[_futureFactory] = _futureFactoryName;
    }

    function isRegisteredFutureFactory(address _futureFactory) public view returns (bool) {
        return futureFactories.contains(_futureFactory);
    }

    function getFutureFactoryAt(uint256 _index) external view returns (address) {
        return futureFactories.at(_index);
    }

    function futurePlatformDeployerCount() external view returns (uint256) {
        return futureFactories.length();
    }

    function getFutureFactoryName(address _futureFactory) external view returns (string memory) {
        require(futureFactories.contains(_futureFactory), "invalid future platform deployer");
        return futureFactoriesNames[_futureFactory];
    }

    /* Future Platform */
    function addFuturePlatform(
        address _futureFactory,
        string memory _futurePlatformName,
        address _future,
        address _futureWallet,
        address _futureVault
    ) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(futureFactories.contains(_futureFactory), "invalid future platfrom deployer address");

        futurePlatform memory newFuturePlaform =
            futurePlatform({futureVault: _futureVault, futureWallet: _futureWallet, future: _future});

        if (!isRegisteredFuturePlatform(_futurePlatformName)) futurePlatformsNames.push(_futurePlatformName);

        futurePlatformsName[_futurePlatformName] = newFuturePlaform;
        futurePlatformToDeployer[_futurePlatformName] = _futureFactory;
        emit FuturePlatformAdded(_futureFactory, _futurePlatformName, _future, _futureWallet, _futureVault);
    }

    function removeFuturePlatform(string memory _futurePlatformName) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(isRegisteredFuturePlatform(_futurePlatformName), "invalid future platform name");

        for (uint256 i = 0; i < futurePlatformsNames.length; i++) {
            // can be optimized
            if (keccak256(bytes(futurePlatformsNames[i])) == keccak256(bytes(_futurePlatformName))) {
                delete futurePlatformsNames[i];
                break;
            }
        }

        delete futurePlatformToDeployer[_futurePlatformName];
        delete futurePlatformsName[_futurePlatformName];
    }

    function isRegisteredFuturePlatform(string memory _futurePlatformName) public view returns (bool) {
        for (uint256 i = 0; i < futurePlatformsNames.length; i++) {
            if (keccak256(bytes(futurePlatformsNames[i])) == keccak256(bytes(_futurePlatformName))) return true;
        }
        return false;
    }

    function getFuturePlatform(string memory _futurePlatformName) public view returns (address[3] memory) {
        futurePlatform memory futurePlatformContracts = futurePlatformsName[_futurePlatformName];
        address[3] memory addressesArrays =
            [futurePlatformContracts.future, futurePlatformContracts.futureWallet, futurePlatformContracts.futureVault];
        return addressesArrays;
    }

    function futurePlatformsCount() external view returns (uint256) {
        return futurePlatformsNames.length;
    }

    function getFuturePlatformNames() external view returns (string[] memory) {
        return futurePlatformsNames;
    }

    /* Futures */
    function addFuture(address _future) public returns (bool) {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not an admin");
        return futures.add(_future);
    }

    function removeFuture(address _future) public returns (bool) {
        require(hasRole(CONTROLLER_ROLE, msg.sender), "Caller is not an admin");
        return futures.remove(_future);
    }

    function isRegisteredFuture(address _future) external view returns (bool) {
        return futures.contains(_future);
    }

    function getFutureAt(uint256 _index) external view returns (address) {
        return futures.at(_index);
    }

    function futureCount() external view returns (uint256) {
        return futures.length();
    }

    /* Future Wallets Logic */
    function isRegisteredFutureWallet(address _futureWallet) external view returns (bool) {
        return futureWalletsLogic.contains(_futureWallet);
    }

    function getFuturWalletAt(uint256 _index) external view returns (address) {
        return futureWalletsLogic.at(_index);
    }

    function futureWalletCount() external view returns (uint256) {
        return futureWalletsLogic.length();
    }

    function getFutureWalletName(address _futureWalletAddress) external view returns (string memory) {
        require(futureWalletsLogic.contains(_futureWalletAddress), "invalid address");
        return futureWalletName[_futureWalletAddress];
    }

    /* Future Vault Logic*/
    function isRegisteredFutureVault(address _futureVault) public view returns (bool) {
        return futureWalletsLogic.contains(_futureVault);
    }

    function getFutureVaultAt(uint256 _index) public view returns (address) {
        return futureWalletsLogic.at(_index);
    }

    function futureVaultCount() external view returns (uint256) {
        return futureWalletsLogic.length();
    }

    function getFutureVaultName(address _futureVault) external view returns (string memory) {
        require(futureWalletsLogic.contains(_futureVault), "invalid address");
        return futureWalletName[_futureVault];
    }

    /* Future Logic*/
    function isRegisteredFutureLogic(address _futureLogic) external view returns (bool) {
        return futuresLogic.contains(_futureLogic);
    }

    function getFutureLogicAt(uint256 _index) external view returns (address) {
        return futuresLogic.at(_index);
    }

    function futureLogicCount() external view returns (uint256) {
        return futuresLogic.length();
    }

    function getFutureLogicName(address _futureLogicAddress) external view returns (string memory) {
        require(futuresLogic.contains(_futureLogicAddress), "invalid address");
        return futureWalletName[_futureLogicAddress];
    }
}
