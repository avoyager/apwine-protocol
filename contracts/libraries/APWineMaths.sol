pragma solidity >=0.4.22 <0.7.3;

import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

library APWineMaths{

    using SafeMath for uint256;

    function getScalledInput(uint256 _actualValue, uint256 _initialSum, uint256 _actualSum) public returns(uint256){
        return _actualValue.mul(_initialSum).div((uint256(1e18).sub(_actualValue.div(_actualValue.add(_actualSum)))).mul(_actualValue.add(_actualSum)));
    }

    function getActualOutput(uint256 _scalledOuput, uint256 _initialSum, uin256 _acutalSum) public returns(uint256){
        return _scalledOuput.mul(_actualSum).div(_initialSum);
    }
}