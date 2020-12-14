pragma solidity >=0.7.0 <0.8.0;

library APWineNaming{
    
    function genTokenSymbol(uint8 _index,string memory _ibtSymbol, string memory _platfrom, string memory _periodDenominator) public pure returns (string memory){
        return string(concatenate(string(concatenate(_periodDenominator,string(concatenate(uintToString(_index),_ibtSymbol)))),_platfrom));
    }

    function uintToString(uint v) public pure returns (string memory) {
        bytes memory reversed = new bytes(8);
        uint i = 0;
        if(v==0) return "0";
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = byte(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i + 1);
        for (uint j = 0; j <= i; j++) {
            s[j] = reversed[i - j];
        }
        return string(s);
    }
    
    function concatenate(
        string memory a,
        string memory b)
        public
        pure
        returns(string memory) {
            return string(abi.encodePacked(a, b));
    }
}