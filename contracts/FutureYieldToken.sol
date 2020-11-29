pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/presets/ERC20PresetMinterPauser.sol';
import "./interfaces/apwine/IAPWineVineyard.sol";


contract FutureYieldToken is ERC20PresetMinterPauserUpgradeSafe{

    address public vineyard;

    function initialize(string memory _tokenName, string memory _tokenSymbol, address _vineyardAddress) initializer public {
        super.initialize(_tokenName,_tokenSymbol);
        _setupRole(DEFAULT_ADMIN_ROLE, _vineyardAddress);
        _setupRole(MINTER_ROLE, _vineyardAddress);
        _setupRole(PAUSER_ROLE, _vineyardAddress);
        vineyard = _vineyardAddress;

    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if(recipient!=vineyard && recipient!=IAPWineVineyard(vineyard).getCellarAddress()){
            _approve(sender, _msgSender(), allowance(sender,_msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        }
        return true;
    }

}