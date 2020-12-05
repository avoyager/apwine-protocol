
pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "../interfaces/ERC20.sol";
import "../interfaces/apwine/IFuture.sol";



contract FutureVault is Initializable,AccessControlUpgradeSafe{

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CAVIST_ROLE = keccak256("CAVIST_ROLE");

    IFuture private vineyard;


    /**
    * @notice Intializer
    * @param _vineyardAddress the address of the corresponding vineyard
    */  
    function initialize(address _vineyardAddress,address _adminAddress) public initializer virtual{
        vineyard = IFuture(_vineyardAddress);
        ERC20(vineyard.getIBTAddress()).approve(_vineyardAddress, uint256(-1));
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
        _setupRole(CAVIST_ROLE, _vineyardAddress);
    }

    function getVineyardAddress() public view returns(address){
        return address(vineyard);
    }

    function approveAdditionalToken(address _tokenAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not allowed to register approve another token");
        ERC20(_tokenAddress).approve(address(vineyard), uint256(-1));
    }



}