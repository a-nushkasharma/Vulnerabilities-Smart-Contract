// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* -------------------- Case 1: Lottery Winner Based on block.timestamp -------------------- */
contract Case1 {
    address[] public players;

    function enter() public payable {
        require(msg.value == 1 ether);
        players.push(msg.sender);
    }

    function pickWinner() public {
        uint index = uint(block.timestamp) % players.length;
        payable(players[index]).transfer(address(this).balance);
    }
}
//  Vulnerability: Miner can adjust block.timestamp slightly to favor a specific index.

/* -------------------- Case 2: Time-Locked Withdraws Based on block.timestamp -------------------- */
contract Case2 {
    mapping(address => uint256) public lockUntil;

    function deposit(uint256 duration) public payable {
        lockUntil[msg.sender] = block.timestamp + duration;
    }

    function withdraw() public {
        require(block.timestamp >= lockUntil[msg.sender], "Still locked");
        payable(msg.sender).transfer(address(this).balance);
    }
}
//  Vulnerability: Miner can slightly manipulate block time to allow premature unlocks.

/* -------------------- Case 3: One-Time Reward Per Day (Trickable) -------------------- */
contract Case3 {
    mapping(address => uint256) public lastClaim;

    function claim() public {
        require(block.timestamp - lastClaim[msg.sender] >= 86400, "Wait a day");
        lastClaim[msg.sender] = block.timestamp;
        // give reward
    }
}
//  Vulnerability: Miner can pack multiple “next-day” blocks in quick succession.

/* -------------------- Case 4: Time-Based Game Outcome -------------------- */
contract Case4 {
    function winIfLucky() public view returns (bool) {
        return (block.timestamp % 100) == 42;
    }

    function play() public {
        require(winIfLucky(), "Try again later");
        // reward
    }
}
//  Vulnerability: Miner can reorder transactions or adjust time to match “lucky” number.

/* -------------------- Case 5: NFT Reveal Logic Tied to Timestamp -------------------- */
contract Case5 {
    string public baseURI;
    uint256 public revealTime;

    constructor(uint256 _revealTime) {
        revealTime = _revealTime;
    }

    function tokenURI(uint tokenId) public view returns (string memory) {
        if (block.timestamp < revealTime) {
            return "hidden.json";
        } else {
            return string(abi.encodePacked(baseURI, "/", uint2str(tokenId), ".json"));
        }
    }

    function setRevealTime(uint256 _time) public {
        revealTime = _time;
    }
}
//  Vulnerability: Miner can reveal/unreveal metadata at will to gain advantage in rarity sniping.

/* -------------------- Case 6: Fair Lottery with block.timestamp for randomness -------------------- */
contract Case6 {
    address[] public participants;

    function enter() public payable {
        participants.push(msg.sender);
    }

    function draw() public {
        require(participants.length > 0);
        uint rand = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        address winner = participants[rand % participants.length];
        payable(winner).transfer(address(this).balance);
    }
}
//  Vulnerability: timestamp used for randomness; miner can manipulate outcome in their favor.

/* -------------------- Case 7: DAO Voting with Expiring Timestamp -------------------- */
contract Case7 {
    struct Proposal {
        string desc;
        uint deadline;
        uint yes;
        uint no;
    }

    mapping(uint => Proposal) public proposals;
    mapping(address => mapping(uint => bool)) public voted;

    function vote(uint id, bool support) public {
        require(block.timestamp <= proposals[id].deadline, "Expired");
        require(!voted[msg.sender][id]);
        voted[msg.sender][id] = true;

        if (support) proposals[id].yes++;
        else proposals[id].no++;
    }
}
//  Vulnerability: Miner can reorder voting near deadline to bias outcome or force expiry.

/* -------------------- Case 8: Airdrop Window Strictly Using Timestamp -------------------- */
contract Case8 {
    uint256 public start;
    uint256 public end;
    mapping(address => bool) public claimed;

    constructor(uint _start, uint _end) {
        start = _start;
        end = _end;
    }

    function claim() public {
        require(block.timestamp >= start && block.timestamp <= end, "Out of window");
        require(!claimed[msg.sender], "Already claimed");
        claimed[msg.sender] = true;
        // airdrop logic
    }
}
//  Vulnerability: Miner or bot can delay tx inclusion or front-run to win edge of airdrop window.
