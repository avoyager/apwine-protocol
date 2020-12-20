pragma solidity >=0.7.0 <0.8.0;

interface IProxyFactory {
    function deployMinimal(address _logic, bytes memory _data)
        external
        returns (address proxy);
}
