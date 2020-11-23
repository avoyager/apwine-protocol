pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

library APWineMaths{

    using SafeMath for uint256;

    function getScaledInput(uint256 _actualValue, uint256 _initialSum, uint256 _actualSum) public pure returns(uint256){
        if  (_initialSum==0) return _actualValue;
        require(_actualSum>0,"The actual value of the sum should not be zero");
        return ( (_actualValue.mul(_actualValue).mul(_initialSum)).add(_actualValue.mul(_initialSum).mul(_actualSum)) ).div((_actualValue.mul(_actualSum)).add(_actualSum.mul(_actualSum)));
    }

    function getActualOutput(uint256 _scalledOuput, uint256 _initialSum, uint256 _actualSum) public pure returns(uint256){
        if (_initialSum==0) return 0;
        require(_actualSum>0,"The actual value of the sum should not be zero");
        return _scalledOuput.mul(_actualSum).div(_initialSum);

    }
}