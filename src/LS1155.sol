// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/BokkyPooBahsDateTimeLibrary.sol";

import {LiquidSplit} from "src/LiquidSplit.sol";
import {Renderer} from "src/libs/Renderer.sol";

/// @title 1155LiquidSplit
/// @author 0xSplits
/// @notice A minimal liquid splits implementation.
/// Ownership in a split is represented by 1155s (each = 0.1% of split)
/// @dev This contract uses token = address(0) to refer to ETH.
contract LS1155 is Owned, LiquidSplit, ERC1155 {
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
    /// libraries
    /// -----------------------------------------------------------------------

    using LibString for uint256;

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 internal constant TOKEN_ID = 0;
    uint256 public constant TOTAL_SUPPLY = 1e3;
    uint256 public constant SUPPLY_TO_PERCENTAGE = 1e3; // = PERCENTAGE_SCALE / TOTAL_SUPPLY = 1e6 / 1e3

    uint256 public immutable mintedOnTimestamp;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _splitMain,
        address[] memory accounts,
        uint32[] memory initAllocations,
        uint32 _distributorFee,
        address _owner
    ) Owned(_owner) LiquidSplit(_splitMain, _distributorFee) {
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

        /// effects

        mintedOnTimestamp = block.timestamp;

        /// interactions

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

    function scaledPercentBalanceOf(address account) public view override returns (uint32) {
        unchecked {
            // can't overflow; invariant:
            // sum(balanceOf) == TOTAL_SUPPLY = 1e3
            // SUPPLY_TO_PERCENTAGE = 1e6 / 1e3 = 1e3
            // =>
            // sum(balanceOf[i] * SUPPLY_TO_PERCENTAGE) == PERCENTAGE_SCALE = 1e6)
            return uint32(balanceOf[account][TOKEN_ID] * SUPPLY_TO_PERCENTAGE);
        }
    }

    function uri(uint256) public view override returns (string memory) {
        string memory contractAddr = uint256(uint160(address(this))).toString();
        (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(mintedOnTimestamp);
        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "0sSplits Liquid Split (',
                        contractAddr,
                        ')", "image": "data:image/svg+xml;base64,',
                        Base64.encode(
                            bytes(
                                Renderer.render({
                                    contractAddress: contractAddr,
                                    chainId: block.chainid.toString(),
                                    mintedOnDate: string(
                                        abi.encodePacked(year.toString(), "-", month.toString(), "-", day.toString())
                                        )
                                })
                            )
                        ),
                        "}"
                    )
                )
            )
        );
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
    function _getSum(uint32[] memory numbers) internal pure returns (uint32 sum) {
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
