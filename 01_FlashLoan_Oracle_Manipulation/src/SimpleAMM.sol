// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SimpleERC20.sol";

/// @title Constant-Product AMM (x * y = k) — like Uniswap V2
/// @notice Exposes a spot price directly from reserves (unsafe to use as a lending oracle!)
contract SimpleAMM {
    SimpleERC20 public immutable usd;
    SimpleERC20 public immutable gov;

    uint256 public reserveUSD;
    uint256 public reserveGOV;

    constructor(address _usd, address _gov) {
        usd = SimpleERC20(_usd);
        gov = SimpleERC20(_gov);
    }

    function addLiquidity(uint256 amountUSD, uint256 amountGOV) external {
        usd.transferFrom(msg.sender, address(this), amountUSD);
        gov.transferFrom(msg.sender, address(this), amountGOV);
        reserveUSD += amountUSD;
        reserveGOV += amountGOV;
    }

    /// @notice Swap USD -> GOV using x * y = k (0% fee for clean educational math)
    function swapUSDForGOV(uint256 amountInUSD) external returns (uint256 amountOutGOV) {
        require(amountInUSD > 0, "zero input");
        usd.transferFrom(msg.sender, address(this), amountInUSD);

        // Constant product: (reserveUSD + amountInUSD) * (reserveGOV - amountOutGOV) = reserveUSD * reserveGOV
        uint256 newReserveUSD = reserveUSD + amountInUSD;
        uint256 newReserveGOV = (reserveUSD * reserveGOV) / newReserveUSD;
        amountOutGOV = reserveGOV - newReserveGOV;

        reserveUSD = newReserveUSD;
        reserveGOV = newReserveGOV;
        gov.transfer(msg.sender, amountOutGOV);
    }

    /// @notice Swap GOV -> USD using x * y = k
    function swapGOVForUSD(uint256 amountInGOV) external returns (uint256 amountOutUSD) {
        require(amountInGOV > 0, "zero input");
        gov.transferFrom(msg.sender, address(this), amountInGOV);

        uint256 newReserveGOV = reserveGOV + amountInGOV;
        uint256 newReserveUSD = (reserveUSD * reserveGOV) / newReserveGOV;
        amountOutUSD = reserveUSD - newReserveUSD;

        reserveGOV = newReserveGOV;
        reserveUSD = newReserveUSD;
        usd.transfer(msg.sender, amountOutUSD);
    }

    /// @notice VULNERABLE ORACLE: Spot price of 1 GOV in USD (scaled by 1e18)
    function getSpotPrice() external view returns (uint256) {
        return (reserveUSD * 1e18) / reserveGOV;
    }
}
