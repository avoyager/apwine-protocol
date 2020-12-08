pragma solidity ^0.6.0;

interface IProxyFactory{
  function deployMinimal(address _logic, bytes memory _data) external returns (address proxy);
}
  
