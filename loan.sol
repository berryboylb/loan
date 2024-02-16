// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Loan {
    using SafeMath for uint256;
    address payable owner;

    //history struct
    struct History {
        uint256 amount;
        uint256 timestamp;
    }
    //user struct
    struct User {
        string name;
        uint256 currently_owed;
        uint256 total_borrowed;
        uint8 tier;
        History[] history;
    }

    //mapping to store user
    mapping(address => User) Accounts;
    //mapping to track user existence
    mapping(address => bool) private userExists;
    //tier limits
    uint256[3] public tierLimits = [1 ether, 2 ether, 3 ether];

    //this checks if user is created
    modifier userExists() {
        require(userExists[msg.sender], "User does not exist");
        _;
    }
    //this checks if user is not created
    modifier userDoesNotExist() {
        require(!userExists[msg.sender], "User already exists");
        _;
    }

    //events
    event UserCreated(address indexed userAddress, User user);
    event UserDeleted(address indexed userAddress, User user);
    event MoneyBorrowed(address indexed userAddress, uint256 amount);
    event MoneyPaidBack(address indexed userAddress, uint256 amount);

    //assign ing the owner of this contract on creation
    constructor() {
        owner = payable(msg.sender);
    }

    //create a new user
    function createUser(string name) public userDoesNotExist {
        //create a new user
        User memory newUser = User({
            name: name,
            currently_owed: 0,
            total_borrowed: 0,
            tier: 1,
            history: new History[](0)
        });
        // add to map
        Accounts[msg.sender] = newUser;
        //toggle user exist
        userExists[msg.sender] = true;
        //emit  an event with all the details
        emit UserCreated(msg.sender, newUser);
    }

    function getUser() public view userExists returns (User memory) {
        //returns user
        return Accounts[msg.sender];
    }

    function deleteAccount() public userExists {
        //fetch user
        User storage user = Accounts[msg.sender];
        //delete from mapping
        delete Accounts[msg.sender];
        // remove from exists
        userExists[msg.sender] = false;
        //emit  an event with all the details
        emit UserDeleted(msg.sender, user);
    }

    function borrowMoney(uint256 amount) public userExists {
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
        (bool sent, bytes memory data) = payable(address(this)).call{
            value: amount
        }("");
        require(sent, "Failed to send Load");

        // Update user's balance
        user.currently_owed = amount;

        emit MoneyBorrowed(msg.sender, amount);
    }

    function calculateInterest(uint256 amount) public pure returns (uint256) {
        return amount.mul(20).div(100); //  20% interest
    }

    function PaybackMoney(uint256 amount) public userExists {
        User storage user = Accounts[msg.sender];
        uint256 amountWithInterest = user.currently_owed.add(
            calculateInterest(user.currently_owed)
        );

        //check for currently owed and interest
        require(user.currently_owed > 0, "You are not owing");
        require(amount >= amountWithInterest, "Please add the 2% interest");

        // Transfer money from the user to the contract
        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        require(sent, "Failed to payback loan");

        // Calculate new tier before updating balances
        uint8 newTier = user.tier;
        if (user.total_borrowed.add(user.currently_owed) > 20) {
            newTier = 3;
        } else if (user.total_borrowed.add(user.currently_owed) > 10) {
            newTier = 2;
        }

        // Update user's balance and tier in one storage operation
        user.total_borrowed = user.total_borrowed.add(user.currently_owed);
        user.currently_owed = 0;
        user.tier = newTier;

        // Add to history
        History memory newEntry = History({
            amount: amount,
            timestamp: block.timestamp
        });
        user.history.push(newEntry);

        // Emit event
        emit MoneyPaidBack(msg.sender, amount);
    }
}
