pragma solidity >=0.7.0 <0.8.0;


interface IAPWineMaths {

    function getScaledInput(
        uint256 _actualValue,
        uint256 _initialSum,
        uint256 _actualSum
    ) external pure returns (uint256);

    function getActualOutput(
        uint256 _scalledOuput,
        uint256 _initialSum,
        uint256 _actualSum
    ) external pure returns (uint256);
}
