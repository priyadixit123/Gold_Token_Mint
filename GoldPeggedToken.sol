// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IDex {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract GoldPeggedToken is ERC20, Ownable {
    AggregatorV3Interface internal goldPriceFeed;
    IERC20Metadata public usdcToken;
    address public dexRouter; // Address of DEX Router (e.g., Uniswap)
    uint256 public tokenPrice; // Price of one token in USD (18 decimals)
    uint256 public constant DECIMALS_MULTIPLIER = 1e10; // Adjust gold price to 18 decimals
    uint256 public feePercent = 5; // Fee in basis points (0.5%)
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // Reward rate in tokens/year

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewardDebt;

    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event FeeCollected(address indexed user, uint256 fee);

    constructor(address _priceFeed, address _usdcToken, address _dexRouter) ERC20("GoldPeggedToken", "GPT") {
        goldPriceFeed = AggregatorV3Interface(_priceFeed);
        usdcToken = IERC20Metadata(_usdcToken);
        dexRouter = _dexRouter;
        updateTokenPrice();
    }

    
      // Fetch the latest gold price from Chainlink oracle.
     
    function getLatestGoldPrice() public view returns (uint256) {
        (, int256 price, , ,) = goldPriceFeed.latestRoundData();
        require(price > 0, "Invalid gold price from oracle");
        return uint256(price) * DECIMALS_MULTIPLIER; // Convert to 18 decimals
    }

    
     // Update the token price based on the latest gold price.
     
    function updateTokenPrice() public {
        tokenPrice = getLatestGoldPrice();
    }

    
     // Stake tokens to earn rewards.
     // amount Amount of tokens to stake.
     
    function stake(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient token balance");
        _transfer(msg.sender, address(this), amount);

        uint256 rewards = calculateRewards(msg.sender);
        stakedBalance[msg.sender] += amount;
        rewardDebt[msg.sender] += rewards;
        totalStaked += amount;

        emit TokensStaked(msg.sender, amount);
    }

    
     // Unstake tokens and claim rewards.
     
    function unstake() external {
        uint256 stakedAmount = stakedBalance[msg.sender];
        require(stakedAmount > 0, "No staked tokens");

        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalPayout = stakedAmount + rewards;

        stakedBalance[msg.sender] = 0;
        rewardDebt[msg.sender] = 0;
        totalStaked -= stakedAmount;

        _transfer(address(this), msg.sender, totalPayout);

        emit TokensUnstaked(msg.sender, stakedAmount, rewards);
    }

    
     // Calculate rewards for a staker.
     //  user Address of the staker.
     
    function calculateRewards(address user) public view returns (uint256) {
        return (stakedBalance[user] * rewardRate) / 10000;
    }

    /*
       Mint tokens by paying in USDC.
       amount Amount of tokens to mint (18 decimals).
     */
    function mintWithUSDC(uint256 amount) external {
        uint256 requiredUSDC = (amount * tokenPrice) / (10 ** decimals());
        require(usdcToken.balanceOf(msg.sender) >= requiredUSDC, "Insufficient USDC balance");

        // Transfer USDC to the contract
        usdcToken.transferFrom(msg.sender, address(this), requiredUSDC);

        // Apply fee
        uint256 fee = (amount * feePercent) / 10000;
        uint256 netAmount = amount - fee;

        _mint(msg.sender, netAmount);

        emit FeeCollected(msg.sender, fee);
    }

    /*  Burn tokens to remove them from circulation.
       amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /*
         Swap USDC to GPT tokens using DEX.
       usdcAmount Amount of USDC to swap.
       minTokens Minimum GPT tokens to receive.
       path Path for the token swap (USDC -> GPT).
       deadline Transaction deadline.
     */
    function swapUSDCToToken(uint256 usdcAmount, uint256 minTokens, address[] calldata path, uint256 deadline) external {
        require(path[0] == address(usdcToken), "Invalid path");
        require(path[path.length - 1] == address(this), "Invalid path");

        usdcToken.transferFrom(msg.sender, address(this), usdcAmount);
        usdcToken.approve(dexRouter, usdcAmount);

        IDex(dexRouter).swapExactTokensForTokens(
            usdcAmount,
            minTokens,
            path,
            msg.sender,
            deadline
        );
    }

    /*
         Automated proof of reserve (mock function for demonstration).
         reserve The mock reserve value.
     */
    function getProofOfReserve() public view returns (uint256 reserve) {
        return address(this).balance;
    }

    
       //Owner can withdraw accumulated USDC.
     
    function withdrawUSDC(uint256 amount) external onlyOwner {
        require(amount <= usdcToken.balanceOf(address(this)), "Not enough USDC");
        usdcToken.transfer(owner(), amount);
    }

    
     // Set a new fee percentage (basis points).
     
    function setFeePercent(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Fee too high"); // Max 1%
        feePercent = newFeePercent;
    }

    receive() external payable {}
}
