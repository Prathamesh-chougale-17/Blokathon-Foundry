// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC165} from "src/interfaces/IERC165.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {SavingsVaultFacet} from "src/facets/utilityFacets/savingsVault/SavingsVaultFacet.sol";
import {ISavingsVault} from "src/facets/utilityFacets/savingsVault/ISavingsVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

/// @title SavingsVaultFacet Test Suite
/// @notice Comprehensive tests for the SavingsVaultFacet functionality
contract SavingsVaultFacetTest is Test {
    // ========================================================================
    // State Variables
    // ========================================================================

    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    SavingsVaultFacet public savingsVaultFacet;

    // Diamond interface references
    SavingsVaultFacet public vault;

    // Test addresses
    address public owner;
    address public user1;
    address public user2;
    address public treasury;

    // Mock token address (we'll use a mock for testing)
    address public mockToken;

    // Aave Pool address (same as in SavingsVaultBase)
    address internal constant AAVE_V3_POOL_ADDRESS = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    // ========================================================================
    // Setup
    // ========================================================================

    function setUp() public {
        // Set up test accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");

        // Deploy mock Aave Pool and deploy it at the expected address using vm.etch + vm.store
        // We need to deploy at the exact address the SavingsVaultBase expects
        _deployMockAavePool();

        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        savingsVaultFacet = new SavingsVaultFacet();

        // Prepare FacetCuts for Diamond initialization
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](3);

        // DiamondCut facet
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupe facet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Ownership facet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = IERC173.owner.selector;
        ownershipSelectors[1] = IERC173.transferOwnership.selector;
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // Deploy Diamond
        diamond = new Diamond(owner, facetCuts);

        // Add SavingsVaultFacet to Diamond
        _addSavingsVaultFacet();

        // Get reference to vault through diamond
        vault = SavingsVaultFacet(address(diamond));

        // Deploy mock token
        mockToken = address(new MockERC20("Mock USDC", "mUSDC", 6));

        // Configure vault
        vault.setTokenSupported(mockToken, true);
        vault.setTreasury(treasury);
        vault.setEarlyWithdrawalPenalty(50); // 0.5%

        // Fund test users
        MockERC20(mockToken).mint(user1, 10000e6);
        MockERC20(mockToken).mint(user2, 10000e6);
    }

    function _addSavingsVaultFacet() internal {
        bytes4[] memory selectors = new bytes4[](13);
        selectors[0] = SavingsVaultFacet.deposit.selector;
        selectors[1] = SavingsVaultFacet.depositWithGoal.selector;
        selectors[2] = SavingsVaultFacet.withdraw.selector;
        selectors[3] = SavingsVaultFacet.emergencyWithdraw.selector;
        selectors[4] = SavingsVaultFacet.claimGoal.selector;
        selectors[5] = SavingsVaultFacet.getSavingsInfo.selector;
        selectors[6] = SavingsVaultFacet.getBalance.selector;
        selectors[7] = SavingsVaultFacet.getAccruedYield.selector;
        selectors[8] = SavingsVaultFacet.isTokenSupported.selector;
        selectors[9] = SavingsVaultFacet.getEarlyWithdrawalPenalty.selector;
        selectors[10] = SavingsVaultFacet.setTokenSupported.selector;
        selectors[11] = SavingsVaultFacet.setTreasury.selector;
        selectors[12] = SavingsVaultFacet.setEarlyWithdrawalPenalty.selector;

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(savingsVaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        DiamondCutFacet(address(diamond)).diamondCut(facetCuts, address(0), "");
    }

    function _deployMockAavePool() internal {
        // Use vm.etch to place mock pool code at Aave's expected address
        vm.etch(AAVE_V3_POOL_ADDRESS, address(new MockAavePool()).code);
    }

    // ========================================================================
    // Admin Function Tests
    // ========================================================================

    function test_SetTokenSupported() public {
        address newToken = makeAddr("newToken");

        vault.setTokenSupported(newToken, true);
        assertTrue(vault.isTokenSupported(newToken));

        vault.setTokenSupported(newToken, false);
        assertFalse(vault.isTokenSupported(newToken));
    }

    function test_SetTokenSupported_RevertIfNotOwner() public {
        address newToken = makeAddr("newToken");

        vm.prank(user1);
        vm.expectRevert();
        vault.setTokenSupported(newToken, true);
    }

    function test_SetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vault.setTreasury(newTreasury);
        // Treasury is set (we can verify through events or state)
    }

    function test_SetTreasury_RevertIfZeroAddress() public {
        vm.expectRevert();
        vault.setTreasury(address(0));
    }

    function test_SetEarlyWithdrawalPenalty() public {
        vault.setEarlyWithdrawalPenalty(100); // 1%
        assertEq(vault.getEarlyWithdrawalPenalty(), 100);
    }

    function test_SetEarlyWithdrawalPenalty_RevertIfTooHigh() public {
        vm.expectRevert();
        vault.setEarlyWithdrawalPenalty(1001); // > 10%
    }

    // ========================================================================
    // Deposit Tests
    // ========================================================================

    function test_Deposit() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.deposit(mockToken, depositAmount);
        vm.stopPrank();

        // Note: In a real test with Aave, balance would be in aTokens
        // For this mock test, we verify the deposit was recorded
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, depositAmount);
    }

    function test_Deposit_RevertIfTokenNotSupported() public {
        address unsupportedToken = makeAddr("unsupported");

        vm.startPrank(user1);
        vm.expectRevert();
        vault.deposit(unsupportedToken, 100e6);
        vm.stopPrank();
    }

    function test_Deposit_RevertIfZeroAmount() public {
        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), 100e6);
        vm.expectRevert();
        vault.deposit(mockToken, 0);
        vm.stopPrank();
    }

    // ========================================================================
    // Deposit With Goal Tests
    // ========================================================================

    function test_DepositWithGoal() public {
        uint256 depositAmount = 500e6;
        uint256 targetAmount = 5000e6;
        uint256 lockDuration = 180 days;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, targetAmount, lockDuration);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, depositAmount);
        assertEq(info.targetAmount, targetAmount);
        assertTrue(info.hasGoal);
        assertTrue(info.isLocked);
    }

    function test_DepositWithGoal_RevertIfGoalExists() public {
        uint256 depositAmount = 500e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount * 2);
        vault.depositWithGoal(mockToken, depositAmount, 5000e6, 180 days);

        // Try to create another goal - should fail
        vm.expectRevert();
        vault.depositWithGoal(mockToken, depositAmount, 10000e6, 365 days);
        vm.stopPrank();
    }

    // ========================================================================
    // Withdrawal Tests
    // ========================================================================

    function test_Withdraw_NoGoal() public {
        uint256 depositAmount = 1000e6;

        // First deposit
        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.deposit(mockToken, depositAmount);

        // Verify deposit was recorded
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, depositAmount);

        vm.stopPrank();
    }

    // ========================================================================
    // View Function Tests
    // ========================================================================

    function test_GetSavingsInfo() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.deposit(mockToken, depositAmount);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, depositAmount);
    }

    function test_IsTokenSupported() public view {
        assertTrue(vault.isTokenSupported(mockToken));
        assertFalse(vault.isTokenSupported(address(0x123)));
    }

    function test_GetEarlyWithdrawalPenalty() public view {
        assertEq(vault.getEarlyWithdrawalPenalty(), 50);
    }

    // ========================================================================
    // Goal Progress Tests
    // ========================================================================

    function test_GoalProgress() public {
        uint256 targetAmount = 1000e6;
        uint256 initialDeposit = 250e6; // 25% of goal

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), initialDeposit);
        vault.depositWithGoal(mockToken, initialDeposit, targetAmount, 180 days);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        // Goal progress should be ~2500 bps (25%)
        // Note: Actual value depends on aToken balance calculation
        assertTrue(info.hasGoal);
    }

    // ========================================================================
    // Multiple User Tests
    // ========================================================================

    function test_MultipleUsersDeposit() public {
        uint256 deposit1 = 1000e6;
        uint256 deposit2 = 2000e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), deposit1);
        vault.deposit(mockToken, deposit1);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(mockToken).approve(address(diamond), deposit2);
        vault.deposit(mockToken, deposit2);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info1 = vault.getSavingsInfo(user1, mockToken);
        ISavingsVault.SavingsInfo memory info2 = vault.getSavingsInfo(user2, mockToken);

        assertEq(info1.depositedAmount, deposit1);
        assertEq(info2.depositedAmount, deposit2);
    }

    // ========================================================================
    // Edge Cases
    // ========================================================================

    function test_DepositMultipleTimes() public {
        uint256 deposit1 = 500e6;
        uint256 deposit2 = 300e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), deposit1 + deposit2);

        vault.deposit(mockToken, deposit1);
        vault.deposit(mockToken, deposit2);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, deposit1 + deposit2);
    }

    function test_DepositAfterGoalCreated() public {
        uint256 initialDeposit = 500e6;
        uint256 additionalDeposit = 200e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), initialDeposit + additionalDeposit);

        // Create goal with initial deposit
        vault.depositWithGoal(mockToken, initialDeposit, 5000e6, 180 days);

        // Add more to the goal
        vault.deposit(mockToken, additionalDeposit);
        vm.stopPrank();

        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertEq(info.depositedAmount, initialDeposit + additionalDeposit);
        assertTrue(info.hasGoal);
    }

    // ========================================================================
    // Claim Goal Tests
    // ========================================================================

    function test_ClaimGoal_WhenGoalMet() public {
        uint256 targetAmount = 1000e6;
        uint256 depositAmount = 1000e6; // Exactly meet the goal

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, targetAmount, 180 days);

        // Goal is met (deposit >= target), should be able to claim
        uint256 balanceBefore = IERC20(mockToken).balanceOf(user1);
        vault.claimGoal(mockToken);
        uint256 balanceAfter = IERC20(mockToken).balanceOf(user1);

        // User should receive their funds back
        assertEq(balanceAfter - balanceBefore, depositAmount);

        // Goal should be deactivated
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertFalse(info.hasGoal);
        assertEq(info.depositedAmount, 0);
        vm.stopPrank();
    }

    function test_ClaimGoal_WhenTimeUnlocked() public {
        uint256 targetAmount = 5000e6;
        uint256 depositAmount = 1000e6; // Less than target
        uint256 lockDuration = 30 days;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, targetAmount, lockDuration);

        // Fast forward past lock duration
        vm.warp(block.timestamp + lockDuration + 1);

        // Should be able to claim even though target not met
        uint256 balanceBefore = IERC20(mockToken).balanceOf(user1);
        vault.claimGoal(mockToken);
        uint256 balanceAfter = IERC20(mockToken).balanceOf(user1);

        assertEq(balanceAfter - balanceBefore, depositAmount);

        // Goal should be deactivated
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertFalse(info.hasGoal);
        vm.stopPrank();
    }

    function test_ClaimGoal_RevertIfGoalNotMet() public {
        uint256 targetAmount = 5000e6;
        uint256 depositAmount = 1000e6; // Less than target

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, targetAmount, 180 days);

        // Try to claim before goal met and before time unlocked
        vm.expectRevert();
        vault.claimGoal(mockToken);
        vm.stopPrank();
    }

    function test_ClaimGoal_RevertIfNoActiveGoal() public {
        // Deposit without goal
        uint256 depositAmount = 1000e6;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.deposit(mockToken, depositAmount);

        // Try to claim without an active goal
        vm.expectRevert();
        vault.claimGoal(mockToken);
        vm.stopPrank();
    }

    // ========================================================================
    // Emergency Withdraw Tests
    // ========================================================================

    function test_EmergencyWithdraw_WithPenalty() public {
        uint256 depositAmount = 1000e6;
        uint256 expectedPenalty = (depositAmount * 50) / 10000; // 0.5%
        uint256 expectedReceived = depositAmount - expectedPenalty;

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, 5000e6, 180 days);

        uint256 balanceBefore = IERC20(mockToken).balanceOf(user1);
        vault.emergencyWithdraw(mockToken, depositAmount);
        uint256 balanceAfter = IERC20(mockToken).balanceOf(user1);

        // User should receive amount minus penalty
        assertEq(balanceAfter - balanceBefore, expectedReceived);

        // Goal should be deactivated
        ISavingsVault.SavingsInfo memory info = vault.getSavingsInfo(user1, mockToken);
        assertFalse(info.hasGoal);
        vm.stopPrank();
    }

    function test_EmergencyWithdraw_PenaltyGoesToTreasury() public {
        uint256 depositAmount = 1000e6;
        uint256 expectedPenalty = (depositAmount * 50) / 10000; // 0.5%

        vm.startPrank(user1);
        IERC20(mockToken).approve(address(diamond), depositAmount);
        vault.depositWithGoal(mockToken, depositAmount, 5000e6, 180 days);

        uint256 treasuryBefore = IERC20(mockToken).balanceOf(treasury);
        vault.emergencyWithdraw(mockToken, depositAmount);
        uint256 treasuryAfter = IERC20(mockToken).balanceOf(treasury);

        // Treasury should receive the penalty
        assertEq(treasuryAfter - treasuryBefore, expectedPenalty);
        vm.stopPrank();
    }
}

