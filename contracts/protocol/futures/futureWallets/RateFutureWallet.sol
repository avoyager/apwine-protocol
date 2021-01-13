pragma solidity >=0.7.0 <0.8.0;

import "contracts/protocol/futures/futureWallets/FutureWallet.sol";

abstract contract RateFutureWallet is FutureWallet {
    using SafeMathUpgradeable for uint256;

    uint256[] internal futureWallets;

    function initialize(address _futureAddress, address _adminAddress) public override initializer {
        super.initialize(_futureAddress, _adminAddress);
    }

    function registerExpiredFuture(uint256 _amount) public override {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to register a harvest");
        futureWallets.push(_amount);
    }

    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view override returns (uint256) {
        IFutureYieldToken fyt = IFutureYieldToken(future.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        return (senderTokenBalance.mul(futureWallets[_periodIndex])).div(fyt.totalSupply());
    }

    function _updateYieldBalances(
        uint256 _periodIndex,
        uint256 _userFYT,
        uint256 _totalFYT
    ) internal override returns (uint256) {
        uint256 claimableYield = (_userFYT.mul(futureWallets[_periodIndex])).div(_totalFYT);
        futureWallets[_periodIndex] = futureWallets[_periodIndex].sub(claimableYield);
        return claimableYield;
    }
}
