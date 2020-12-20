pragma solidity >=0.7.0 <0.8.0;

interface IIBTFutureFactory {
    function initialize(address _controller, address _admin) external;

    function deployFutureWithIBT(
        string memory _futurePlatformName,
        address _ibt,
        uint256 _periodDuration
    ) external returns (address);
}
