pragma solidity 0.7.6;

interface IGaugeController {
    enum FutureTypes {Weekly, Monthly}

    /**
     * @notice Intializer of the contract
     * @param _ADMIN the address of the admin of the contract
     * @param _registry the address of the registry
     */
    function initialize(address _ADMIN, address _registry) external;

    /**
     * @notice Deploy a new liquidity gauge for a newly created future and register in in the registry
     * @param _future the address of the new future
     * @return the address of the new liquidity gauge
     */
    function registerNewGauge(address _future) external returns (address);

    /**
     * @notice Claim all claimable APW rewards for the sender
     * @dev not gas efficient, claim function with specified liquidity gauges saves gas
     */
    function claimAPW() external;

    /**
     * @notice Claim all claimable APW rewards for the sender for a specified list of liquidity gauges
     * @param _liquidityGauges the the list of liquidity gauges to claim the rewards of
     */
    function claimAPW(address[] memory _liquidityGauges) external;

    /**
     * @notice Admin function to pause APW whitdrawals
     */
    function pauseAPWWithdrawals() external;

    /**
     * @notice Admin function to resume APW whitdrawals
     */
    function resumeAPWWithdrawals() external;

    /* Getters */

    /**
     * @notice Getter for the inflation rate of the current epoch
     * @return the inflation rate of the current epoch
     */
    function getLastEpochInflationRate() external view returns (uint256);

    /**
     * @notice Getter for weight of one gauge
     * @param _liquidityGauge the address of the liquidity gauge to get the weight of
     * @return the weight of the gauge
     */
    function getGaugeWeight(address _liquidityGauge) external view returns (uint256);

    /**
     * @notice Getter for duration of one epoch
     * @return the duration of one epoch
     */
    function getEpochLength() external view returns (uint256);

    /**
     * @notice Getter for duration of one epoch
     * @param _future the address of the future to check the liquidity gauge of
     * @return the address of the liquidity gauge of the future
     */
    function getLiquidityGaugeOfFuture(address _future) external view returns (address);

    /**
     * @notice Getter for the total redeemable APW of one user
     * @param _user the address of the user to get the redeemable APW of
     * @return the total amount of APW redeemable
     */
    function getUserRedeemableAPW(address _user) external view returns (uint256);

    /**
     * @notice Getter for the current state of rewards withdrawal availability
     * @return true if the users can withdraw their redeemable APW, false otherwise
     */
    function getWithdrawableState() external view returns (bool);

    /**
     * @notice Getter for the registry address
     * @return the registry address
     */
    function getRegistry() external view returns (address);

    /**
     * @notice Setter for the inflation rate of the epoch
     * @param _inflationRate the new inflation rate of the epoch
     */
    function setEpochInflationRate(uint256 _inflationRate) external;

    /**
     * @notice Setter for the weight of one liquidity gauge
     * @param _liquidityGauge the address of the liquidity gauge
     * @param _gaugeWeight the new weight of the liquidity gauge
     */
    function setGaugeWeight(address _liquidityGauge, uint256 _gaugeWeight) external;

    /**
     * @notice Setter for the length of the epochs
     * @param _epochLength the new length of the epochs
     */
    function setEpochLength(uint256 _epochLength) external;

    /**
     * @notice Setter for the APW token addres
     * @param _APW the APW token address
     * @dev can only be called once
     */
    function setAPW(address _APW) external;

    /**
     * @notice Setter for the registry address
     * @param _registry the new registry address
     */
    function setRegistry(address _registry) external;
}
