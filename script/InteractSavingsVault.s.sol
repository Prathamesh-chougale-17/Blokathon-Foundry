// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISavingsVault} from "src/facets/utilityFacets/savingsVault/ISavingsVault.sol";

// InteractSavingsVault - Script to approve tokens and interact with SavingsVault on Arbitrum
// Usage:
//   1. Set environment variables:
//      export DIAMOND_ADDRESS=0x...
//      export PRIVATE_KEY=0x...
//
//   2. Approve tokens:
//      forge script script/InteractSavingsVault.s.sol:ApproveToken --rpc-url https://arb1.arbitrum.io/rpc --broadcast
//
//   3. Deposit:
//      forge script script/InteractSavingsVault.s.sol:DepositToVault --rpc-url https://arb1.arbitrum.io/rpc --broadcast

// Arbitrum token addresses
address constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
address constant USDT_ARBITRUM = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
address constant DAI_ARBITRUM = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

contract ApproveToken is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address token = vm.envOr("TOKEN_ADDRESS", USDC_ARBITRUM);
        uint256 amount = vm.envOr("APPROVE_AMOUNT", uint256(type(uint256).max)); // Max approval by default

        vm.startBroadcast();

        IERC20(token).approve(diamond, amount);
        console.log("Approved token:", token);
        console.log("Spender (Diamond):", diamond);
        console.log("Amount:", amount);

        // Check allowance
        uint256 allowance = IERC20(token).allowance(msg.sender, diamond);
        console.log("Current allowance:", allowance);

        vm.stopBroadcast();
    }
}

contract DepositToVault is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address token = vm.envOr("TOKEN_ADDRESS", USDC_ARBITRUM);
        uint256 amount = vm.envOr("DEPOSIT_AMOUNT", uint256(100 * 1e6)); // 100 USDC default (6 decimals)

        vm.startBroadcast();

        // Check allowance first
        uint256 allowance = IERC20(token).allowance(msg.sender, diamond);
        console.log("Current allowance:", allowance);
        require(allowance >= amount, "Insufficient allowance - run ApproveToken first!");

        // Check balance
        uint256 balance = IERC20(token).balanceOf(msg.sender);
        console.log("Your token balance:", balance);
        require(balance >= amount, "Insufficient token balance!");

        // Deposit
        ISavingsVault(diamond).deposit(token, amount);
        console.log("Deposited", amount, "of token", token);

        vm.stopBroadcast();
    }
}

contract DepositWithGoal is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address token = vm.envOr("TOKEN_ADDRESS", USDC_ARBITRUM);
        uint256 amount = vm.envOr("DEPOSIT_AMOUNT", uint256(100 * 1e6)); // 100 USDC
        uint256 targetAmount = vm.envOr("TARGET_AMOUNT", uint256(1000 * 1e6)); // 1000 USDC goal
        uint256 lockDuration = vm.envOr("LOCK_DURATION", uint256(30 days)); // 30 days lock

        vm.startBroadcast();

        // Check allowance first
        uint256 allowance = IERC20(token).allowance(msg.sender, diamond);
        require(allowance >= amount, "Insufficient allowance - run ApproveToken first!");

        // Deposit with goal
        ISavingsVault(diamond).depositWithGoal(token, amount, targetAmount, lockDuration);
        console.log("Deposited with goal:");
        console.log("  Amount:", amount);
        console.log("  Target:", targetAmount);
        console.log("  Lock duration:", lockDuration, "seconds");

        vm.stopBroadcast();
    }
}

contract CheckSavings is Script {
    function run() external view {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address token = vm.envOr("TOKEN_ADDRESS", USDC_ARBITRUM);
        address user = vm.envOr("USER_ADDRESS", msg.sender);

        ISavingsVault vault = ISavingsVault(diamond);

        // Get savings info
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user, token);

        console.log("=== Savings Info for", user, "===");
        console.log("Deposited Amount:", info.depositedAmount);
        console.log("Current Balance:", info.currentBalance);
        console.log("Accrued Yield:", info.accruedYield);
        console.log("Has Goal:", info.hasGoal);

        if (info.hasGoal) {
            console.log("Target Amount:", info.targetAmount);
            console.log("Unlock Timestamp:", info.unlockTimestamp);
            console.log("Is Locked:", info.isLocked);
            console.log("Goal Progress (bps):", info.goalProgress);
        }
    }
}

contract WithdrawFromVault is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND_ADDRESS");
        address token = vm.envOr("TOKEN_ADDRESS", USDC_ARBITRUM);
        uint256 amount = vm.envOr("WITHDRAW_AMOUNT", type(uint256).max); // Max = withdraw all

        vm.startBroadcast();

        ISavingsVault(diamond).withdraw(token, amount);
        console.log("Withdrawn from vault");

        vm.stopBroadcast();
    }
}
