# Web3 & DeFi Security Research — Audits & Foundry PoCs

**Author:** MOJTABITS — Independent Web3 Security Researcher & Malware Analyst  
**Focus:** DeFi Economic Exploits, Smart Contract Auditing (Foundry / Slither), Flash Loan & Oracle Manipulation PoCs, and Reentrancy/Access Control Remediation.

---

## Published Case Studies & Foundry PoCs

| # | Vulnerability / Attack Vector | Severity | Tooling | Verified Result | Report & Code |
| :-: | :--- | :---: | :--- | :--- | :--- |
| **01** | **Flash Loan + AMM Spot-Price Oracle Manipulation** | Critical | Foundry (`forge v1.10.0`, `solc 0.8.24`) | 36x spot price pump (`$1 -> $36`), `$200k` pool drained in 1 atomic tx + TWAP fix verified (`2/2 PASS`) | [Audit Report & PoC](./01_FlashLoan_Oracle_Manipulation/) |

---

## Quick Verification (Foundry)
```bash
cd 01_FlashLoan_Oracle_Manipulation
forge test -vv
```

## Disclaimer
All smart contracts, exploit Proofs of Concept (PoCs), and remediation tests in this repository are strictly for **local educational simulation, security auditing, and defensive DeFi research**.
