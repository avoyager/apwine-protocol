pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/presets/ERC20PresetMinterPauser.sol';


contract FutureYieldToken is ERC20PresetMinterPauserUpgradeSafe{
    function initialize(string memory _tokenName, string memory _tokenSymbol, address _futureAddress) initializer public {
        super.initialize(_tokenName,_tokenSymbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _futureAddress);
        _setupRole(MINTER_ROLE, _futureAddress);
        _setupRole(PAUSER_ROLE, _futureAddress);
    }

}
