
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper , 2 - Scissors
    mapping (address => bool) public player_not_played;
    address[] public players;
    address[4] public available_addresses = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    uint public numInput = 0;

    function addPlayer() public payable {
        require(_isCallerAvailable(), "You are not available player");
        require(numPlayer < 2, "Already have 2 players");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already the first player");
        }
        require(msg.value == 1 ether, "Need to send 1 ether");
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function input(uint choice) public  {
        require(numPlayer == 2, "Need 2 players");
        require(player_not_played[msg.sender], "You are not the player");
        require(choice == 0 || choice == 1 || choice == 2, "Wrong Input");
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
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
        }
        delete players;
        numInput = 0;
    }

    function _isCallerAvailable() private view returns (bool) {
        for (uint i = 0; i < available_addresses.length; i++) {
            if(msg.sender == available_addresses[i]) return true;
        }
        return false;
    }
}
