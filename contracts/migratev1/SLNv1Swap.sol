// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../SLNToken.sol";
import "./SLNv1Snap.sol";

contract SLNv1Swap {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public start;
    uint256 public ending;
    SLNv1Snap public constant snap = SLNv1Snap(0xFb31Abeb999a21Bf3df024b676196C6c7b17bc4f);
    IERC20 public constant slnV1Token = IERC20(0xDfcb9Bc15238bCaE69aa406846CB93d4CC9D4eBc);
    SLNToken public slnV2Token;

    mapping (address => uint256) public swapAmount;
    uint256 public totalAmount;
    uint256 public totalAccounts;

    constructor (
        SLNToken _slnV2Token,
        uint256 _start,
        uint256 _ending
    ) public {
        slnV2Token = _slnV2Token;
        start = _start;
        ending = _ending;
    }

    function allowance(address _account) public view returns (uint256 value) {
        value = snap.holders(_account).sub(swapAmount[_account]);
    }

    function swap(uint256 _amount) external returns (uint256 value) {
        require(block.number > start && block.number < ending, 'not in swap time');
        require(!isContract(msg.sender), 'not call from contract');

        uint256 max_value = allowance(msg.sender);
        require(_amount <= max_value, 'not more allowance');
        swapAmount[msg.sender] = swapAmount[msg.sender].add(_amount);

        if(swapAmount[msg.sender] == 0) {
            totalAccounts = totalAccounts.add(1);
        }

        slnV1Token.safeTransferFrom(msg.sender, address(this), _amount);
        slnV2Token.mint(msg.sender, _amount);
        value = _amount;
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}