pragma solidity >=0.7.0 <0.8.0;

interface IAPWineNaming {
    // i.e. 30D-AAVE-ADAI-2
    function genFYTSymbol(
        uint8 _index,
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) external pure returns (string memory);

    function genFYTSymbolFromIBT(uint8 _index, string memory _ibtSymbol) external pure returns (string memory);

    function genIBTSymbol(
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) external pure returns (string memory);

    function getPeriodDurationDenominator(uint256 _periodDuration) external pure returns (string memory);
}
