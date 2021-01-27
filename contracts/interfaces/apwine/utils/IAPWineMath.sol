pragma solidity ^0.7.6;

interface IAPWineMaths {
    /**
     * @notice scaled an input
     * @param _actualValue the original value of the input
     * @param _initialSum the scaled value of the sum of the inputs
     * @param _actualSum the current value of the sum of the inputs
     */
    function getScaledInput(
        uint256 _actualValue,
        uint256 _initialSum,
        uint256 _actualSum
    ) external pure returns (uint256);

    /**
     * @notice scale back a value to the output
     * @param _scalledOuput the current scaled output
     * @param _initialSum the scaled value of the sum of the inputs
     * @param _actualSum the current value of the sum of the inputs
     */
    function getActualOutput(
        uint256 _scalledOuput,
        uint256 _initialSum,
        uint256 _actualSum
    ) external pure returns (uint256);
}
