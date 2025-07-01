// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* -------------------- Case 1: Unbounded Loop -------------------- */
contract Case1 {
    address[] public users;

    function register() external {
        users.push(msg.sender);
    }

    function payAll() external {
        for (uint i = 0; i < users.length; i++) {
            payable(users[i]).transfer(1 wei); // unbounded loop: large array = out of gas
        }
    }
}

/* -------------------- Case 2: Transfer to Contract with Expensive Fallback -------------------- */
contract VictimCase2 {
    address public richUser;

    function setRichUser(address user) public {
        richUser = user;
    }

    function reward() public payable {
        payable(richUser).transfer(msg.value); // transfer provides 2300 gas only
    }
}

contract AttackerCase2 {
    fallback() external payable {
        // Uses more than 2300 gas → .transfer fails
        for (uint i = 0; i < 100; i++) {
            uint x = i**2;
        }
    }
}

/* -------------------- Case 3: Block `selfdestruct` Refund via Gas Burn -------------------- */
contract VictimCase3 {
    function nuke(address payable target) public {
        selfdestruct(target); // intended to refund gas
    }
}

contract AttackerCase3 {
    fallback() external payable {
        // prevent gas refund by using all gas
        while (true) {
            // Infinite loop
        }
    }
}

/* -------------------- Case 4: Reentrancy Gas Bomb (not logic reentrancy) -------------------- */
contract VictimCase4 {
    mapping(address => uint) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent);
    }
}

contract AttackerCase4 {
    fallback() external payable {
        // burn gas just enough to make Victim revert on `require(sent)`
        for (uint i = 0; i < 10000; i++) {
            keccak256(abi.encodePacked(i));
        }
    }
}

/* -------------------- Case 5: Gas Limit Front-running in Bidding -------------------- */
contract Case5 {
    struct Bid {
        address bidder;
        uint amount;
    }

    Bid[] public bids;

    function placeBid() public payable {
        bids.push(Bid(msg.sender, msg.value));
    }

    function finalize() public {
        uint highest = 0;
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].amount > highest) {
                highest = bids[i].amount;
            }
        }

        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].amount < highest) {
                payable(bids[i].bidder).transfer(bids[i].amount);
            }
        }
    }
}

// Attacker places many low bids → finalizer fails from gas limit

/* -------------------- Case 6: Denial-of-Service on Array Remove -------------------- */
contract Case6 {
    address[] public whitelist;

    function add(address user) public {
        whitelist.push(user);
    }

    function remove(address user) public {
        for (uint i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == user) {
                whitelist[i] = whitelist[whitelist.length - 1];
                whitelist.pop();
                return;
            }
        }
    }

    // Attacker adds 10,000 dummy users → causes DoS when others try remove
}

/* -------------------- Case 7: State Cleanup With Costly Writes -------------------- */
contract Case7 {
    mapping(address => uint[]) public data;

    function store(uint size) public {
        for (uint i = 0; i < size; i++) {
            data[msg.sender].push(i);
        }
    }

    function clear() public {
        delete data[msg.sender]; // deleting large dynamic array → expensive gas
    }
}

// Attacker writes huge array to make `clear()` unaffordable for others

/* -------------------- Case 8: Block Gas Limit Abuse via Nested Calls -------------------- */
contract RecursiveCaller {
    function recurse(uint depth) public {
        if (depth == 0) return;
        this.recurse(depth - 1); // each call adds stack/gas usage
    }
}

contract Case8 {
    RecursiveCaller public helper;

    constructor(address _helper) {
        helper = RecursiveCaller(_helper);
    }

    function trigger() public {
        helper.recurse(100); // attacker sets up low gas block, this fails
    }
}
