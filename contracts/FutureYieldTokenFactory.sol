pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract FutureYieldTokenFactory {
    
    /**
    * @notice Generate a future yield token for a future
    * @param _tokenName name of the future yield token
    * @param _tokenSymbol symbol of the future yield token
    * @return address of the newly created token
    */
    function generateToken(string memory _tokenName, string memory _tokenSymbol) external returns(address){
        ERC20PresetMinterPauser newToken = new ERC20PresetMinterPauser(_tokenName,_tokenSymbol);
        newToken.grantRole(newToken.MINTER_ROLE(), msg.sender);
        return address(newToken);
    }
}