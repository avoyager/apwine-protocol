pragma solidity >=0.4.22 <0.7.3;


interface IAPWineFutureWallet {

    /**
    * @notice Intializer
    * @param _vineyardAddress the address of the corresponding vineyard
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _vineyardAddress, address _adminAddress) external;


    /**
    * @notice Getter for the vineyard address
    * @return the vinyard address linked to this future wallet
    */  
    function getVineyardAddress() external view returns(address);

}