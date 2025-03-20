// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";
import "./IERC20.sol";

contract RPS {
    // 0 - Scissors, 1 - Paper, 2 - Rock, 3 - Lizard, 4 - Spock
    
    CommitReveal public commitReveal;
    TimeUnit public timeUnit;
    IERC20 public token;

    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice;
    mapping (address => bool) public player_not_played;
    mapping (address => bool) public player_revealed;
    address[] public players;

    uint public numInput = 0;
    uint public numReveal = 0;
    uint public gameDuration = 20 minutes;
    uint public stakeAmount = 0.000001 ether;

    constructor(address _tokenAddress) {
        commitReveal = new CommitReveal();
        timeUnit = new TimeUnit();
        token = IERC20(_tokenAddress);
    }

    function addPlayer() public {
        require(numPlayer < 2, "Already have 2 players");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already the first player");
        }
        require(token.allowance(msg.sender, address(this)) >= stakeAmount, "Need to approve stake amount");
        players.push(msg.sender);
        numPlayer++;
        if (numPlayer == 1) {
            timeUnit.setStartTime();
        }
    }

    function input(bytes32 dataHash) public {
        require(numPlayer == 2, "Need 2 players");
        require(player_not_played[msg.sender], "You have chosen the choice");
        require(token.allowance(msg.sender, address(this)) >= stakeAmount, "Insufficient allowance");
        
        // Transfer stake amount from player to contract
        token.transferFrom(msg.sender, address(this), stakeAmount);
        reward += stakeAmount;
        
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

        if ((p0Choice + 1) % 5 == p1Choice || ((p0Choice + 3) % 5 == p1Choice)) {
            // account 0 wins
            token.transfer(account0, reward);
        }
        else if ((p1Choice + 1) % 5 == p0Choice || ((p1Choice + 3) % 5 == p0Choice)) {
            // account 1 wins
            token.transfer(account1, reward);
        }
        else {
            token.transfer(account0, reward / 2);
            token.transfer(account1, reward / 2);
        }
        _reset();
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        delete players;
        numInput = 0;
        numReveal = 0;
    }

    function getChoiceFromHash(bytes32 revealHash) public pure returns (uint8) {
        uint8 choice = uint8(revealHash[revealHash.length - 1]) % 5;
        return choice;
    }

    function getRefund() public {
        require(numPlayer > 0, "The game has not started");
        uint elapsed = timeUnit.elapsedSeconds();
        require(elapsed >= gameDuration, "Not enough time passed to get refund");

        if (numPlayer == 2 && numInput == 2 && numReveal < 2 && elapsed >= gameDuration) {
            address payable recipient;
            if (numReveal == 1) {
                if (player_revealed[players[0]]) {
                    recipient = payable(players[0]);
                } else {
                    recipient = payable(players[1]);
                }
                token.transfer(recipient, reward);
            } else {
                token.transfer(msg.sender, reward);
            }
            _reset();
        }
    }

    function getElapsedTime() public view returns (uint) {
        return timeUnit.elapsedSeconds();
    }

    function getCommit(address sender) public view returns (bytes32, bool) {
        return commitReveal.getCommit(sender);
    }
}
