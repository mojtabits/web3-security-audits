// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SimpleERC20.sol";
import "./SimpleAMM.sol";

interface IFlashLoanReceiver {
    function onFlashLoan(uint256 amount) external;
}

/// @title Uncollateralized Flash Loan Provider (must be repaid in the same transaction)
contract FlashLoanProvider {
    SimpleERC20 public immutable usd;

    constructor(address _usd) {
        usd = SimpleERC20(_usd);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = usd.balanceOf(address(this));
        require(balanceBefore >= amount, "insufficient flash liquidity");

        usd.transfer(msg.sender, amount);
        IFlashLoanReceiver(msg.sender).onFlashLoan(amount);

        require(usd.balanceOf(address(this)) >= balanceBefore, "flash loan not repaid");
    }
}

/// @title VULNERABLE DeFi Lending Protocol (uses AMM Spot Price as Oracle)
contract VulnerableLending {
    SimpleERC20 public immutable usd;
    SimpleERC20 public immutable gov;
    SimpleAMM public immutable amm;

    mapping(address => uint256) public collateralGOV;
    mapping(address => uint256) public debtUSD;

    // 80% Loan-to-Value (LTV)
    uint256 public constant LTV_BPS = 8000;

    constructor(address _usd, address _gov, address _amm) {
        usd = SimpleERC20(_usd);
        gov = SimpleERC20(_gov);
        amm = SimpleAMM(_amm);
    }

    function depositCollateral(uint256 amountGOV) external {
        gov.transferFrom(msg.sender, address(this), amountGOV);
        collateralGOV[msg.sender] += amountGOV;
    }

    function borrow(uint256 amountUSD) external {
        // BUG: Trusts manipulable AMM spot price within a single transaction!
        uint256 govPriceUSD = amm.getSpotPrice();
        uint256 collateralValueUSD = (collateralGOV[msg.sender] * govPriceUSD) / 1e18;
        uint256 maxBorrow = (collateralValueUSD * LTV_BPS) / 10000;

        require(debtUSD[msg.sender] + amountUSD <= maxBorrow, "undercollateralized");
        debtUSD[msg.sender] += amountUSD;
        usd.transfer(msg.sender, amountUSD);
    }
}

/// @title SECURE DeFi Lending Protocol (uses Manipulation-Resistant External / TWAP Oracle)
contract SecureLending {
    SimpleERC20 public immutable usd;
    SimpleERC20 public immutable gov;
    uint256 public twapPriceUSD; // Simulates Chainlink / Uniswap V3 TWAP oracle

    mapping(address => uint256) public collateralGOV;
    mapping(address => uint256) public debtUSD;
    uint256 public constant LTV_BPS = 8000;

    constructor(address _usd, address _gov, uint256 _initialTwapPrice) {
        usd = SimpleERC20(_usd);
        gov = SimpleERC20(_gov);
        twapPriceUSD = _initialTwapPrice;
    }

    function depositCollateral(uint256 amountGOV) external {
        gov.transferFrom(msg.sender, address(this), amountGOV);
        collateralGOV[msg.sender] += amountGOV;
    }

    function borrow(uint256 amountUSD) external {
        // FIX: Uses time-weighted / external oracle immune to single-block flash loan swaps
        uint256 collateralValueUSD = (collateralGOV[msg.sender] * twapPriceUSD) / 1e18;
        uint256 maxBorrow = (collateralValueUSD * LTV_BPS) / 10000;

        require(debtUSD[msg.sender] + amountUSD <= maxBorrow, "undercollateralized");
        debtUSD[msg.sender] += amountUSD;
        usd.transfer(msg.sender, amountUSD);
    }
}
