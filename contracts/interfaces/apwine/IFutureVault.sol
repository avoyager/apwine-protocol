pragma solidity >=0.7.0 <0.8.0;


interface IFutureVault {

    /**
    * @notice Intializer
    * @param _futureAddress the address of the corresponding future
    */  
    function initialize(address _futureAddress) external;


    /**
    * @notice Getter for the future address
    * @return the vinyard address linked to this future wallet
    */  
    function getFutureAddress() external view returns(address);

}