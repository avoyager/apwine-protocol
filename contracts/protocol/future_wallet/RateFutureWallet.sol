pragma solidity >=0.4.22 <0.7.3;

import "./FutureWallet.sol";

abstract contract RateFutureWallet is FutureWallet{

    uint256[] internal cellars;

    function initialize(address _vineyardAddress, address _adminAddress) public initializer override{
        super.initialize(_vineyardAddress,_adminAddress);
    }

    function registerExpiredFuture(uint256 _amount) public override{
        require(hasRole(CAVIST_ROLE, msg.sender), "Caller is not allowed to register a harvest");
        cellars.push(_amount);
    }


    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view override returns(uint256){
        IFutureYieldToken fyt = IFutureYieldToken(vineyard.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(_tokenHolder);
        return (senderTokenBalance.mul(cellars[_periodIndex])).div(fyt.totalSupply());
    }

    function _updateYieldBalances(uint256 _periodIndex, uint256 _cavistFYT, uint256 _totalFYT) internal override returns(uint256){
        uint256 claimableYield = (_cavistFYT.mul(cellars[_periodIndex])).div(_totalFYT);
        cellars[_periodIndex] = cellars[_periodIndex].sub(claimableYield);
        return claimableYield;
    }

}