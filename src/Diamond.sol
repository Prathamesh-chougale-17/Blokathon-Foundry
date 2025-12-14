// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*###############################################################################

    @title Diamond
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Implementation of a Diamond proxy following EIP-2535 Diamonds standard
    @dev This contract implements the Diamond proxy pattern, allowing for modular and upgradeable smart contracts.
         It delegates calls to various facets based on function selectors.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {IERC165} from "src/interfaces/IERC165.sol";

import {DiamondCutStorage} from "src/facets/baseFacets/cut/DiamondCutStorage.sol";
import {DiamondLoupeStorage} from "src/facets/baseFacets/loupe/DiamondLoupeStorage.sol";
import {OwnershipStorage} from "src/facets/baseFacets/ownership/OwnershipStorage.sol";

import {DiamondCutBase} from "src/facets/baseFacets/cut/DiamondCutBase.sol";

contract Diamond is DiamondCutBase {
    constructor(address _contractOwner, IDiamondCut.FacetCut[] memory _facetCuts) payable {
        OwnershipStorage.Layout storage os = OwnershipStorage.layout();
        os.owner = _contractOwner;

        _diamondCut(_facetCuts, address(0), "");

        DiamondLoupeStorage.Layout storage ls = DiamondLoupeStorage.layout();
        ls.supportedInterfaces[type(IERC165).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ls.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ls.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
