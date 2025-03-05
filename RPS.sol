
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    // 0 - Scissors, 1 - Paper, 2 - Rock, 3 - Lizard, 4 - Spock

    CommitReveal public commitReveal;
    TimeUnit public timeUnit;

    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice;
    mapping (address => bool) public player_not_played;
    mapping (address => bool) public player_revealed;
    address[] public players;
    address[4] public available_addresses = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    uint public numInput = 0;
    uint public numReveal = 0;
    uint public gameDuration = 20 minutes;

    constructor() {
        commitReveal = new CommitReveal();
        timeUnit = new TimeUnit();
        
    }

    function addPlayer() public payable {
        require(_isCallerAvailable(), "You are not available player");
        require(numPlayer < 2, "Already have 2 players");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already the first player");
        }
        require(msg.value == 1 ether, "Need to send 1 ether");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        player_revealed[msg.sender] = false;
        players.push(msg.sender);
        numPlayer++;
        if (numPlayer == 1) {
            timeUnit.setStartTime();
        }
    }

    function input(bytes32 dataHash) public  {
        require(numPlayer == 2, "Need 2 players");
        require(player_not_played[msg.sender], "You have chosen the choice");
        // commit hash
        commitReveal.commit(dataHash, msg.sender);
        player_not_played[msg.sender] = false;
        numInput++;
    }

    function revealChoice (bytes32 revealHash) public {
        require(numInput == 2, "Need input from 2 players before reveal");
        require(!player_revealed[msg.sender], "You have already revealed");
        player_revealed[msg.sender] = true;
        // reveal hash
        commitReveal.reveal(revealHash, msg.sender);
        uint8 choiceFromHash = getChoiceFromHash(revealHash);
        player_choice[msg.sender] = choiceFromHash;
        numReveal++;
        if (numReveal == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        // Rules
        // Scissors (0) < [Rock (2), Spock (4)]
        // Paper (1) < [Scissors (0), Lizard (3)]
        // Rock (2) < [Paper (1), Spock (4)]
        // Lizard (3) < [Rock (2), Scissors (0)]
        // Spock (4) < [Paper (1), Lizard (3)]

        if ((p0Choice + 1) % 5 == p1Choice || ((p0Choice + 3) % 5 == p1Choice)) {
            // account 0 wins
            account0.transfer(reward);
        }
        else if ((p1Choice + 1) % 5 == p0Choice || ((p1Choice + 3) % 5 == p0Choice)) {
            // account 1 wins
            account1.transfer(reward);    
        }
        else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        _reset();
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        for (uint i = 0; i < available_addresses.length; i++) {
            delete player_choice[available_addresses[i]];
            delete player_not_played[available_addresses[i]];
            delete player_revealed[available_addresses[i]];
        }
        delete players;
        numInput = 0;
        numReveal = 0;
    }

    function _isCallerAvailable() private view returns (bool) {
        for (uint i = 0; i < available_addresses.length; i++) {
            if(msg.sender == available_addresses[i]) return true;
        }
        return false;
    }

    function getChoiceFromHash(bytes32 revealHash) public pure returns (uint8) {
        // Get the last byte and mod by 5
        uint8 choice = uint8(revealHash[revealHash.length - 1]) % 5;
        return choice;
    }

    // get refund
    function getRefund() public {
        require(_isCallerAvailable(), "You are not available player");
        require(numPlayer > 0, "The game has not started");
        uint elapsed = timeUnit.elapsedSeconds();
        require(elapsed >= gameDuration, "Not enough time passed to get refund");
        if (numPlayer == 1 && elapsed >= gameDuration) {
            // no player 2 in game duration
            address payable account0 = payable(players[0]);
            account0.transfer(reward);
            _reset();
        }
        else if (numPlayer == 2 && numInput < 2 && elapsed >= gameDuration) {
            // any player does not input choice in game duration
            address payable account0 = payable(players[0]);
            address payable account1 = payable(players[1]);
            account0.transfer(reward/2);
            account1.transfer(reward/2);
            _reset();
        }
        else if (numPlayer == 2 && numInput == 2 && numReveal < 2 && elapsed >= gameDuration) {
            // player does not reveal choice in game duration
            address payable account0 = payable(players[0]);
            address payable account1 = payable(players[1]);
            if (numReveal == 0) {
                account0.transfer(reward/2);
                account1.transfer(reward/2);
                _reset();
            }
            else if (player_revealed[players[0]]) {
                account0.transfer(reward);
                _reset();
            }
            else if (player_revealed[players[1]]) {
                account1.transfer(reward);
                _reset();
            }
        }
    }

    function getElapsedTime() public view returns (uint) {
        return timeUnit.elapsedSeconds();
    }

    function getCommit(address sender) public view returns (bytes32, bool) {
        return commitReveal.getCommit(sender);
    }
}
