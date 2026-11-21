# DeFi Security Audit Case Study: Flash Loan + Spot-Price Oracle Manipulation

**Author:** MOJTABITS — Web3 Security Researcher & Malware Analyst  
**Severity:** Critical (Total Loss of Protocol Liquidity)  
**Category:** Economic / DeFi Logic Exploit (Price Oracle Manipulation)  
**Tooling:** Foundry (`forge v1.10.0`, `solc 0.8.24`)  

---

## 1. Executive Summary
This case study demonstrates and mitigates one of the most destructive economic vulnerabilities in DeFi: **Single-Transaction Spot-Price Oracle Manipulation** via an uncollateralized **Flash Loan** (the root cause behind real-world exploits such as Harvest Finance, Mango Markets, and Cream Finance).

When a lending protocol computes collateral value directly from an AMM's instantaneous reserve ratio (`reserveUSD / reserveGOV`), an attacker with **zero upfront stablecoin capital** can borrow flash liquidity, temporarily skew the AMM pool ratio, inflate their collateral valuation by **36x**, drain **100% of the lending pool (\$200,000)**, restore the pool, and repay the flash loan in a **single atomic transaction**.

---

## 2. Vulnerability Root Cause (`VulnerableLending.sol`)
```solidity
function borrow(uint256 amountUSD) external {
    // CRITICAL BUG: Trusts instantaneous AMM spot price manipulable within 1 block
    uint256 govPriceUSD = amm.getSpotPrice();
    uint256 collateralValueUSD = (collateralGOV[msg.sender] * govPriceUSD) / 1e18;
    uint256 maxBorrow = (collateralValueUSD * LTV_BPS) / 10000;
    require(debtUSD[msg.sender] + amountUSD <= maxBorrow, "undercollateralized");
    ...
}
```
Because `SimpleAMM.getSpotPrice()` returns `(reserveUSD * 1e18) / reserveGOV` using constant-product math (`x * y = k`), injecting `500,000 USD` into a `100,000 USD / 100,000 GOV` pool changes reserves to `600,000 USD / 16,666.66 GOV`, spiking the reported spot price from **`$1.00`** to **`$36.00`** (`6² = 36x`).

---

## 3. Atomic Exploit Flow (1 Single Transaction)
1. **Initial State:** AMM holds `100k USD / 100k GOV` (`$1/GOV`). Victim Lending Pool holds `200,000 USD`. Attacker holds `0 USD` and `10,000 GOV` (fair borrow limit at 80% LTV = `$8,000`).
2. **Flash Loan:** Attacker borrows **`500,000 USD`** with **0 collateral** from `FlashLoanProvider`.
3. **Price Pump:** Attacker swaps `500,000 USD -> 83,333 GOV` in `SimpleAMM`. Spot price jumps **`$1 -> $36`**.
4. **Over-Borrow & Drain:** Attacker deposits `10,000 GOV`. Protocol values it at **`$360,000`** (80% LTV = `$288,000`) and approves borrowing the entire **`$200,000 USD`** pool.
5. **Unwind & Repay:** Attacker swaps `83,333 GOV -> 500,000 USD` back in the AMM and repays the Flash Loan.
6. **Result:** Victim Lending Pool balance = **`$0`**. Attacker net profit = **`$200,000 USD`** (minus `$10,000` collateral left behind = **`+$190,000` net economic gain**).

---

## 4. Remediation (`SecureLending.sol`)
Replace instantaneous AMM spot prices with a **manipulation-resistant oracle**:
* **Chainlink Price Feeds** (with staleness & sequencer uptime checks), or
* **Uniswap V3 TWAP (Time-Weighted Average Price)** over a 30+ minute window, combined with per-block borrow caps and circuit breakers.

---

## 5. Verification (`forge test -vv`)
```text
Ran 2 tests for test/FlashLoanOracleExploit.t.sol:FlashLoanOracleExploitTest
[PASS] test_Exploit_DrainsVulnerableLendingViaFlashLoan() (gas: 938296)
[PASS] test_Fix_SecureLendingBlocksSameAttack() (gas: 388620)
Suite result: ok. 2 passed; 0 failed; 0 skipped
```
