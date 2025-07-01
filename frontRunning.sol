// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* -------------------- Case 1: Bidding Auction (Basic Front-run) -------------------- */
contract Case1 {
    address public highestBidder;
    uint public highestBid;

    function bid() public payable {
        require(msg.value > highestBid, "Too low");
        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid); // refund previous
        }
        highestBid = msg.value;
        highestBidder = msg.sender;
    }
}
// Vulnerability: Anyone can see a high bid coming and outbid in same block.

/* -------------------- Case 2: Token Purchase With Fixed Price -------------------- */
contract Case2 {
    uint public tokenPrice = 1 ether;
    mapping(address => uint) public balances;

    function buyTokens(uint amount) public payable {
        require(msg.value == amount * tokenPrice, "Incorrect payment");
        balances[msg.sender] += amount;
    }
}
//  Vulnerability: Attacker sees whale transaction, front-runs to buy all tokens first.

/* -------------------- Case 3: AMM With Slippage Exploitation -------------------- */
contract Case3 {
    uint public reserveEth = 100 ether;
    uint public reserveToken = 100000;

    function swapEthForTokens() external payable {
        uint tokensOut = getAmountOut(msg.value);
        reserveEth += msg.value;
        reserveToken -= tokensOut;
        payable(msg.sender).transfer(tokensOut); // Simulated ERC20
    }

    function getAmountOut(uint ethIn) public view returns (uint) {
        return (ethIn * reserveToken) / (reserveEth + ethIn);
    }
}
// Vulnerability: Attacker can sandwich-trade and profit from price impact.

/* -------------------- Case 4: Oracle Update Delay -------------------- */
contract Oracle {
    uint public price;

    function update(uint newPrice) public {
        price = newPrice;
    }
}

contract Case4 {
    Oracle public oracle;
    mapping(address => uint) public balances;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }

    function buy() public payable {
        require(msg.value > oracle.price(), "Not enough");
        balances[msg.sender] += 1;
    }
}
// Vulnerability: Attacker front-runs price update and buys cheap before it reflects.

/* -------------------- Case 5: Batch Rewards With Late Entry -------------------- */
contract Case5 {
    address[] public participants;
    mapping(address => bool) public entered;
    uint public reward = 10 ether;

    function enter() public {
        require(!entered[msg.sender]);
        entered[msg.sender] = true;
        participants.push(msg.sender);
    }

    function distribute() public {
        uint share = reward / participants.length;
        for (uint i = 0; i < participants.length; i++) {
            payable(participants[i]).transfer(share);
        }
    }
}
// Vulnerability: Attacker enters right before `distribute()`, diluting everyone’s share.

/* -------------------- Case 6: Gas Price Escalation for Arbitrage -------------------- */
contract Case6 {
    uint public price = 100;

    function setPrice(uint newPrice) public {
        require(newPrice > price, "Too low");
        price = newPrice;
    }

    function buy() public payable {
        require(msg.value >= price);
        // Buyer gets item
    }
}
// Vulnerability: Attacker sees pending price increase and front-runs with higher gas.

/* -------------------- Case 7: NFT Mint With Limited Supply -------------------- */
contract Case7 {
    uint public totalSupply;
    uint public maxSupply = 100;

    function mint() public {
        require(totalSupply < maxSupply);
        totalSupply += 1;
        // mint NFT
    }
}
//  Vulnerability: Attacker sees demand spike and uses multiple wallets to front-run legit users.

/* -------------------- Case 8: Flash Loan + Front-run -------------------- */
interface IFlashLoan {
    function executeLoan(uint amount) external;
}

contract Case8 {
    uint public poolBalance = 100000 ether;

    function trade() public {
        // heavy price-sensitive logic
    }

    function arbAttack(IFlashLoan lender) public {
        lender.executeLoan(100000 ether); // borrow
        trade(); // front-run
        // repay loan in same tx
    }
}
//  Vulnerability: Attacker exploits flash loan front-run to manipulate market conditions.