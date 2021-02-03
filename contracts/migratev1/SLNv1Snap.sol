// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SLNv1Snap {

    uint256 public start;
    uint256 public ending;

    mapping (address => uint256) public holders;
    address public constant SLNToken = address(0xDfcb9Bc15238bCaE69aa406846CB93d4CC9D4eBc);

    constructor (
        uint256 _start,
        uint256 _ending
    ) public {
        start = _start;
        ending = _ending;
    }

    function snapshot(address[] memory _accounts) external {
        require(block.number > start && block.number < ending, 'not in snapshot time');
        for(uint256 i = 0; i < _accounts.length; i ++) {
            holders[_accounts[i]] = ERC20(SLNToken).balanceOf(_accounts[i]);
        }
    }

    function balanceOf(address accounts) external view returns(uint256) {
        return holders[accounts];
    }
}