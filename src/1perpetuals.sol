//SPDX-License-Identifier:MIT
pragma solidity ^0.8.8;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
contract Perpetuals is ReentrancyGuard{

    AggregatorV3Interface internal pricefeed;
    IERC20 public token;

    event LiquidityDeposited(address indexed provider,uint256 amount);
    event LiquidityWithdrawn (address indexed provider,uint256 amount);
    event PositionOpened (address indexed trader,uint256 size, uint256 collateral);
    event SizeIncreased(address indexed trader,uint256 size);
    event CollateralIncreased(address indexed trader, uint256 collateral);

    uint256 public totalLiquidity;
    uint256 public utilizedLiquidity;
    uint256 public liquidityUtilizationLimit = 75;

    struct Position{
        uint256 size;
        uint256 collateral;
        bool isOpen;
    }

    mapping (address => uint256) public liquidityProviders;
    mapping(address => Position) public positions;

    constructor(address _pricefeed,address _token)
    {
        pricefeed = AggregatorV3Interface(_pricefeed);
        token = IERC20(_token);
    }


    modifier WithinUtilizationLimit(uint256 amount) {
        require((utilizedLiquidity + amount) <= (totalLiquidity*liquidityUtilizationLimit)/100,"Utilization limit exceeded");
        _;
    }

    modifier CanWithdraw(uint256 amount){
        require (liquidityProviders[msg.sender] >= amount,"Insufficient liquidity");
        require ((totalLiquidity - utilizedLiquidity) >= amount,"Reserved Liquidity cannot be used");
        _;
    }

    function getLatestPrice() public view returns(int){
        (,int price, , , ) = pricefeed.latestRoundData();
        return price;
    }



    function openPosition(uint256 size,uint256 collateral) external WithinUtilizationLimit(size){
        require (size > 0,"Size must be greater than zero");
        require (collateral > 0,"Collateral must be greater than zero");

        positions[msg.sender] = Position({
            size: size,
            collateral :collateral,
            isOpen : true
        });
        utilizedLiquidity += size;

        emit PositionOpened(msg.sender,size,collateral);
    }

    function increaseSize(uint256 size) external WithinUtilizationLimit(size){
        require(size > 0," Size must be greater than zero");
        Position storage position = positions[msg.sender];
        require (position.isOpen,"Position closed");

        position.size += size;
        utilizedLiquidity += size;

        emit SizeIncreased(msg.sender,size);
    }

    function increaseCollateral (uint256 collateral) external{
        require(collateral > 0, "collateral must be greater than zero");
        Position storage position = positions[msg.sender];
        require(position.isOpen,"PositionClosed");

        position.collateral += collateral;

        emit CollateralIncreased(msg.sender,collateral);
    }

    function depositLiquidity(uint256 amount) external nonReentrant{
        require (amount > 0,"Amount must be greater than zero");
        token.transferFrom(msg.sender,address(this),amount);

        liquidityProviders[msg.sender] += amount;
        totalLiquidity += amount;

        emit LiquidityDeposited(msg.sender, amount);
    }

    function withdrawLiquidity(uint256 amount) external nonReentrant CanWithdraw(amount){
        require(amount > 0, "Amount must be greater than zero");
        token.transfer(msg.sender,amount);

        liquidityProviders[msg.sender] -= amount;
        totalLiquidity -= amount;

        emit LiquidityWithdrawn(msg.sender,amount);

    }
}