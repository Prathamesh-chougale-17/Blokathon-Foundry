// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title SavingsVaultBase
    @author BLOK Capital DAO
    @notice Base contract for SavingsVaultFacet with internal logic
    @dev Implements core savings vault functionality with Aave V3 integration

################################################################################*/

// OpenZeppelin Contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Aave Contracts
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

// Local Interfaces & Storage
import {ISavingsVault} from "./ISavingsVault.sol";
import {SavingsVaultStorage} from "./SavingsVaultStorage.sol";

// Errors
error SavingsVault_TokenNotSupported();
error SavingsVault_InvalidAmount();
error SavingsVault_InvalidToken();
error SavingsVault_InsufficientBalance();
error SavingsVault_GoalAlreadyExists();
error SavingsVault_FundsLocked();
error SavingsVault_PenaltyTooHigh();
error SavingsVault_InvalidTreasury();
error SavingsVault_InvalidTargetAmount();
error SavingsVault_InvalidAToken();
error SavingsVault_NoActiveGoal();

/// @notice Thrown when goal is not met for claim
error SavingsVault_GoalNotMet();

abstract contract SavingsVaultBase is ISavingsVault {
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_PENALTY_BPS = 1000;
    uint256 internal constant BPS_DENOMINATOR = 10000;

    /// @notice Aave V3 Pool (Arbitrum)
    address internal constant AAVE_V3_POOL_ADDRESS = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    // ========================================================================
    // Internal Functions - Deposits
    // ========================================================================

    function _deposit(address user, address token, uint256 amount) internal {
        if (token == address(0)) revert SavingsVault_InvalidToken();
        if (amount == 0) revert SavingsVault_InvalidAmount();

        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        if (!s.supportedTokens[token]) revert SavingsVault_TokenNotSupported();

        // Move tokens from user into vault
        IERC20(token).safeTransferFrom(user, address(this), amount);

        // Update balances
        s.userDeposits[user][token] += amount;
        s.totalDeposits[token] += amount;

        // Update goal deposits
        if (s.userGoals[user][token].isActive) {
            s.userGoals[user][token].depositedAmount += amount;
        }

        // Supply to Aave
        _supplyToAave(token, amount);

        emit Deposited(user, token, amount);
    }

    function _depositWithGoal(address user, address token, uint256 amount, uint256 targetAmount, uint256 lockDuration)
        internal
    {
        if (token == address(0)) revert SavingsVault_InvalidToken();
        if (amount == 0) revert SavingsVault_InvalidAmount();
        if (targetAmount == 0) revert SavingsVault_InvalidTargetAmount();

        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        if (!s.supportedTokens[token]) revert SavingsVault_TokenNotSupported();
        if (s.userGoals[user][token].isActive) {
            revert SavingsVault_GoalAlreadyExists();
        }

        // Transfer funds
        IERC20(token).safeTransferFrom(user, address(this), amount);

        // Create goal
        s.userGoals[user][token] = SavingsVaultStorage.SavingsGoal({
            targetAmount: targetAmount,
            unlockTimestamp: block.timestamp + lockDuration,
            depositedAmount: amount,
            createdAt: block.timestamp,
            isActive: true
        });

        // Update tracking
        s.userDeposits[user][token] += amount;
        s.totalDeposits[token] += amount;

        // Supply to Aave
        _supplyToAave(token, amount);

        emit GoalCreated(user, token, targetAmount, block.timestamp + lockDuration);
        emit Deposited(user, token, amount);
    }

    // ========================================================================
    // Internal Functions - Withdrawals
    // ========================================================================

    function _withdraw(address user, address token, uint256 amount) internal {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        SavingsVaultStorage.SavingsGoal storage goal = s.userGoals[user][token];

        uint256 currentBalance = _getUserBalance(user, token);
        uint256 withdrawAmount = amount == type(uint256).max ? currentBalance : amount;

        if (withdrawAmount == 0) revert SavingsVault_InvalidAmount();
        if (currentBalance < withdrawAmount) {
            revert SavingsVault_InsufficientBalance();
        }

        // Check lock conditions
        if (goal.isActive) {
            bool goalMet = currentBalance >= goal.targetAmount;
            bool unlocked = block.timestamp >= goal.unlockTimestamp;

            if (!goalMet && !unlocked) revert SavingsVault_FundsLocked();

            // Mark goal complete if fully withdrawing
            if (withdrawAmount == currentBalance) {
                goal.isActive = false;
                emit GoalCompleted(user, token, currentBalance);
            }
        }

        // Withdraw from Aave
        _withdrawFromAave(token, withdrawAmount);

        // Update storage
        s.userDeposits[user][token] = currentBalance - withdrawAmount;
        s.totalDeposits[token] -= _min(s.totalDeposits[token], withdrawAmount);

        IERC20(token).safeTransfer(user, withdrawAmount);

        emit Withdrawn(user, token, withdrawAmount, 0);
    }

    function _claimGoal(address user, address token) internal {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        SavingsVaultStorage.SavingsGoal storage goal = s.userGoals[user][token];

        if (!goal.isActive) revert SavingsVault_NoActiveGoal();

        uint256 currentBalance = _getUserBalance(user, token);

        bool goalMet = currentBalance >= goal.targetAmount;
        bool unlocked = block.timestamp >= goal.unlockTimestamp;

        if (!goalMet && !unlocked) revert SavingsVault_GoalNotMet();

        goal.isActive = false;

        _withdrawFromAave(token, currentBalance);

        s.userDeposits[user][token] = 0;
        s.totalDeposits[token] -= _min(s.totalDeposits[token], currentBalance);

        IERC20(token).safeTransfer(user, currentBalance);

        emit GoalCompleted(user, token, currentBalance);
        emit Withdrawn(user, token, currentBalance, 0);
    }

    function _emergencyWithdraw(address user, address token, uint256 amount) internal {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();

        uint256 currentBalance = _getUserBalance(user, token);

        if (amount == 0) revert SavingsVault_InvalidAmount();
        if (currentBalance < amount) revert SavingsVault_InsufficientBalance();

        uint256 penalty = (amount * s.earlyWithdrawalPenaltyBps) / BPS_DENOMINATOR;
        uint256 payout = amount - penalty;

        _withdrawFromAave(token, amount);

        // Update balances
        s.userDeposits[user][token] = currentBalance - amount;
        s.totalDeposits[token] -= _min(s.totalDeposits[token], amount);

        if (s.userGoals[user][token].isActive) {
            s.userGoals[user][token].isActive = false;
        }

        if (penalty > 0 && s.treasury != address(0)) {
            IERC20(token).safeTransfer(s.treasury, penalty);
        }

        IERC20(token).safeTransfer(user, payout);

        emit Withdrawn(user, token, payout, penalty);
    }

    /// @notice Claim all funds when goal is met (currentBalance >= targetAmount)
    function _claim(address user, address token) internal {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        SavingsVaultStorage.SavingsGoal storage goal = s.userGoals[user][token];

        uint256 currentBalance = _getUserBalance(user, token);
        if (currentBalance == 0) revert SavingsVault_InsufficientBalance();

        // If goal exists, check if it's met
        if (goal.isActive) {
            if (currentBalance < goal.targetAmount) {
                revert SavingsVault_GoalNotMet();
            }
            // Goal is met, mark as completed
            goal.isActive = false;
            emit GoalCompleted(user, token, currentBalance);
        }

        // Withdraw all from Aave
        _withdrawFromAave(token, currentBalance);

        // Update state
        s.userDeposits[user][token] = 0;
        s.totalDeposits[token] -= _min(s.totalDeposits[token], currentBalance);

        // Transfer all to user
        IERC20(token).safeTransfer(user, currentBalance);

        emit Withdrawn(user, token, currentBalance, 0);
    }

    // ========================================================================
    // View Helpers
    // ========================================================================

    function _getUserBalance(address user, address token) internal view returns (uint256) {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        uint256 deposited = s.userDeposits[user][token];

        if (deposited == 0) return 0;

        uint256 totalATokens = _getATokenBalance(token);
        uint256 totalDeposits = s.totalDeposits[token];

        if (totalDeposits == 0) return 0;

        return (totalATokens * deposited) / totalDeposits;
    }

    function _getAccruedYield(address user, address token) internal view returns (uint256) {
        uint256 deposited = SavingsVaultStorage.layout().userDeposits[user][token];
        uint256 current = _getUserBalance(user, token);

        return current > deposited ? current - deposited : 0;
    }

    function _isGoalActive(address user, address token) internal view returns (bool) {
        return SavingsVaultStorage.layout().userGoals[user][token].isActive;
    }

    function _getSavingsInfo(address user, address token) internal view returns (SavingsInfo memory info) {
        SavingsVaultStorage.Layout storage s = SavingsVaultStorage.layout();
        SavingsVaultStorage.SavingsGoal storage goal = s.userGoals[user][token];

        uint256 deposited = s.userDeposits[user][token];
        uint256 currentBalance = _getUserBalance(user, token);
        uint256 accruedYield = currentBalance > deposited ? currentBalance - deposited : 0;

        info.depositedAmount = deposited;
        info.currentBalance = currentBalance;
        info.accruedYield = accruedYield;
        info.hasGoal = goal.isActive;

        if (goal.isActive) {
            info.targetAmount = goal.targetAmount;
            info.unlockTimestamp = goal.unlockTimestamp;
            info.isLocked = block.timestamp < goal.unlockTimestamp && currentBalance < goal.targetAmount;
            // Calculate goal progress in basis points (10000 = 100%)
            info.goalProgress = goal.targetAmount > 0 ? (currentBalance * BPS_DENOMINATOR) / goal.targetAmount : 0;
        }

        return info;
    }

    // ========================================================================
    // Aave Integration
    // ========================================================================

    function _supplyToAave(address token, uint256 amount) internal {
        IPool pool = IPool(AAVE_V3_POOL_ADDRESS);

        IERC20(token).forceApprove(address(pool), amount);

        pool.supply(token, amount, address(this), 0);
    }

    function _withdrawFromAave(address token, uint256 amount) internal {
        IPool pool = IPool(AAVE_V3_POOL_ADDRESS);
        pool.withdraw(token, amount, address(this));
    }

    function _getATokenBalance(address token) internal view returns (uint256) {
        IPool pool = IPool(AAVE_V3_POOL_ADDRESS);
        DataTypes.ReserveData memory reserve = pool.getReserveData(token);

        if (reserve.aTokenAddress == address(0)) return 0;

        return IERC20(reserve.aTokenAddress).balanceOf(address(this));
    }

    // ========================================================================
    // Admin
    // ========================================================================

    function _setTokenSupported(address token, bool supported) internal {
        if (token == address(0)) revert SavingsVault_InvalidToken();

        SavingsVaultStorage.layout().supportedTokens[token] = supported;

        emit TokenSupportUpdated(token, supported);
    }

    function _setTreasury(address treasury) internal {
        if (treasury == address(0)) revert SavingsVault_InvalidTreasury();

        SavingsVaultStorage.layout().treasury = treasury;

        emit TreasuryUpdated(address(0), treasury);
    }

    function _setEarlyWithdrawalPenalty(uint256 penaltyBps) internal {
        if (penaltyBps > MAX_PENALTY_BPS) revert SavingsVault_PenaltyTooHigh();

        SavingsVaultStorage.layout().earlyWithdrawalPenaltyBps = penaltyBps;

        emit PenaltyRateUpdated(0, penaltyBps);
    }

    // ========================================================================
    // Utility
    // ========================================================================

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
