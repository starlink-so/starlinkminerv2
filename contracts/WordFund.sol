
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StarPoolsV2} from "./StarPools.sol";
import {WordFundV2Asset} from "./WordFundAsset.sol";

pragma experimental ABIEncoderV2;

// Word Management Contract
contract WordFundV2 is ERC721, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct worddata {
        address owner;              // The leader in the bidding
        uint256 amount;             // amount of collateral
        uint256 lastBiddingTime;    // last bidding time, bid ending in 24h, locked in 15d
        string word;                
        string pic;
        string ext;
        uint256 rewardDebt;
        uint256 rewardRemain;
    }

    uint256 totalAmount;
    uint256 accRewardPerShare;

    worddata[] public words;  // Word Data List
    
    uint256 public biddingPeriod = (1 hours);
    uint256 public lockingPeriod = (15 days) + (1 hours);

    uint256 public bidingFee = 10e18;
    address public feeGather;

    StarPoolsV2 public poolAddress;
    WordFundV2Asset public lpToken;
    IERC20 public colToken;
    uint256 public poolId;
    uint256 public reservePrice;

    event AddWord(address indexed account, uint256 wordid, string word);
    event SetWordData(address indexed account, uint256 wordid, string pic, string ext);
    event Bidding(address indexed account, uint256 indexed wordid, uint256 value);
    event Harvest(address indexed account, uint256 indexed wordid, uint256 holdtime);
    event Release(address indexed account, uint256 indexed wordid, uint256 value, uint256 holdtime);
    event Claim(address indexed account, uint256 indexed wordid, uint256 value);

    // Word Data
    constructor(address _collateral) public ERC721('GOOG-Token', 'GOOG') {
        colToken = IERC20(_collateral);
        lpToken = new WordFundV2Asset();
    }

    function setRelatedPool(address payable _poolAddress, uint256 _poolid) external onlyOwner {
        require(address(poolAddress) == address(0), 'init once only');

        IERC20 lpPoolToken;
        (lpPoolToken,,,,,) = StarPoolsV2(_poolAddress).poolInfo(_poolid);
        require(lpPoolToken == lpToken, 'not same lptoken');

        poolAddress = StarPoolsV2(_poolAddress);
        poolId = _poolid;

        lpToken.approve(address(poolAddress), uint256(-1));
    }

    function setReservePrice(uint256 _reservePrice) external onlyOwner {
        reservePrice = _reservePrice;
    }

    function setBiddingPeriod(uint256 _biddingPeriod) external onlyOwner {
        biddingPeriod = _biddingPeriod;
    }

    function setLockingPeriod(uint256 _lockingPeriod) external onlyOwner {
        lockingPeriod = _lockingPeriod;
    }

    function setBiddingFeeValue(uint256 _feeValue) external onlyOwner {
        bidingFee = _feeValue;
    }
    
    function setBiddingFeeGather(address _feeGather) external onlyOwner {
        feeGather = _feeGather;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setBaseURI(baseURI_);
    }

    function wordsLength() external view returns (uint256) {
        return words.length;
    }

    function addWords(string[] memory wordlist) external onlyOwner returns (uint256) {
        uint256 wordid = 0;
        for(uint256 i = 0; i < wordlist.length; i ++) {
            wordid = words.length;
            words.push(worddata(address(0),0,0,wordlist[i],"","",0,0));
            _mint(address(this), wordid);
            emit AddWord(msg.sender, wordid, wordlist[i]);
        }
        return words.length;
    }

    function setData(uint256 _wordid, string memory _pic, string memory _ext) external {
        // set word info data
        require(ownerOf(_wordid) == msg.sender, "only owner can set data");
        words[_wordid].pic = _pic;
        words[_wordid].ext = _ext;
        emit SetWordData(msg.sender, _wordid, _pic, _ext);
    }

    function bidding(uint256 _wordid, uint256 _value) external {
        require(address(poolAddress) != address(0), 'pool not inited');
        require(words[_wordid].lastBiddingTime == 0 ||
                now - words[_wordid].lastBiddingTime < biddingPeriod,
                "not in bidding period");
        require(_value > words[_wordid].amount.add(bidingFee) && _value >= reservePrice.add(bidingFee), 'value to low');

        if(words[_wordid].owner != address(0)) {
            // release previous biding, claimAndReleaseTo has owner call updatePool()
            claimAndReleaseTo(_wordid, words[_wordid].owner);
        }

        updatePool();

        // purchase from wallet
        colToken.safeTransferFrom(msg.sender, address(this), _value);

        if(feeGather != address(0)) {
            _value = _value.sub(bidingFee);
            colToken.safeTransfer(feeGather, bidingFee);
        }

        lpToken.mint(address(this), _value);
        poolAddress.deposit(poolId, _value);
        totalAmount = totalAmount.add(_value);

        emit Bidding(msg.sender, _wordid, _value);

        // define word ownership
        words[_wordid].owner = msg.sender;
        words[_wordid].amount = _value;
        words[_wordid].lastBiddingTime = now;
        words[_wordid].rewardDebt = totalRewards(_wordid);
        words[_wordid].rewardRemain = 0;
    }

    function harvest(uint256 _wordid) external {
        require(now - words[_wordid].lastBiddingTime > biddingPeriod, 'not in bidding ending');
        require(words[_wordid].owner == msg.sender, "not bidding winner");
        require(ownerOf(_wordid) == address(this), "held by someone");
        
        emit Harvest(msg.sender, _wordid, now - words[_wordid].lastBiddingTime);

        _transfer(address(this), msg.sender, _wordid);
    }

    function release(uint256 _wordid) external {
        require(now - words[_wordid].lastBiddingTime > lockingPeriod,
                "in locking period");

        address owner = ownerOf(_wordid);

        if(owner == msg.sender) {
            _transfer(msg.sender, address(this), _wordid);
        }
        else{
            require(owner == address(this) && words[_wordid].owner == msg.sender, 'ntf not yours');
        }

        claimAndReleaseTo(_wordid, msg.sender);
    }

    function claimAndReleaseTo(uint256 _wordid, address _to) internal {
        updatePool();
        claimTo(_wordid, _to);
        uint256 amount = words[_wordid].amount;
        poolAddress.withdraw(poolId, amount);
        lpToken.burn(address(this), amount);
        // require(words[_wordid].rewardRemain == 0, 'must release after claim');
        release2new(_wordid, _to);
    }

    function emergencyRelease(uint256 _wordid) external {
        address owner = ownerOf(_wordid);
        require( owner == msg.sender || 
                ( owner == address(this) && words[_wordid].owner == msg.sender),
                'ntf not yours');
        require(now - words[_wordid].lastBiddingTime > lockingPeriod,
                "in locking period");
        if(owner == msg.sender) {
            _transfer(msg.sender, address(this), _wordid);
        }
        release2new(_wordid, msg.sender);
    }

    function release2new(uint256 _wordid, address _to) internal {
        uint256 amount = words[_wordid].amount;

        emit Release(_to, _wordid, amount, now - words[_wordid].lastBiddingTime);

        words[_wordid].owner = address(0);
        words[_wordid].amount = 0;
        words[_wordid].lastBiddingTime = 0;
        words[_wordid].rewardDebt = 0;
        words[_wordid].rewardRemain = 0;
        colToken.safeTransfer(_to, amount);
        totalAmount = totalAmount.sub(amount);
    }

    function updatePool() public {
        if (totalAmount == 0) {
            return;
        }
        uint256 poolReward = poolAddress.claimAll(poolId);
        accRewardPerShare = accRewardPerShare.add(poolReward.mul(1e18).div(totalAmount));
    }

    // View function to see pending SLNTokens on frontend.
    function pendingRewards(uint256 _wordid) public view returns (uint256 value) {
        value = totalRewards(_wordid).add(words[_wordid].rewardRemain).sub(words[_wordid].rewardDebt);
    }

    function totalRewards(uint256 _wordid) internal view returns (uint256 value) {
        uint256 accRewardPerShareNew = accRewardPerShare;
        uint256 poolReward = poolAddress.pendingRewards(poolId, address(this));
        if(poolReward > 0){
            accRewardPerShareNew = accRewardPerShareNew.add(poolReward.mul(1e18).div(totalAmount));
        }
        value = words[_wordid].amount.mul(accRewardPerShareNew).div(1e18);
    }

    function claim(uint256 _wordid) external {
        address owner = ownerOf(_wordid);
        require( owner == msg.sender || 
                ( owner == address(this) && words[_wordid].owner == msg.sender),
                'ntf not yours');

        updatePool();

        claimTo(_wordid, msg.sender);
    }

    function claimTo(uint256 _wordid, address _to) internal {
        uint256 rewardsValue = pendingRewards(_wordid);
        if(rewardsValue == 0) {
            return ;
        }

        words[_wordid].rewardRemain = 0;
        words[_wordid].rewardDebt = totalRewards(_wordid);

        safeSlnTransfer(_to, rewardsValue);

        emit Claim(_to, _wordid, rewardsValue);
    }

    function safeSlnTransfer(address _to, uint256 _amount) internal {

        ERC20 slnToken = ERC20(address(poolAddress.slnToken()));
        uint256 slnBalance = slnToken.balanceOf(address(this));

        if (_amount > slnBalance) {
            slnToken.transfer(_to, slnBalance);
        } else {
            slnToken.transfer(_to, _amount);
        }
    }

    // If the user transfers TH to contract, it will revert
    receive() external payable {
        revert();
    }
}
