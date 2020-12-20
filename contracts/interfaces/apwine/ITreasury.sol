pragma solidity >=0.7.0 <0.8.0;

interface ITreasury{

    function initialize(address _adminAddress) external;

    function sendToken(address _erc20, address _recipient, uint256 _amount) external;

    function sendEther(address payable _recipient,uint256 _amount) payable external;

}