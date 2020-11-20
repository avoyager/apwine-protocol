
pragma solidity >=0.4.22 <0.7.3;


import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";

import "../../interfaces/ERC20.sol";
import "../../interfaces/apwine/IFutureYieldToken.sol";
import "../../interfaces/apwine/IAPWineFuture.sol";


abstract contract APWineCellar is Initializable, AccessControlUpgradeSafe{

    using SafeMath for uint256;


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAVIST_ROLE = keccak256("CAVIST_ROLE");

    IAPWineFuture public future;

    /**
    * @notice Intializer
    * @param _futureAddress the address of the corresponding future
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _futureAddress, address _adminAddress) public initializer virtual{
        future = IAPWineFuture(_futureAddress);        
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(CAVIST_ROLE, _futureAddress);
    }

    /**
    * @notice register the yield of an expired period
    * @param _amount the amount of yield to be registered
    */  
    function registerExpiredFuture(uint256 _amount) public virtual;

    /**
    * @notice claim the yield of the underlying yield of the FYT held by the sender
    * @param _periodIndex the index of the period to claim the yield from
    */  
    function claimYield(uint256 _periodIndex) public virtual;

    /**
    * @notice return the yield that could be claimed by an address for a particular period
    * @param _periodIndex the index of the corresponding period
    * @param _tokenHolder the fyt holder
    * @return the yield that could be claimed by the token holder for this period
    */  
    function getClaimableYield(uint256 _periodIndex, address _tokenHolder) public view virtual returns(uint256);
}