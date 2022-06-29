
//0xae24cC03f448e0B6f8e5F5f5deB32D24031d5b78

pragma solidity >=0.5.9;

contract Bidder{
    string public name;
    uint public bidAmount = 20000;
    bool public eligible;
    uint constant minBid = 1000;

    function setName(string memory newName) public{
        name = newName;
    }

    function setBidAmount(uint newAmount) public{
        bidAmount = newAmount;
    }

    function determineEligibility() public{
        if(bidAmount >= minBid) {
            eligible = true;
        }
        else {
            eligible = false;
        }
    }
}