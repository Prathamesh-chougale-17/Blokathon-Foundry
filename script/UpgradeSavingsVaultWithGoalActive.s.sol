//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeSavingsVaultWithGoalActive
    @author BLOK Capital DAO
    @notice Upgrade script to add isGoalActive function to SavingsVaultFacet
    @dev Deploys new facet, replaces existing functions, and adds the new one

################################################################################*/

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {SavingsVaultFacet} from "src/facets/utilityFacets/savingsVault/SavingsVaultFacet.sol";

contract UpgradeSavingsVaultWithGoalActiveScript is BaseScript {
    // Diamond deployed on Arbitrum mainnet
    address internal constant DIAMOND_ADDRESS = 0x974F4C2CC78623BE6Af551498a6Bb037C413B80C;

    function run() public broadcaster {
        setUp();

        // Deploy new SavingsVaultFacet with isGoalActive
        SavingsVaultFacet savingsVaultFacet = new SavingsVaultFacet();
        console.log("New SavingsVaultFacet deployed to: ", address(savingsVaultFacet));

        // Existing function selectors to REPLACE (13 functions)
        bytes4[] memory replaceSelectors = new bytes4[](13);
        replaceSelectors[0] = SavingsVaultFacet.deposit.selector;
        replaceSelectors[1] = SavingsVaultFacet.depositWithGoal.selector;
        replaceSelectors[2] = SavingsVaultFacet.withdraw.selector;
        replaceSelectors[3] = SavingsVaultFacet.emergencyWithdraw.selector;
        replaceSelectors[4] = SavingsVaultFacet.claimGoal.selector;
        replaceSelectors[5] = SavingsVaultFacet.getSavingsInfo.selector;
        replaceSelectors[6] = SavingsVaultFacet.getBalance.selector;
        replaceSelectors[7] = SavingsVaultFacet.getAccruedYield.selector;
        replaceSelectors[8] = SavingsVaultFacet.isTokenSupported.selector;
        replaceSelectors[9] = SavingsVaultFacet.getEarlyWithdrawalPenalty.selector;
        replaceSelectors[10] = SavingsVaultFacet.setTokenSupported.selector;
        replaceSelectors[11] = SavingsVaultFacet.setTreasury.selector;
        replaceSelectors[12] = SavingsVaultFacet.setEarlyWithdrawalPenalty.selector;

        // New function selector to ADD (1 function)
        bytes4[] memory addSelectors = new bytes4[](1);
        addSelectors[0] = SavingsVaultFacet.isGoalActive.selector;

        // Create FacetCuts - 2 cuts: Replace existing + Add new
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](2);

        // Replace existing functions
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(savingsVaultFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replaceSelectors
        });

        // Add new isGoalActive function
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(savingsVaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: addSelectors
        });

        // Execute diamond cut
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");
        console.log("SavingsVaultFacet upgraded with isGoalActive function");

        console.log("=== Upgrade Complete ===");
        console.log("New facet address: ", address(savingsVaultFacet));
        console.log("isGoalActive selector: ", uint32(SavingsVaultFacet.isGoalActive.selector));
    }
}
