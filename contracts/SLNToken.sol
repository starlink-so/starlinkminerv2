// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SLNToken is ERC20, Ownable {

    constructor (
            uint256 _totalSupply,
            address _premint,
            address _investor
        ) public ERC20('SLN-Token V2', 'SLNV2') {

        capmax =  _totalSupply;   
        _mint(_premint, _totalSupply*1/10000);        // 1%% for pool premint
        _mint(_investor, _totalSupply*300/10000);     // 300%% for foundation to vc investor, release weekly
    }

    address public starpools;
    address public slnv1swap;
    uint256 public slnv1endblock;

    uint256 public capmax;

    function setpool(address _pool) external onlyOwner {
        require(starpools == address(0), 'only init once');
        starpools = _pool;
    }

    function setv1swap(address _v1swap) external onlyOwner {
        require(slnv1swap == address(0), 'only init once');
        slnv1swap = _v1swap;
    }

    function mint(address _to, uint256 _amount) public {
        require(msg.sender == starpools || msg.sender == slnv1swap, 'from pools or swap call');
        require(totalSupply().add(_amount) <= capmax, 'cap exceeded');
        _mint(_to, _amount);
    }

    // If the user transfers TH to contract, it will revert
    function pay() public payable {
        revert();
    }
}