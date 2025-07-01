// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* -------------------- Case 1: tx.origin-based Access Control -------------------- */
contract Case1 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function sensitive() external {
        require(tx.origin == owner, "Not owner"); // vulnerable to phishing via contract call
        // Critical operation
    }
}

/* -------------------- Case 2: Missing Visibility (default to public) -------------------- */
contract Case2 {
    address owner;

    constructor() {
        owner = msg.sender;
    }

    // Forgot to make internal/private
    function destroy() external {
        require(msg.sender == owner, "Not owner");
        selfdestruct(payable(msg.sender));
    }
}

/* -------------------- Case 3: Public Delegatecall Entrypoint -------------------- */
contract LogicCase3 {
    function setOwner(address newOwner) public {
        assembly {
            sstore(0x0, newOwner)
        }
    }
}

contract ProxyCase3 {
    address public implementation;

    constructor(address impl) {
        implementation = impl;
    }

    function exec(bytes calldata data) public {
        implementation.delegatecall(data); // no restriction on who can call
    }
}

/* -------------------- Case 4: Constructor Bypass (pre-0.7.0 style) -------------------- */
contract Case4 {
    address public owner;

    function Case4() public {
        owner = msg.sender; // Not a constructor in Solidity ≥0.4.22 — it's a public function!
    }

    function withdraw() public {
        require(msg.sender == owner);
        // ...
    }
}

/* -------------------- Case 5: Uninitialized Proxy Storage Slot -------------------- */
contract LogicCase5 {
    address public owner;

    function setOwner(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }
}

contract ProxyCase5 {
    address public logic;

    constructor(address _logic) {
        logic = _logic;
    }

    fallback() external payable {
        (bool success, ) = logic.delegatecall(msg.data);
        require(success);
    }
}

// If proxy doesn't initialize storage, owner is 0x0 and attacker can setOwner

/* -------------------- Case 6: Overloaded Function Shadowing -------------------- */
contract Case6 {
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    function set(uint value) public {
        require(msg.sender == admin);
        //...
    }

    function set(string memory name) public {
        // attacker can call this one with string and bypass admin check!
    }
}

/* -------------------- Case 7: External Contract Ownership Injection -------------------- */
contract RegistryCase7 {
    mapping(address => bool) public isApproved;

    function approve(address target) external {
        isApproved[target] = true;
    }
}

contract VictimCase7 {
    address public registry;
    address public owner;

    constructor(address _registry) {
        registry = _registry;
        owner = msg.sender;
    }

    function doAction() public {
        require(RegistryCase7(registry).isApproved(msg.sender), "Not approved");
        // critical function
    }
}

// Attacker deploys their own Registry with false approval logic

/* -------------------- Case 8: Selfdestruct Resets Access Control -------------------- */
contract Case8 {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function destroyAndRedeploy() public {
        require(msg.sender == owner);
        selfdestruct(payable(owner));
    }
}

// Attacker creates contract at same address using CREATE2 and becomes new owner

/* -------------------- Case 9: Storage Collision in Inherited Contracts -------------------- */
contract ParentCase9 {
    address public owner = msg.sender;
}

contract ChildCase9 is ParentCase9 {
    // same storage slot reused accidentally
    uint public version; // slot 0 collides with owner
    function updateVersion() public {
        version = 1337; // overwrites owner slot in base contract
    }

    function onlyOwner() public view {
        require(msg.sender == owner, "Not owner");
    }
}

/* -------------------- Case 10: Modifier Logic Error -------------------- */
contract Case10 {
    address public admin = msg.sender;

    modifier onlyAdmin() {
        _;
        require(msg.sender == admin, "Not admin"); // check happens after function!
    }

    function setData() public onlyAdmin {
        // attacker function runs first, then revert occurs → logic already executed!
    }
}
