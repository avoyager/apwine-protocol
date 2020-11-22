
pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "../interfaces/ERC20.sol";
import "../interfaces/apwine/IAPWineVineyard.sol";



contract APWineFutureWallet is Initializable{

    IAPWineVineyard private vineyard;

    /**
    * @notice Intializer
    * @param _vineyardAddress the address of the corresponding vineyard
    */  
    function initialize(address _vineyardAddress) public initializer virtual{
        vineyard = IAPWineVineyard(_vineyardAddress);
        ERC20(vineyard.getIBTAddress()).approve(_vineyardAddress, uint256(-1));
    }

    function getVineyardAddress() public view returns(address){
        return address(vineyard);
    }



}