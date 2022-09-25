// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {ISplitMain} from "splits-contracts/interfaces/ISplitMain.sol";
import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title LiquidSplit
/// @author 0xSplits
/// @notice TODO
/// @dev This contract uses token = address(0) to refer to ETH.
contract LiquidSplit is ERC1155 {
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

    /// Invalid distributorFee `distributorFee` cannot be greater than `MAX_DISTRIBUTOR_FEE`
    /// @param distributorFee Invalid distributorFee amount
    error InvalidLiquidSplit__InvalidDistributorFee(uint32 distributorFee);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    /// Emitted after each successful ETH transfer to proxy
    /// @param amount Amount of ETH received
    /// @dev embedded in & emitted from clone bytecode
    event ReceiveETH(uint256 amount);

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant TOKEN_ID = 0;
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    uint256 public constant MAX_DISTRIBUTOR_FEE = 1e5; // = 10% * PERCENTAGE_SCALE
    uint256 public constant TOTAL_SUPPLY = 1e3;
    uint256 public constant SUPPLY_TO_PERCENTAGE = 1e3; // = PERCENTAGE_SCALE / TOTAL_SUPPLY;

    ISplitMain public immutable splitMain;
    uint256 public immutable distributorFee;
    address public immutable payoutSplit;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    // TODO: gas check vs manual uint32 check

    constructor(
        ISplitMain _splitMain,
        address[] calldata accounts,
        uint32[] calldata initAllocations,
        uint32 _distributorFee
    ) {
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

        if (_distributorFee > MAX_DISTRIBUTOR_FEE) {
            revert InvalidLiquidSplit__InvalidDistributorFee(distributorFee);
        }

        /// effects

        splitMain = _splitMain; /*Establish interface to splits contract*/
        distributorFee = _distributorFee;

        /// interactions

        // create dummy mutable split with this contract as controller;
        // recipients & distributorFee will be updated on first payout
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);
        recipients[1] = address(1);
        uint32[] memory initPercentAllocations = new uint32[](2);
        initPercentAllocations[0] = uint32(500000);
        initPercentAllocations[1] = uint32(500000);
        payoutSplit = payable(splitMain.createSplit(recipients, initPercentAllocations, 0, address(this)));

        // mint NFTs to initial holders
        uint256 numAccs = accounts.length;
        unchecked {
            for (uint256 i; i < numAccs; ++i) {
                _mint(accounts[i], TOKEN_ID, initAllocations[i], "");
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// emit event when receiving ETH
    /// @dev implemented w/i clone bytecode
    receive() external payable {
        emit ReceiveETH(msg.value);
    }

    /// distributes ETH & ERC20s to NFT holders
    /// @param token ETH (0x0) or ERC20 token to distribute
    /// @param accounts Ordered, unique list of NFT holders
    /// @param distributorAddress Address to receive distributorFee
    function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external {
        uint256 numRecipients = accounts.length;
        uint32[] memory percentAllocations = new uint32[](numRecipients);
        unchecked {
            for (uint256 i; i < numRecipients; ++i) {
                percentAllocations[i] = balanceOf[accounts[i]][TOKEN_ID] * SUPPLY_TO_PERCENTAGE;
            }
        }

        // atomically deposit funds, update recipients to reflect current NFT holders, and distribute
        if (token == ETH_ADDRESS) {
            payoutSplit.safeTransferETH(address(this).balance);
            splitMain.updateAndDistributeETH(
                payoutSplit, accounts, percentAllocations, distributorFee, distributorAddress
            );
        } else {
            token.safeTransfer(payoutSplit, ERC20(token).balanceOf(address(this)));
            splitMain.updateAndDistributeERC20(
                payoutSplit, ERC20(token), accounts, percentAllocations, distributorFee, distributorAddress
            );
        }
    }

    /// -----------------------------------------------------------------------
    /// functions - private & internal
    /// -----------------------------------------------------------------------

    /// Sums array of uint32s
    /// @param numbers Array of uint32s to sum
    /// @return sum Sum of `numbers`.
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
