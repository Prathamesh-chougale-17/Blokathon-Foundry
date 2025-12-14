// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title AaveV3Storage
    @author BLOK Capital DAO
    @notice Storage for the AaveV3Facet
    @dev This storage is used to store the AaveV3Facet

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library AaveV3Storage {
    /// @notice Fixed storage slot for AaveV3 persistent state.
    bytes32 internal constant AAVEV3_STORAGE_POSITION = keccak256("aave.v3.storage");

    /// @notice Layout for the AaveV3Storage
    struct Layout {
        /// @notice Timestamp of the last lend operation
        uint256 lastLendTimestamp;
    }

    /// @notice Returns a pointer to the AaveV3 storage layout
    /// @return l Storage pointer to the AaveV3 Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = AAVEV3_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
