//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DeploySavingsVaultFacet
    @author BLOK Capital DAO
    @notice Deployment script for SavingsVaultFacet
    @dev Deploys and adds SavingsVaultFacet to the Diamond

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {SavingsVaultFacet} from "src/facets/utilityFacets/savingsVault/SavingsVaultFacet.sol";

contract DeploySavingsVaultFacetScript is BaseScript {
    // Diamond deployed on Arbitrum mainnet
    address internal constant DIAMOND_ADDRESS = 0x974F4C2CC78623BE6Af551498a6Bb037C413B80C;

    // Common stablecoin addresses on Arbitrum One
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Native USDC
    address internal constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address internal constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    function run() public broadcaster {
        setUp();

        // Deploy SavingsVaultFacet
        SavingsVaultFacet savingsVaultFacet = new SavingsVaultFacet();
        console.log("SavingsVaultFacet deployed to: ", address(savingsVaultFacet));

        // Prepare function selectors (14 functions)
        bytes4[] memory functionSelectors = new bytes4[](14);

        // User functions
        functionSelectors[0] = SavingsVaultFacet.deposit.selector;
        functionSelectors[1] = SavingsVaultFacet.depositWithGoal.selector;
        functionSelectors[2] = SavingsVaultFacet.withdraw.selector;
        functionSelectors[3] = SavingsVaultFacet.emergencyWithdraw.selector;
        functionSelectors[4] = SavingsVaultFacet.claimGoal.selector;

        // View functions
        functionSelectors[5] = SavingsVaultFacet.getSavingsInfo.selector;
        functionSelectors[6] = SavingsVaultFacet.getBalance.selector;
        functionSelectors[7] = SavingsVaultFacet.getAccruedYield.selector;
        functionSelectors[8] = SavingsVaultFacet.isTokenSupported.selector;
        functionSelectors[9] = SavingsVaultFacet.isGoalActive.selector;
        functionSelectors[10] = SavingsVaultFacet.getEarlyWithdrawalPenalty.selector;

        // Admin functions
        functionSelectors[11] = SavingsVaultFacet.setTokenSupported.selector;
        functionSelectors[12] = SavingsVaultFacet.setTreasury.selector;
        functionSelectors[13] = SavingsVaultFacet.setEarlyWithdrawalPenalty.selector;

        // Create FacetCut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(savingsVaultFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        // Add facet to diamond
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");
        console.log("SavingsVaultFacet added to Diamond");

        // Configure initial settings via the Diamond
        SavingsVaultFacet diamond = SavingsVaultFacet(DIAMOND_ADDRESS);

        // Set supported tokens (USDC, USDT, DAI on Arbitrum)
        diamond.setTokenSupported(USDC, true);
        console.log("USDC enabled as supported token");

        diamond.setTokenSupported(USDT, true);
        console.log("USDT enabled as supported token");

        diamond.setTokenSupported(DAI, true);
        console.log("DAI enabled as supported token");

        // Set treasury (deployer for now - update in production)
        diamond.setTreasury(deployer);
        console.log("Treasury set to deployer: ", deployer);

        // Set early withdrawal penalty (0.5% = 50 bps)
        diamond.setEarlyWithdrawalPenalty(50);
        console.log("Early withdrawal penalty set to 0.5%");

        console.log("=== SavingsVaultFacet Deployment Complete ===");
    }
}
