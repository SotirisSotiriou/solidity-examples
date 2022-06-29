// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.5.9;

import "hardhat/console.sol";

contract Lottery{
    mapping(address => Person) tokenDetails; // διεύθυνση παίκτη
    Person [] bidders; // πίνακας 4 παικτών
    Item [] public items; // πίνακας 3 αντικειμένων
    address[] public winners; // πίνακας νικητών - η τιμή 0 δηλώνει πως δεν υπάρχει νικητής
    address public beneficiary; // ο πρόεδρος του συλλόγου και ιδιοκτήτης του smart contract
    uint bidderCount = 0; // πλήθος των εγγεγραμένων παικτών

    uint randNonce = 0;

    uint minimunPrice = 10**16; // Ελαχιστη τιμή σε Wei ώστε να μπορεί κάποιος να κάνει εγγραφή

    uint totalAmt = 0; // Συνολικά Wei που έχουν δώσει οι παίχτες

    enum Stage {Init, Reg, Bid, Done}
    Stage public stage;

    uint lotteryId = 0;

    event Winner(address _winner, uint _itemId, uint _lottery);

    struct Item{
        uint itemId;
        uint[] itemTokens;
    }


    struct Person{
        uint personId;
        address addr;
        uint remainingTokens;
    }


    constructor(uint itemsCount){
        // Αρχικοποίηση του προέδρου με τη διεύθυνση του κατόχου του έξυπνου συμβολαίου
        beneficiary = msg.sender;
        uint[] memory emptyArray;
        for(uint i = 0; i < itemsCount; i++){
            items.push(Item({itemId:i, itemTokens:emptyArray}));
            winners.push(address(0));
        }

        stage = Stage.Init; // αρχικοποίηση με Init, για να ξεκινήσει η πρώτη λαχειοφόρος πρέπει να γίνει κλήση της advanceState απο τον beneficiary
    }


    modifier validBid(uint itemid, uint count){
        if(itemid < items.length){
            //Ελεγχος αν ο παιχτης έχει κάνει εγγραφή αν έχει αρκετά tokens
            if(tokenDetails[msg.sender].remainingTokens >= count){
                _;
            }
            else{
                revert();
            }
        }
        else{
            revert();
        }
    }


    modifier onlyOwner(){
        if(msg.sender != beneficiary){
            revert();
        }
        _;
    }


    modifier enoughPrice(){
        if(msg.value < minimunPrice){
            revert();
        }
        _;
    }


    modifier canRegister(){
        if(stage == Stage.Reg){
            for(uint i=0; i<bidderCount; i++){
                if(bidders[i].addr == msg.sender){
                    revert();
                }
            }
        }
        else{
            revert();
        }
        _;
    }


    modifier isRegistered(){
        bool found = false;
        for(uint i=0; i<bidderCount; i++){
            if(bidders[i].addr == msg.sender){
                found = true;
                break;
            }
        }
        if(!found){
            revert();
        }
        _;
    }

    modifier canBid() {
        if(stage != Stage.Bid){
            revert();
        }
        _;
    }

    modifier canStartLottery() {
        if(stage != Stage.Done){
            revert();
        }
        _;
    }

    modifier hasNextStage() {
        if(stage == Stage.Done){
            revert();
        }
        _;
    }


    function register() public enoughPrice canRegister payable {
        Person memory bidder = Person({personId:bidderCount, addr:msg.sender, remainingTokens:5});
        bidders.push(bidder);
        bidderCount++;
        tokenDetails[msg.sender] = bidder;
        totalAmt = totalAmt + msg.value;
    }


    function bid(uint _itemId, uint _count) public canBid isRegistered validBid(_itemId, _count) payable { // Ποντάρει _count λαχεία στο αντικείμενο _itemId
        /*
        Ενημέρωση του υπολοίπου λαχείων του παίκτη
        */
        tokenDetails[msg.sender].remainingTokens = tokenDetails[msg.sender].remainingTokens - _count;

        /*
        Ενημέρωση της κληρωτίδας του _itemId με εισαγωγή των _count λαχείων που ποντάρει ο παίκτης
        */
        for(uint i=0; i<_count; i++){
            items[_itemId].itemTokens.push(tokenDetails[msg.sender].personId);
        }

    }


    function revealWinners() public onlyOwner canStartLottery payable { // θα υλοποιήσετε modifier με το όνομα onlyOwner
        /*
        Για κάθε αντικείμενο που έχει περισσότερα από 0 λαχεία στην κάλπη του
        επιλέξτε τυχαία έναν νικητή από όσους έχουν τοποθετήσει το λαχείο τους
        */
        for (uint id = 0; id < items.length; id++) { // Εδώ για 3 μόνο αντικείμενα
            if(items[id].itemTokens.length > 0 && winners[id] == address(0)){
                // παραγωγή τυχαίου αριθμού
                uint randomnumber = randMod(items[id].itemTokens.length);

                // ανάκτηση του αριθμού παίκτη που είχε αυτό το λαχείο
                uint winnerId = items[id].itemTokens[randomnumber];


                // ενημέρωση του πίνακα winners με τη διεύθυνση του νικητή
                for(uint personid = 0; personid <= bidderCount; personid++){
                    if(winnerId == personid){
                        winners[id] = bidders[personid].addr;
                        emit Winner(winners[id], items[id].itemId, lotteryId);
                        break;
                    }
                }

            }
        }
    }


    function randMod(uint _modulus) internal returns(uint) {
        randNonce++; 
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
    }


    function withdraw() public onlyOwner payable {
        payable(beneficiary).transfer(totalAmt);
        totalAmt = 0;
    }


    function reset(uint newItemCount) public onlyOwner payable {
        // μηδενισμός του πίνακα παικτών
        for(uint i=0; i<bidderCount; i++){
            bidders.pop();
        }
        bidderCount = 0;

        // μηδενισμός του πίνακα αντικειμένων
        uint oldLength = items.length;
        for(uint i=0; i<oldLength; i++){
            items.pop();
        }

        // επαναδημιουργία του πίνακα αντικειμένων με νέο μέγεθος
        uint[] memory emptyItemTokensArray;
        for(uint i=0; i<newItemCount; i++){
            items.push(Item({itemId:i, itemTokens:emptyItemTokensArray}));
        }

        // μηδενισμός του πίνακα νικητών
        address[] memory emptyWinnersArray;
        winners = emptyWinnersArray;

        // επαναφορά του stage σε Reg
        stage = Stage.Reg;

        // επομενη λαχειοφόρος
        lotteryId++;
    }


    function advanceState() public onlyOwner hasNextStage payable {
        if(stage == Stage.Init){
            stage = Stage.Reg;
        }
        else if(stage == Stage.Reg){
            stage = Stage.Bid;
        }
        else if(stage == Stage.Bid){
            stage = Stage.Done;
        }
    }


    // ΥΛΟΠΟΙΗΣΤΕ ΟΠΩΣΔΗΠΟΤΕ την παρακάτω συνάρτηση ΑΚΡΙΒΩΣ ΟΠΩΣ ΕΙΝΑΙ παρακάτω.
    function getPersonDetails(uint id) public view returns(uint, uint, address){
        return (bidders[id].remainingTokens, bidders[id].personId, bidders[id].addr);
    } 
}