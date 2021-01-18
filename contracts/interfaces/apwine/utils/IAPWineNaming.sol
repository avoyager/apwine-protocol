pragma solidity >=0.7.0 <0.8.0;

interface IAPWineNaming {
    /**
     * @notice generate the symbol of the FYT
     * @param _index the index of the current period
     * @param _ibtSymbol the symbol of the ibt
     * @param _platfrom the platform name
     * @param _periodDuration the period duration
     * @return the symbol fo the FYT
     * @dev i.e 30D-AAVE-ADAI-2
     */
    function genFYTSymbol(
        uint8 _index,
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) external pure returns (string memory);

    /**
     * @notice generate the FYT symbol from the apwibt
     * @param _index the index of the current period
     * @param _ibtSymbol the symbol of the ibt
     * @return the symbol fo the FYT
     * @dev i.e 30D-AAVE-ADAI-2
     */
    function genFYTSymbolFromIBT(uint8 _index, string memory _ibtSymbol) external pure returns (string memory);

    /**
     * @notice generate the apwibt symbol
     * @param _ibtSymbol the symbol of the ibt of the future
     * @param _platfrom the platfrom name
     * @param _periodDuration the period duration
     * @return the symbol fo the apwibt
     * @dev i.e 30D-AAVE-ADAI
     */
    function genIBTSymbol(
        string memory _ibtSymbol,
        string memory _platfrom,
        uint256 _periodDuration
    ) external pure returns (string memory);

    /**
     * @notice generate the period denominator
     * @param _periodDuration the period duration
     * @return the period denominator
     * @dev i.e 30D
     */
    function getPeriodDurationDenominator(uint256 _periodDuration) external pure returns (string memory);
}
