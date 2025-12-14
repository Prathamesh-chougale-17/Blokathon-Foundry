// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title SavingsVaultFacet
    @author BLOK Capital DAO
    @notice Smart Savings Vault with Aave V3 yield and goal-based time-locks
    @dev A "Set-and-Forget" savings vault that auto-earns yield via Aave V3

    Features:
    - Deposit stablecoins that automatically earn Aave V3 yield
    - Create savings goals with target amounts and time-locks
    - Emergency withdraw with configurable penalty
    - Track deposits, yield, and goal progress

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Contracts
import {SavingsVaultBase} from "./SavingsVaultBase.sol";
import {SavingsVaultStorage} from "./SavingsVaultStorage.sol";
import {ISavingsVault} from "./ISavingsVault.sol";
import {Facet} from "src/facets/Facet.sol";

contract SavingsVaultFacet is SavingsVaultBase, Facet {
    // ========================================================================
    // User Functions
    // ========================================================================

    /// @inheritdoc ISavingsVault
    function deposit(address token, uint256 amount) external override nonReentrant {
        _deposit(msg.sender, token, amount);
    }

    /// @inheritdoc ISavingsVault
    function depositWithGoal(address token, uint256 amount, uint256 targetAmount, uint256 lockDuration)
        external
        override
        nonReentrant
    {
        _depositWithGoal(msg.sender, token, amount, targetAmount, lockDuration);
    }

    /// @inheritdoc ISavingsVault
    function withdraw(address token, uint256 amount) external override nonReentrant {
        _withdraw(msg.sender, token, amount);
    }

    /// @inheritdoc ISavingsVault
    function emergencyWithdraw(address token, uint256 amount) external override nonReentrant {
        _emergencyWithdraw(msg.sender, token, amount);
    }

    /// @inheritdoc ISavingsVault
    function claimGoal(address token) external override nonReentrant {
        _claimGoal(msg.sender, token);
    }

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @inheritdoc ISavingsVault
    function getSavingsInfo(address user, address token) external view override returns (SavingsInfo memory info) {
        return _getSavingsInfo(user, token);
    }

    /// @inheritdoc ISavingsVault
    function getBalance(address user, address token) external view override returns (uint256 balance) {
        return _getUserBalance(user, token);
    }

    /// @inheritdoc ISavingsVault
    function getAccruedYield(address user, address token) external view override returns (uint256 yield) {
        return _getAccruedYield(user, token);
    }

    /// @inheritdoc ISavingsVault
    function isTokenSupported(address token) external view override returns (bool supported) {
        return SavingsVaultStorage.layout().supportedTokens[token];
    }

    /// @inheritdoc ISavingsVault
    function isGoalActive(address user, address token) external view override returns (bool active) {
        return _isGoalActive(user, token);
    }

    /// @inheritdoc ISavingsVault
    function getEarlyWithdrawalPenalty() external view override returns (uint256 penaltyBps) {
        return SavingsVaultStorage.layout().earlyWithdrawalPenaltyBps;
    }

    // ========================================================================
    // Admin Functions
    // ========================================================================

    /// @inheritdoc ISavingsVault
    function setTokenSupported(address token, bool supported) external override onlyDiamondOwner {
        _setTokenSupported(token, supported);
    }

    /// @inheritdoc ISavingsVault
    function setTreasury(address treasury) external override onlyDiamondOwner {
        _setTreasury(treasury);
    }

    /// @inheritdoc ISavingsVault
    function setEarlyWithdrawalPenalty(uint256 penaltyBps) external override onlyDiamondOwner {
        _setEarlyWithdrawalPenalty(penaltyBps);
    }
}
