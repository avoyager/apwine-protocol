pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/futureWallets/RateFutureWallet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

abstract contract DroppedFutureWallet is Initializable {
    using SafeMathUpgradeable for uint256;

    uint256[] internal droppedTokenBalance;
    uint256 internal totalTokensAccounted;

    ERC20 public droppedToken;

    function _tokenDroppedinitialize(address _droppedToken) internal virtual initializer {
        droppedToken = ERC20(_droppedToken);
    }

    function _updateDroppedTokenBalances() internal virtual;

    function _addTDRegistration(uint256 _amount) internal {
        _updateDroppedTokenBalances();
        droppedTokenBalance.push(_amount);
        totalTokensAccounted = getNewTotal().add(_amount);
    }

    function _redeemRegistration(
        uint256 _index,
        uint256 _senderAmount,
        uint256 _periodTotalSupply
    ) internal {
        _updateDroppedTokenBalances();
        uint256 redeemable = (droppedTokenBalance[_index].mul(_senderAmount)).div(_periodTotalSupply);
        droppedTokenBalance[_index] = droppedTokenBalance[_index].sub(redeemable);
        totalTokensAccounted = totalTokensAccounted.sub(redeemable);
        if (redeemable > 0) droppedToken.transfer(msg.sender, redeemable);
    }

    function getNewTotal() internal virtual returns (uint256);
}
