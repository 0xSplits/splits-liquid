// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {Clone} from "solady/utils/Clone.sol";
import {LiquidSplitImpl} from "src/LiquidSplitImpl.sol";

/// @title 1155LiquidSplit
/// @author 0xSplits
/// @notice A minimal liquid splits implementation (ownership in a split is represented by 1155s).
/// Each 1155 = 0.1% of the split.
/// @dev This contract uses token = address(0) to refer to ETH.
contract LS1155Impl is ERC1155, Clone, LiquidSplitImpl {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Array lengths of accounts & percentAllocations don't match (`accountsLength` != `allocationsLength`)
    /// @param accountsLength Length of accounts array
    /// @param allocationsLength Length of percentAllocations array
    error InvalidLiquidSplit__AccountsAndAllocationsMismatch(uint256 accountsLength, uint256 allocationsLength);

    /// Invalid initAllocations sum `allocationsSum` must equal `TOTAL_SUPPLY`
    /// @param allocationsSum Sum of percentAllocations array
    error InvalidLiquidSplit__InvalidAllocationsSum(uint32 allocationsSum);

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 internal constant TOKEN_ID = 0;
    uint256 public constant TOTAL_SUPPLY = 1e3;
    uint256 public constant SUPPLY_TO_PERCENTAGE = 1e3; // = PERCENTAGE_SCALE / TOTAL_SUPPLY

    /// -----------------------------------------------------------------------
    /// constructor & initializer
    /// -----------------------------------------------------------------------

    // solhint-disable-next-line no-empty-blocks
    constructor(address _splitMain) LiquidSplitImpl(_splitMain) {}

    // TODO: check if initialized
    // or only allow msg.sender to be factory
    // TODO: use cwia for dist fee

    function initializer(address[] calldata accounts, uint32[] calldata initAllocations, uint32 _distributorFee)
        external
    {
        /// checks

        if (accounts.length != initAllocations.length) {
            revert InvalidLiquidSplit__AccountsAndAllocationsMismatch(accounts.length, initAllocations.length);
        }

        {
            uint32 sum = _getSum(initAllocations);
            if (sum != TOTAL_SUPPLY) {
                revert InvalidLiquidSplit__InvalidAllocationsSum(sum);
            }
        }

        /// interactions

        LiquidSplitImpl.initializer(_distributorFee);

        // mint NFTs to initial holders
        uint256 numAccs = accounts.length;
        unchecked {
            for (uint256 i; i < numAccs; ++i) {
                _mint({to: accounts[i], id: TOKEN_ID, amount: initAllocations[i], data: ""});
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external - view & pure
    /// -----------------------------------------------------------------------

    function scaledPercentBalanceOf(address account) internal view override returns (uint32) {
        unchecked {
            // can't overflow; invariant:
            // sum(balanceOf) == TOTAL_SUPPLY = 1e3
            // SUPPLY_TO_PERCENTAGE = 1e6 / 1e3 = 1e3
            // =>
            // sum(balanceOf[i] * SUPPLY_TO_PERCENTAGE) == PERCENTAGE_SCALE = 1e6)
            return uint32(balanceOf[account][TOKEN_ID] * SUPPLY_TO_PERCENTAGE);
        }
    }

    // TODO

    /* function uri(uint256 id) public view override returns (string memory) { */
    function uri(uint256) public pure override returns (string memory) {
        return "uri";
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - private & internal - pure
    /// -----------------------------------------------------------------------

    /// Sums array of uint32s
    /// @param numbers Array of uint32s to sum
    /// @return sum Sum of `numbers`
    function _getSum(uint32[] calldata numbers) internal pure returns (uint32 sum) {
        uint256 numbersLength = numbers.length;
        for (uint256 i; i < numbersLength;) {
            sum += numbers[i];
            unchecked {
                // overflow should be impossible in for-loop index
                ++i;
            }
        }
    }
}
