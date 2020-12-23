pragma solidity >=0.7.0 <0.8.0;

interface IGaugeController {
    enum FutureTypes {Weekly, Monthly}

    function initialize(
        address _ADMIN,
        address _APW,
        address _registry
    ) external;

    function registerNewGauge(address _future) external returns (address);

    function claimAPW() external;

    function claimAPW(address[] memory _liquidityGauges) external;

    function mint(address _user, uint256 _amount) external;

    function addUserRedeemable(address _user, uint256 _amount) external;




    /* Getters */
    function getLastEpochInflationRate() external view returns (uint256);

    function getGaugeWeight() external view returns (uint256);

    function getGaugeTypeWeight() external view returns (uint256);

    function getEpochLength() external view returns (uint256);

    function getUserRedeemableAPW(address _user) external view returns(uint256);
}
