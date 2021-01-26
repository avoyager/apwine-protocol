pragma solidity ^0.7.6;

interface IIBTFutureFactory {
    function initialize(address _controller, address _admin) external;

    /**
     * @notice update gauge and user liquidity state then return the new redeemable
     * @param _futurePlatformName the name of the platform of the future to create
     * @param _ibt the ibt for the future
     * @param _periodDuration the duration of the period of the future
     * @return the address of the newly created future contract
     */
    function deployFutureWithIBT(
        string memory _futurePlatformName,
        address _ibt,
        uint256 _periodDuration
    ) external returns (address);
}
