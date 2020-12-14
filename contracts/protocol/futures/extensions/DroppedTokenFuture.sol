// pragma solidity >=0.7.0 <0.8.0;

// import "../../../interfaces/ERC20.sol";
// import "../../../interfaces/apwine/IAPWineFuture.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol
// ";// import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeableUpgradeable.so";
// import '@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol';





// abstract contract APWineDroppedTokens is Initializable{
//     using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
//     using SafeMathUpgradeable for uint256;

//     IAPWineFuture public future;
//     EnumerableSetUpgradeable.AddressSet private tokensDropped;

//     uint256[] private total;

//     mapping(address=>uint256[]) private registrations;
//     address[] private registeredAddresses;

//     /**
//     * @notice Intializer
//     * @param _futureAddress the address of the corresponding future
//     * @param _tokens the address of the differents tokens
//     */  
//     function initialize(address _futureAddress, address[] memory _tokens) internal initializer virtual{
//         future = IAPWineFuture(_futureAddress);   
//         for(uint i = 0; i<_tokens.length;i++){
//             tokensDropped.add(_tokens[i]);
//             total.push();
//         }
//     }

//     function _addRegistration(address _user, uint256 _amount, uint256 _totalSupply) internal virtual{
//         require(_amount>0, "Invalid amount to register");
//         assert(_totalSupply>0);
//         _updateState();
//         for(uint i = 0; i<tokensDropped.length();i++){

//         }

//     }

//     function _delRegistration(address _user, uint256 _amount) internal virtual;

//     function _switchPeriod() internal virtual;

//     function _updateState() internal virtual;

//     function _updateBalances(uint256[] memory _newTotal) internal virtual{
//         for(uint i = 0; i<tokensDropped.length();i++){
//             for(uint j = 0; j<registeredAddresses.length;j++){
//                 registrations[registeredAddresses[j]][i] = (registrations[registeredAddresses[j]][i].mul(_newTotal[i])).div(total[i]);
//             }
//         }
//     }


//     function getRegistrationValue(address _user) public view returns(uint256[] memory){
//         return registrations[_user];
//     }

//     function getDroppedTokenLists() public view returns(address[] memory){
//         address[] list = new address[](tokensDropped.length());
//         for(uint i = 0; i<tokensDropped.length();i++){
//             list[i] = tokensDropped.at(i);
//         }
//         return list;
//     }

// }