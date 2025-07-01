// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/* -------------------- Case 1: Token Transfer Underflow -------------------- */
contract Case1 {
    mapping(address => uint256) public balances;

    constructor() {
        balances[msg.sender] = 100;
    }

    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount; // underflow possible
        balances[to] += amount;
    }
}

/* -------------------- Case 2: Privilege Escalation via Role Overflow -------------------- */
contract Case2 {
    mapping(address => uint8) public roles;

    function escalate() public {
        roles[msg.sender] += 1; // 255+1 = 0
    }

    function isAdmin(address user) public view returns (bool) {
        return roles[user] == 255;
    }
}

/* -------------------- Case 3: Refund Logic Underflow -------------------- */
contract Case3 {
    mapping(address => uint256) public refunds;
    address public highestBidder;
    uint public highestBid;

    function bid() public payable {
        require(msg.value > highestBid);
        refunds[highestBidder] += highestBid;
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function claimRefund(uint256 amount) public {
        refunds[msg.sender] -= amount; // underflow bug
        msg.sender.transfer(amount);
    }
}

/* -------------------- Case 4: Locking Period Overflow -------------------- */
contract Case4 {
    mapping(address => uint256) public unlockTime;

    function lock(uint256 duration) public {
        unlockTime[msg.sender] = block.timestamp + duration; // overflow possible
    }

    function unlock() public {
        require(block.timestamp >= unlockTime[msg.sender], "Too early");
    }
}

/* -------------------- Case 5: Staking Reward Overflow -------------------- */
contract Case5 {
    uint256 public rewardPerBlock = 1e18;
    uint256 public lastUpdateBlock;
    mapping(address => uint256) public rewards;

    function update(address user) public {
        uint256 blocks = block.number - lastUpdateBlock;
        uint256 reward = blocks * rewardPerBlock; // reward overflow
        rewards[user] += reward;
        lastUpdateBlock = block.number;
    }
}

/* -------------------- Case 6: Escrow Overflow in Balances -------------------- */
contract Case6 {
    mapping(address => uint256) public deposits;

    function deposit(uint256 amount) public payable {
        deposits[msg.sender] += amount; // attacker repeatedly deposits small amounts → overflow
    }

    function release(address payable user) public {
        uint amount = deposits[user];
        deposits[user] = 0;
        user.transfer(amount);
    }
}

/* -------------------- Case 7: Loyalty Points Wraparound -------------------- */
contract Case7 {
    mapping(address => uint16) public points;

    function earn(uint16 value) public {
        points[msg.sender] += value; // wraparound at 65535
    }

    function spend(uint16 value) public {
        require(points[msg.sender] >= value, "Not enough");
        points[msg.sender] -= value;
    }
}

/* -------------------- Case 8: Inflation by Overflow in Mint -------------------- */
contract Case8 {
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    function mint(address to, uint256 amount) public {
        balances[to] += amount;
        totalSupply += amount; // overflow leads to broken supply cap checks
    }

    function isCapped(uint256 cap) public view returns (bool) {
        return totalSupply <= cap;
    }
}

/* -------------------- Case 9: Auction With Wraparound Refund -------------------- */
contract Case9 {
    mapping(address => uint256) public pendingReturns;

    function bid(uint amount) public {
        require(amount > 1000);
        pendingReturns[msg.sender] += amount; // overflow if repeated bids
    }

    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        pendingReturns[msg.sender] -= amount; // underflow if amount = 0
        msg.sender.transfer(amount);
    }
}

/* -------------------- Case 10: Integer Division Truncation + Underflow -------------------- */
contract Case10 {
    mapping(address => uint256) public shares;

    function assignShares(uint256 totalSupply, uint256 numUsers) public {
        uint256 perUser = totalSupply / numUsers; // integer division
        shares[msg.sender] = perUser;
    }

    function burn(uint256 amount) public {
        shares[msg.sender] -= amount; // underflow if perUser = 0 and burn called
    }
}
