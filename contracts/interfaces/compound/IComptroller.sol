pragma solidity >=0.4.22 <0.7.3;

interface Comptroller {
    /**
    * @notice Claim all the comp accrued by holder in all markets
    * @param _holder The address to claim COMP for
    */
    function claimComp(address _holder) external;
}