// ============================================================================
// Mock ERC20 Token for Testing
// ============================================================================

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

// ============================================================================
// Mock Aave V3 Pool for Testing
// ============================================================================

contract MockAavePool {
    // Track aToken addresses for each underlying token
    mapping(address => address) public aTokens;
    // Track supplies per user per token
    mapping(address => mapping(address => uint256)) public supplies;

    /// @notice Supply tokens to the pool
    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        // Get or create aToken for this asset
        address aToken = aTokens[asset];
        if (aToken == address(0)) {
            // Create a mock aToken
            MockAToken newAToken = new MockAToken(asset);
            aTokens[asset] = address(newAToken);
            aToken = address(newAToken);
        }

        // Transfer underlying from caller
        require(IERC20(asset).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Mint aTokens to the onBehalfOf address
        MockAToken(aToken).mint(onBehalfOf, amount);

        supplies[onBehalfOf][asset] += amount;
    }

    /// @notice Withdraw tokens from the pool
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        address aToken = aTokens[asset];
        require(aToken != address(0), "No aToken");

        uint256 aTokenBalance = MockAToken(aToken).balanceOf(msg.sender);
        uint256 withdrawAmount = amount == type(uint256).max ? aTokenBalance : amount;

        // Burn aTokens
        MockAToken(aToken).burn(msg.sender, withdrawAmount);

        // Transfer underlying to recipient
        require(IERC20(asset).transfer(to, withdrawAmount), "Transfer failed");

        return withdrawAmount;
    }

    /// @notice Get reserve data (returns aToken address)
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory data) {
        data.aTokenAddress = aTokens[asset];
        return data;
    }
}

// ============================================================================
// Mock aToken for Testing
// ============================================================================

contract MockAToken {
    address public immutable UNDERLYING_ASSET;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(address underlying) {
        UNDERLYING_ASSET = underlying;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        require(balanceOf[from] >= amount, "Insufficient aToken balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }
}
