
pragma solidity >=0.7.0 <0.8.0;


import '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "contracts/interfaces/ERC20.sol";
import "contracts/interfaces/apwine/tokens/IFutureYieldToken.sol";
import "contracts/interfaces/apwine/IFuture.sol";

import "contracts/libraries/APWineMaths.sol";


abstract contract FutureWallet is Initializable, AccessControlUpgradeable{

    using SafeMathUpgradeable for uint256;


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IFuture public future;
    ERC20 public ibt;

    /**
    * @notice Intializer
    * @param _futureAddress the address of the corresponding future
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _futureAddress, address _adminAddress) public initializer virtual{
        future = IFuture(_futureAddress);   
        ibt =  ERC20(future.getIBTAddress());     
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }

    /**
    * @notice register the yield of an expired period
    * @param _amount the amount of yield to be registered
    */  
    function registerExpiredFuture(uint256 _amount) public virtual;

    /**
    * @notice redeem the yield of the underlying yield of the FYT held by the sender
    * @param _periodIndex the index of the period to redeem the yield from
    */  
    function redeemYield(uint256 _periodIndex) public virtual{
        require(_periodIndex<future.getNextPeriodIndex()-1,"Invalid period index");
        IFutureYieldToken fyt = IFutureYieldToken(future.getFYTofPeriod(_periodIndex));
        uint256 senderTokenBalance = fyt.balanceOf(msg.sender);
        require(senderTokenBalance > 0,"FYT sender balance should not be null");
        require(fyt.transferFrom(msg.sender, address(this), senderTokenBalance),"Failed transfer");

        uint256 claimableYield = _updateYieldBalances(_periodIndex, senderTokenBalance, fyt.totalSupply());

        ibt.transfer(msg.sender, claimableYield);
        fyt.burn(senderTokenBalance);
    }   

    /**
    * @notice return the yield that could be redeemed by an address for a particular period
    * @param _periodIndex the index of the corresponding period
    * @param _tokenHolder the fyt holder
    * @return the yield that could be redeemed by the token holder for this period
    */  
    function getRedeemableYield(uint256 _periodIndex, address _tokenHolder) public view virtual returns(uint256);

    function _updateYieldBalances(uint256 _periodIndex, uint256 _cavistFYT, uint256 _totalFYT) internal virtual returns(uint256);


    /**
    * @notice getter for the address of the future corresponding to this future wallet
    * @return the address of the future
    */  
    function getFutureAddress() public view virtual returns(address){
        return address(future);
    }

    /**
    * @notice getter for the address of the ibt corresponding to this future wallet
    * @return the address of the ibt
    */  
    function getIBTAddress() public view virtual returns(address){
        return address(ibt);
    }

}