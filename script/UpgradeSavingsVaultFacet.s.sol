//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeSavingsVaultFacet
    @author BLOK Capital DAO
    @notice Upgrade script to add claimGoal and cancelGoal functions
    @dev Replaces the existing SavingsVaultFacet with new version

################################################################################*/

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {SavingsVaultFacet} from "src/facets/utilityFacets/savingsVault/SavingsVaultFacet.sol";

contract UpgradeSavingsVaultFacetScript is BaseScript {
    // Diamond deployed on Arbitrum mainnet
    address internal constant DIAMOND_ADDRESS = 0xE7CEe4ff6298AeA36BF1314d776c240f2caDd374;

    function run() public broadcaster {
        setUp();

        // Deploy new SavingsVaultFacet with claimGoal and cancelGoal
        SavingsVaultFacet newFacet = new SavingsVaultFacet();
        console.log("New SavingsVaultFacet deployed to:", address(newFacet));

        // Prepare new function selectors to ADD (claimGoal only)
        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = SavingsVaultFacet.claimGoal.selector;

        // Prepare existing function selectors to REPLACE (point to new facet)
        bytes4[] memory replaceSelectors = new bytes4[](12);
        replaceSelectors[0] = SavingsVaultFacet.deposit.selector;
        replaceSelectors[1] = SavingsVaultFacet.depositWithGoal.selector;
        replaceSelectors[2] = SavingsVaultFacet.withdraw.selector;
        replaceSelectors[3] = SavingsVaultFacet.emergencyWithdraw.selector;
        replaceSelectors[4] = SavingsVaultFacet.getSavingsInfo.selector;
        replaceSelectors[5] = SavingsVaultFacet.getBalance.selector;
        replaceSelectors[6] = SavingsVaultFacet.getAccruedYield.selector;
        replaceSelectors[7] = SavingsVaultFacet.isTokenSupported.selector;
        replaceSelectors[8] = SavingsVaultFacet.getEarlyWithdrawalPenalty.selector;
        replaceSelectors[9] = SavingsVaultFacet.setTokenSupported.selector;
        replaceSelectors[10] = SavingsVaultFacet.setTreasury.selector;
        replaceSelectors[11] = SavingsVaultFacet.setEarlyWithdrawalPenalty.selector;

        // Create FacetCuts: Replace existing + Add new
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](2);

        // Replace existing functions with new facet implementation
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replaceSelectors
        });

        // Add new functions (claimGoal, cancelGoal)
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors: newSelectors
        });

        // Execute diamond cut
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");

        console.log("=== SavingsVaultFacet Upgrade Complete ===");
        console.log("New function added: claimGoal");
        console.log("All existing functions updated to new implementation");
    }
}
