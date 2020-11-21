
pragma solidity >=0.4.22 <0.7.3;


interface IAPWineVineyard{

    struct Registration{
        uint256 startIndex;
        uint256 scaledBalance;
        bool ibtClaimed;
    }

    /**
    * @notice Intializer
    * @param _controllerAddress the address of the controller
    * @param _ibt the address of the corresponding ibt
    * @param _periodLength the length of the period (in days)
    * @param _tokenName the APWineIBT name
    * @param _tokenSymbol the APWineIBT symbol
    * @param _adminAddress the address of the ACR admin
    */  
    function initialize(address _controllerAddress, address _ibt, uint256 _periodLength,string memory _tokenName, string memory _tokenSymbol,address _adminAddress) external;


    /**
    * @notice Set future wallet address
    * @param _futureWalletAddress the address of the new future wallet
    * @dev needs corresponding permissions for sender
    */
    function setFutureWallet(address _futureWalletAddress) external;

    /**
    * @notice Set cellar address
    * @param _cellarAddress the address of the new cellar
    * @dev needs corresponding permissions for sender
    */
    function setCellar(address _cellarAddress) external;

    /**
    * @notice Sender registers an amount of ibt for the next period
    * @param _winegrower address to register to the future
    * @param _amount amount of ibt to be registered
    * @dev called by the controller only
    */
    function register(address _winegrower ,uint256 _amount) external;

    /**
    * @notice Sender unregisters an amount of ibt for the next period
    * @param _amount amount of ibt to be unregistered
    */
    function unregister(uint256 _amount) external;

    /**
    * @notice Sender unlock the locked funds corresponding to its apwibt holding
    * @param _amount amount of funds to unlocked
    * @dev will require transfer of fyt of the oingoing period corresponding to the funds unlocked
    */
    function withdrawLockFunds(uint _amount) external;

    /**
    * @notice Send the winemaker its apwibt
    * @param _winemaker address to send the apwibt to
    */
    function claimAPWIBT(address _winemaker) external;

    /**
    * @notice Send the winemaker its owed fyt
    * @param _winemaker address of the winemaker to send the fyt to
    */
    function claimFYT(address _winemaker) external;

    /**
    * @notice Send the winemaker its owed fyt for a particular period
    * @param _winemaker address of the winemaker to send the fyt to
    * @param _periodIndex index of the period
    */
    function claimFYTforPeriod(address _winemaker, uint256 _periodIndex) external;

    /**
    * @notice Start a new period
    * @param _tokenName name for the new fyt
    * @param _tokenSymbol name for the new fyt
    * @dev needs corresponding permissions for sender
    */
    function startNewPeriod(string memory _tokenName, string memory _tokenSymbol) external;

    /**
    * @notice Getter for winemaker registered amount 
    * @param _winemaker winemaker to return the registered funds of
    * @return the registered amount, 0 if no registrations
    * @dev the registration can be older than for the next period
    */
    function getRegisteredAmount(address _winemaker) external view returns(uint256);

    /**
    * @notice Check if a winemaker has fyt not claimed
    * @param _winemaker the winemaker to check
    * @return true if the winemaker can claim some fyt, false otherwise
    */
    function hasClaimableFYT(address _winemaker) external view returns(bool);

    /**
    * @notice Getter for next period index
    * @return next period index
    * @dev index starts at 1
    */
    function getNextPeriodIndex() external view returns(uint256);


    /**
    * @notice Getter for future wallet address
    * @return future wallet address
    */
    function getFutureWalletAddress() external view returns(address);

    /**
    * @notice Getter for cellar address
    * @return cellar address
    */
    function getCellarAddress() external view returns(address);


    /**
    * @notice Getter for the ibt address
    * @return ibt address
    */
    function getIBTAddress() external view returns(address);

    /**
    * @notice Getter for future apwibt address
    * @return apwibt address
    */
    function getAPWIBTAddress() external view returns(address);

    /**
    * @notice Getter for fyt address of a particular period
    * @param _periodIndex period index
    * @return fyt address
    */
    function getFYTofPeriod(uint256 _periodIndex) external view returns(address);


}