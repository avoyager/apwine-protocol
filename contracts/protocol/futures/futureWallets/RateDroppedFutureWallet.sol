pragma solidity >=0.7.0 <0.8.0;

import "./RateFutureWallet.sol";
import "./DroppedFutureWallet.sol";

abstract contract RateDroppedFutureWallet is RateFutureWallet, DroppedFutureWallet {
    using SafeMathUpgradeable for uint256;

    function initialize(
        address _futureAddress,
        address _adminAddress,
        address _droppedToken
    ) public virtual initializer {
        super.initialize(_futureAddress, _adminAddress);
        _tokenDroppedinitialize(_droppedToken);
    }

    function redeemYield(uint256 _periodIndex) public override {
        super.redeemYield(_periodIndex);
        IFutureYieldToken fyt = IFutureYieldToken(future.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);
        _redeemRegistration(_periodIndex, senderTokenBalance, fyt.totalSupply());
    }

    function _updateDroppedTokenBalances() internal override {
        uint256 nextTotal = getNewTotal();
        for (uint256 i = 0; i < droppedTokenBalance.length; i++) {
            droppedTokenBalance[i] = droppedTokenBalance[i].add(
                ((nextTotal.sub(totalTokensAccounted)).mul(futureWallets[i]).mul(nextTotal)).div(
                    totalTokensAccounted.mul(ibt.balanceOf(address(this)))
                )
            );
        }
        totalTokensAccounted = nextTotal;
    }
}
