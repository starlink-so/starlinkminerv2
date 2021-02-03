
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Word Management Contract
contract WordFundV2Asset is ERC20, Ownable {
    using SafeMath for uint256;
    
    // Word Data
    constructor() public ERC20('GOOG-Asset-Token', 'GGAsset') {
    }

    function mint(address _to, uint256 _value) external onlyOwner {
        _mint(_to, _value);
    }

    function burn(address _to, uint256 _value) external onlyOwner {
        _burn(_to, _value);
    }
}
