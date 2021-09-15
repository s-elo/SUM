pragma solidity ^0.6;

// Based on :
// * https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Ownable.sol
// * https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Secondary.sol

contract Ownable {
    address public owner;

    constructor() public {
        // the first one who deployed this contarct will be the owner
        owner = msg.sender;
    }

    // when we call a function of the contract
    // only the owner can call
    modifier onlyOwner() {
        require(msg.sender == owner, "Sender is not the owner.");
        _;
    }

    // change the ower
    // still only the current owner can call
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be 0x0.");
        owner = newOwner;
    }
}
