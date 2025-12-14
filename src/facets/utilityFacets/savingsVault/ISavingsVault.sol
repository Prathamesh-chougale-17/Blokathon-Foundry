// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title ISavingsVault
    @author BLOK Capital DAO
    @notice Interface for the Smart Savings Vault with Aave V3 yield generation
    @dev Defines functions for goal-based savings with time-locks and auto-yield

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface ISavingsVault {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Information about a user's savings position
    struct SavingsInfo {
        uint256 depositedAmount;
        uint256 currentBalance;
        uint256 accruedYield;
        uint256 targetAmount;
        uint256 unlockTimestamp;
        uint256 goalProgress; // percentage in basis points (10000 = 100%)
        bool isLocked;
        bool hasGoal;
    }

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a user deposits into savings
    event Deposited(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when a user withdraws from savings
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 penalty);

    /// @notice Emitted when a savings goal is created
    event GoalCreated(address indexed user, address indexed token, uint256 targetAmount, uint256 unlockTimestamp);

    /// @notice Emitted when a savings goal is completed
    event GoalCompleted(address indexed user, address indexed token, uint256 totalSaved);

    /// @notice Emitted when a savings goal is cancelled
    event GoalCancelled(address indexed user, address indexed token);

    /// @notice Emitted when a token is added/removed from supported list
    event TokenSupportUpdated(address indexed token, bool supported);

    /// @notice Emitted when treasury address is updated
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when penalty rate is updated
    event PenaltyRateUpdated(uint256 oldRate, uint256 newRate);

    // ========================================================================
    // User Functions
    // ========================================================================

    /// @notice Deposit tokens into the savings vault (auto-supplied to Aave)
    /// @param token The ERC20 token address to deposit
    /// @param amount Amount of tokens to deposit
    function deposit(address token, uint256 amount) external;

    /// @notice Deposit with a savings goal (target amount + time-lock)
    /// @param token The ERC20 token address to deposit
    /// @param amount Initial deposit amount
    /// @param targetAmount Target savings amount
    /// @param lockDuration Duration in seconds until funds can be withdrawn penalty-free
    function depositWithGoal(address token, uint256 amount, uint256 targetAmount, uint256 lockDuration) external;

    /// @notice Withdraw tokens from savings vault
    /// @param token The token address to withdraw
    /// @param amount Amount to withdraw (or type(uint256).max for full withdrawal)
    function withdraw(address token, uint256 amount) external;

    /// @notice Emergency withdraw with penalty if goal/lock not met
    /// @param token The token address to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, uint256 amount) external;

    /// @notice Claim all funds when goal is met (currentBalance >= targetAmount)
    /// @param token The token address to claim
    function claimGoal(address token) external;

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @notice Get comprehensive savings info for a user
    /// @param user The user address
    /// @param token The token address
    /// @return info SavingsInfo struct with all position details
    function getSavingsInfo(address user, address token) external view returns (SavingsInfo memory info);

    /// @notice Get the current balance including accrued yield
    /// @param user The user address
    /// @param token The token address
    /// @return balance Current balance including yield
    function getBalance(address user, address token) external view returns (uint256 balance);

    /// @notice Get accrued yield for a user's position
    /// @param user The user address
    /// @param token The token address
    /// @return yield Accrued yield amount
    function getAccruedYield(address user, address token) external view returns (uint256 yield);

    /// @notice Check if a token is supported for savings
    /// @param token The token address to check
    /// @return supported Whether the token is supported
    function isTokenSupported(address token) external view returns (bool supported);

    /// @notice Check if a user has an active savings goal for a token
    /// @param user The user address
    /// @param token The token address
    /// @return active Whether the user has an active goal
    function isGoalActive(address user, address token) external view returns (bool active);

    /// @notice Get the early withdrawal penalty rate
    /// @return penaltyBps Penalty in basis points
    function getEarlyWithdrawalPenalty() external view returns (uint256 penaltyBps);

    // ========================================================================
    // Admin Functions
    // ========================================================================

    /// @notice Add or remove a token from supported list (owner only)
    /// @param token The token address
    /// @param supported Whether to support the token
    function setTokenSupported(address token, bool supported) external;

    /// @notice Set the treasury address for penalties (owner only)
    /// @param treasury The new treasury address
    function setTreasury(address treasury) external;

    /// @notice Set the early withdrawal penalty rate (owner only)
    /// @param penaltyBps Penalty in basis points (max 1000 = 10%)
    function setEarlyWithdrawalPenalty(uint256 penaltyBps) external;
}
