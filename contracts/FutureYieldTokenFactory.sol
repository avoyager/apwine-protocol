pragma solidity >=0.4.22 <0.7.3;

import "./oz-upgradability-solc6/upgradeability/ProxyFactory.sol";
import './FutureYieldToken.sol';
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";


contract FutureYieldTokenFactory is Initializable, AccessControlUpgradeSafe, ProxyFactory{

    /* ACR Roles*/
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");


    /* Events */
    event TokenCreated(address indexed _tokenAddress);

    /* Attributes */
    address private FutureYieldTokenLogic;

    /**
     * @notice Initializer of the FutureYieldTokenFactory contract
     * @param _adminAddress the address of the admin
    */
    function initialize(address _adminAddress) initializer public {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(ADMIN_ROLE, _adminAddress);
    }
    
    /**
    * @notice Generate a future yield token for a future
    * @param _tokenName name of the future yield token
    * @param _tokenSymbol symbol of the future yield token
    * @return address of the newly created token
    */
    function generateToken(string memory _tokenName, string memory _tokenSymbol) external returns(address){
        bytes memory payload = abi.encodeWithSignature("initialize(string,string)", _tokenName, _tokenSymbol);
        address Newtoken = deployMinimal(FutureYieldTokenLogic, payload);
        FutureYieldToken(Newtoken).grantRole(FutureYieldToken(Newtoken).MINTER_ROLE(), msg.sender);
        return Newtoken;
    }


    /**
     * @notice Change the FutureYieldToken contract logic address
     * @param _FutureYieldTokenLogic the address of the new FutureYieldToken logic
     */
    function setFutureYieldTokenLogic(address _FutureYieldTokenLogic) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        FutureYieldTokenLogic = _FutureYieldTokenLogic;
    }
}