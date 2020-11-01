pragma solidity >=0.4.22 <0.7.3;

interface IFutureYieldTokenFactory {
    
    /**
    * @notice Generate a future yield token for a future
    * @param _tokenName name of the future yield token
    * @param _tokenSymbol symbol of the future yield token
    * @return address of the newly created token
    */
    function generateToken(string memory _tokenName, string memory _tokenSymbol) external returns(address);
}