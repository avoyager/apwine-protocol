
pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "../interfaces/ERC20.sol";
import "../interfaces/apwine/IFuture.sol";



contract FutureVault is Initializable,AccessControlUpgradeSafe{

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAVIST_ROLE = keccak256("CAVIST_ROLE");

    IFuture private future;


    /**
    * @notice Intializer
    * @param _futureAddress the address of the corresponding future
    */  
    function initialize(address _futureAddress,address _adminAddress) public initializer virtual{
        future = IFuture(_futureAddress);
        ERC20(future.getIBTAddress()).approve(_futureAddress, uint256(-1));
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(CAVIST_ROLE, _futureAddress);
    }

    function getFutureAddress() public view returns(address){
        return address(future);
    }

    function approveAdditionalToken(address _tokenAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to register approve another token");
        ERC20(_tokenAddress).approve(address(future), uint256(-1));
    }



}