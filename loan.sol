// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract Loan {
    using SafeMath for uint256;
    address payable owner;

    //user struct
    struct User {
        string name;
        uint256 currently_owed;
        uint256 total_borrowed;
        uint8 tier;
        uint256 timestamp;
    }
    //tier limits
    uint256[3] public tierLimits = [5 ether, 10 ether, 15 ether];

    //mapping to track user existence
    mapping(address => bool) private userExists;

    //mapping to store user
    mapping(address => User) Accounts;

    modifier userExist() {
        require(userExists[msg.sender], "User does not exist");
        _;
    }

    modifier userDoesNotExist() {
        require(!userExists[msg.sender], "User already exists");
        _;
    }

    //events
    event UserCreated(address indexed userAddress, User user);
    event UserDeleted(address indexed userAddress, User user);
    event MoneyBorrowed(address indexed userAddress, uint256 amount);
    event MoneyPaidBack(address indexed userAddress, uint256 amount);

    //assigning the owner of this contract on creation
    constructor() payable {
        owner = payable(msg.sender);
    }

    //create a new user
    function createUser(string memory name) public userDoesNotExist {
        //create a new user
        User memory newUser = User({
            name: name,
            currently_owed: 0,
            total_borrowed: 0,
            tier: 1,
            timestamp: 0
        });
        // add to map
        Accounts[msg.sender] = newUser;
        //toggle user exist
        userExists[msg.sender] = true;
        //emit  an event with all the details
        emit UserCreated(msg.sender, newUser);
    }

    function getUser() public view userExist returns (User memory) {
        //returns user
        return Accounts[msg.sender];
    }

    function deleteAccount() public userExist {
        //fetch user
        User storage user = Accounts[msg.sender];
        require(user.currently_owed == 0, "Please payback your previous loan");
        //delete from mapping
        delete Accounts[msg.sender];
        // remove from exists
        userExists[msg.sender] = false;
        //emit  an event with all the details
        emit UserDeleted(msg.sender, user);
    }

    function calculateInterest(uint256 amount) public pure returns (uint256) {
        return amount.mul(20).div(100); //  20% interest
    }

    function borrowMoney(uint256 amount) public userExist {
        require(amount > 0, "Cannot borrow zero or negative amounts");
        User storage user = Accounts[msg.sender];
        require(user.currently_owed == 0, "Please payback your previous loan");

        // Check the tier for the loan amount to limit then from excessive borrowing
        uint8 currentTier = user.tier;
        require(
            amount <= tierLimits[currentTier - 1],
            "Exceeded maximum borrowing limit for your tier"
        );

        // Transfer money from the contract to the user
        (bool sent, ) = payable(address(this)).call{value: amount}("");
        require(sent, "Failed to send Loan");

        // Update user's balance
        user.currently_owed = amount;
        user.timestamp = block.timestamp + 24 hours;

        emit MoneyBorrowed(msg.sender, amount);
    }

    function PaybackMoney(uint256 amount) public userExist {
        User storage user = Accounts[msg.sender];
        uint256 amountWithInterest = user.currently_owed.add(
            calculateInterest(user.currently_owed)
        );

        //check for currently owed and interest
        require(user.currently_owed > 0, "You are not owing");
        require(amount >= amountWithInterest, "Please add the 2% interest");
        require(
            block.timestamp >= user.timestamp,
            "It's not yet your payback date"
        );

        // Transfer money from the user to the contract
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to payback loan");

        // Calculate new tier before updating balances
        uint8 newTier = user.tier;
        if (user.total_borrowed.add(user.currently_owed) > 50) {
            newTier = 3;
        } else if (user.total_borrowed.add(user.currently_owed) > 30) {
            newTier = 2;
        }

        // Update user's balance and tier in one storage operation
        user.total_borrowed = user.total_borrowed.add(user.currently_owed);
        user.currently_owed = 0;
        user.tier = newTier;
        user.timestamp = 0;

        // Emit event
        emit MoneyPaidBack(msg.sender, amount);
    }

    fallback() external payable {}

    // Receive function
    receive() external payable {}
}
