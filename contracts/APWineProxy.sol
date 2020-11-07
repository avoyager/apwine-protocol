pragma solidity >=0.4.22 <0.7.3;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/apwine/IFutureYieldToken.sol";
import "./interfaces/apwine/IAPWineFuture.sol";
import "./interfaces/apwine/IAPWineController.sol";
import "./interfaces/ERC20.sol";

contract APWineProxy  is Ownable{

    using SafeMath for uint256;

    uint256 internal constant MAX_UINT256 = uint256(-1);

    /* Attributes */

    IAPWineController private controller;

    mapping (address => uint256) public registeredFunds;

    /* Modifiers */

    modifier onlyController() {
        require(msg.sender == address(controller), "Caller is not controller");
        _;
    }

    modifier onlyFuture() {
        require(controller.isRegisteredFuture(msg.sender), "Invalid future");
        _;
    }

    /* Initializer */

    constructor(address _controller) public {
        controller = IAPWineController(_controller);
    }

    /* Public */

    /**
     * @notice Withdraws a token amount from the proxy
     * @param _token the token to withdraw
     * @param _amount the amount to withdraw
     */
    function withdraw(address _token, uint256 _amount) onlyOwner public {
        ERC20 token = ERC20(_token);
        require(_amount <= token.balanceOf(address(this)).sub(registeredFunds[_token]), "Insufficient funds");
        token.transfer(msg.sender, _amount);
    }

    /**
     * @notice Registers to a future
     * @param _futureAddress the future address to register to
     * @param _index the period index to register ti
     * @param _amount the amount to register
     * @param _autoRegister whether to register again automatically when the period ends
     */
    function registerToFuture(address _futureAddress, uint256 _index, uint256 _amount, bool _autoRegister) onlyOwner public {
        address tokenAddress =  IAPWineFuture(_futureAddress).IBTokenAddress();
        ERC20 token = ERC20(tokenAddress);
        token.approve(address(_futureAddress), MAX_UINT256);
        require(_amount <= token.balanceOf(address(this)).sub(registeredFunds[tokenAddress]), "Insufficient registered funds");
        IAPWineFuture(_futureAddress).registerToPeriod(_index, _amount, _autoRegister);
        registeredFunds[tokenAddress] = registeredFunds[tokenAddress].add(_amount);
    }

    /**
     * @notice Unregisters from a future
     * @param _futureAddress the future address to unregister from
     * @param _index the period index to unregister from
     * @param _amount the amount to unregister
     */
    function unregisterFromFuture(address _futureAddress, uint256 _index, uint256 _amount) onlyOwner public {
        IAPWineFuture future = IAPWineFuture(_futureAddress);
        future.unregisterAmountToPeriod(_index, _amount);
        address tokenAddress = future.IBTokenAddress();
        registeredFunds[tokenAddress] = registeredFunds[tokenAddress].sub(_amount);
    }

    /**
     * @notice Quit an ongoing future
     * @param _futureAddress the future address to quit from
     * @param _index the period index to quit from
     * @param _amount the amount to withdraw
     */
    function quitFuture(address _futureAddress, uint _index, uint _amount) onlyOwner public{
        IAPWineFuture future = IAPWineFuture(_futureAddress);
        future.quitFuture(_index, _amount);
    }


    /**
     * @notice Sends registered funds from the proxy to a future
     * @dev The future calls this function to transfer all registered funds when the period starts
     */
    function collect() onlyFuture public {
        IAPWineFuture future = IAPWineFuture(msg.sender);
        ERC20 interestToken = ERC20(future.IBTokenAddress());
        interestToken.transfer(msg.sender, registeredFunds[address(interestToken)]);
    }

}