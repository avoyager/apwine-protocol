pragma solidity >=0.4.22 <0.7.3;


interface IFutureWallet {

    /**
    * @notice Intializer
    * @param _vineyardAddress the address of the corresponding vineyard
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _vineyardAddress, address _adminAddress) external;

    /**
    * @notice register the yield of an expired period
    * @param _amount the amount of yield to be registered
    */  
    function registerExpiredFuture(uint256 _amount) external;

    /**
    * @notice claim the yield of the underlying yield of the FYT held by the sender
    * @param _periodIndex the index of the period to claim the yield from
    */  
    function claimYield(uint256 _periodIndex) external;

    /**
    * @notice return the yield that could be claimed by an address for a particular period
    * @param _periodIndex the index of the corresponding period
    * @param _tokenHolder the fyt holder
    * @return the yield that could be claimed by the token holder for this period
    */  
    function getClaimableYield(uint256 _periodIndex, address _tokenHolder) external view returns(uint256);
}