pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

interface IRegistry{

    function setTreasury(address _newTreasury) external;
    function setGaugeController(address _newGaugeController) external;
    function setController(address _newController) external;
    function setAPW(address _newAPW) external;

    function getControllerAddress() external view returns(address);
    function getTreasuryAddress() external view returns(address);
    function getGaugeControllerAddress() external view returns(address);

    function getDAOAddress() external returns(address);
    function getAPWAddress() external view returns(address);
    function getVestingAddress() external view returns(address);

    function setProxyFactory(address _proxyFactory) external;
    function setLiquidityGaugeLogic(address _liquidityGaugeLogic) external;
    function setAPWineIBTLogic(address _APWineIBTLogic) external;
    function setFYTLogic(address _FYTLogic) external;

    function getProxyFactoryAddress() external view returns(address);
    function getLiquidityGaugeLogicAddress() external view returns(address);
    function getAPWineIBTLogicAddress() external view returns(address);
    function getFYTLogicAddress() external view returns(address);

    function addFuturePlatformDeployer(address _futurePlatformDeployer, string memory _futurePlatformDeployerName) external;
    function isRegisteredFuturePlatformDeployer(address _futurePlatformDeployer) external view returns(bool);
    function getFuturePlatformDeployerAt(uint256 _index) external view returns(address);
    function futurePlatformDeployerCount() external view returns(uint256) ;
    function getFuturePlatformDeployerName(address _futurePlatformDeployer) external view returns(string memory);
    
    function addFuturePlatform(address _futurePlatformDeployer, string memory _futurePlatformName, address _future, address _futureWallet, address _futureVault) external;
    function isRegisteredFuturePlatform(string memory _futurePlatformName) external view returns(bool);
    function getFuturePlatform(string memory _futurePlatformName) external view returns(address[3] memory);
    function futurePlatformsCount() external view returns (uint256) ;
    function getFuturePlatformNames() external view returns(string[] memory);
    function removeFuturePlatform(string memory _futurePlatformName) external;

    function addFuture(address _future) external returns(bool);
    function removeFuture(address _future) external returns(bool);
    function isRegisteredFuture(address _future) external view returns(bool);
    function getFutureAt(uint256 _index) external view returns(address);
    function futureCount() external view returns (uint256) ;

    function isRegisteredFutureWallet(address _futureWallet) external view returns(bool);
    function getFuturWalletAt(uint256 _index) external view returns(address);
    function futureWalletCount() external view returns (uint256) ;
    function getFutureWalletName(address _futureWalletAddress) external view returns(string memory);

    function isRegisteredFutureVault(address _futureVault) external view returns(bool);
    function getFutureVaultAt(uint256 _index) external view returns(address);
    function futureVaultCount() external view returns (uint256) ;
    function getFutureVaultName(address _futureVault) external view returns(string memory);

    function isRegisteredFutureLogic(address _futureLogic) external view returns(bool);
    function getFutureLogicAt(uint256 _index) external view returns(address);
    function futureLogicCount() external view returns (uint256) ;
    function getFutureLogicName(address _futureLogicAddress) external view returns(string memory);
}