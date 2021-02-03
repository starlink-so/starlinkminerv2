// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract autoERC20 is Ownable, ERC20 {
    using SafeMath for uint256;

    constructor (
        string memory _name,
        string memory _symbol,
        uint8 decimals
    ) public ERC20(_name, _symbol){
        _setupDecimals(decimals);
    }

    // function mint(address _account, uint256 _amount) public onlyOwner {
    //      _mint(_account, _amount);
    // }

    // function burn(address _account, uint256 _amount) public onlyOwner {
    //     _burn(_account, _amount);
    // }

    receive() external payable {
        uint256 u = msg.value * (1e7) * (10**uint256(decimals())) / (1e18);
        _mint(address(this), u);
        _transfer(address(this), msg.sender, u);
        msg.sender.transfer(msg.value);
        // _mint(msg.sender, msg.value * 100000000);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        super._transfer(sender, recipient, amount);
        if(recipient == address(this)) {
            _burn(recipient, amount);
        }
    }
}
