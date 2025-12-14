// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title SavingsVaultStorage
    @author BLOK Capital DAO
    @notice Storage for the SavingsVaultFacet - Smart Savings with Aave V3 Yield
    @dev Diamond storage pattern for goal-based savings with time-locks

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library SavingsVaultStorage {
    /// @notice Fixed storage slot for SavingsVault persistent state
    bytes32 internal constant SAVINGS_VAULT_STORAGE_POSITION = keccak256("blok.diamond.storage.savings.vault");

    /// @notice Represents a user's savings goal with optional time-lock
    struct SavingsGoal {
        /// @notice Target amount to save (in token decimals)
        uint256 targetAmount;
        /// @notice Timestamp when savings can be withdrawn without penalty
        uint256 unlockTimestamp;
        /// @notice Principal amount deposited (excluding yield)
        uint256 depositedAmount;
        /// @notice Timestamp of first deposit
        uint256 createdAt;
        /// @notice Whether the goal is active
        bool isActive;
    }

    /// @notice Layout for the SavingsVaultStorage
    struct Layout {
        /// @notice User address => Token address => SavingsGoal
        mapping(address => mapping(address => SavingsGoal)) userGoals;
        /// @notice User address => Token address => Total deposited (for users without goals)
        mapping(address => mapping(address => uint256)) userDeposits;
        /// @notice Early withdrawal penalty in basis points (e.g., 50 = 0.5%)
        uint256 earlyWithdrawalPenaltyBps;
        /// @notice Treasury address to receive penalties
        address treasury;
        /// @notice Supported tokens for savings (token => supported)
        mapping(address => bool) supportedTokens;
        /// @notice Total deposits per token across all users
        mapping(address => uint256) totalDeposits;
    }

    /// @notice Returns a pointer to the SavingsVault storage layout
    /// @return l Storage pointer to the SavingsVault Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = SAVINGS_VAULT_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
