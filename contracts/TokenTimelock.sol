// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 */
contract TokenTimelock {
    using SafeERC20 for IERC20;

    address public beneficiary;

    uint256 public totalvalue;

    uint256 public begintime;

    constructor (uint256 totalvalue_, address beneficiary_) public {
        beneficiary = beneficiary_;
        totalvalue = totalvalue_;
        begintime = block.timestamp;
    }

    function canRelease(IERC20 token_) public view returns (uint256) {
        uint256 weekscount = (block.timestamp - begintime) / (1 weeks);
        uint256 remains = totalvalue * ( 25 - weekscount ) / (26);
        uint256 balance = token_.balanceOf(address(this));
        return balance-remains;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release(IERC20 token_) public virtual {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= begintime, "TokenTimelock: current time is before release time");
        uint256 releaseValue = canRelease(token_);
        require(releaseValue > 0, "TokenTimelock: no tokens to release");
        token_.safeTransfer(beneficiary, releaseValue);
    }
}