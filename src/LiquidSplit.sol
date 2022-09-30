// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";

/// @title LiquidSplit
/// @author 0xSplits
/// @notice An abstract liquid split base (ownership in a split is represented by 1155s).
/// Each 1155 = 0.1% of the split.
/// @dev This contract uses token = address(0) to refer to ETH.
abstract contract LiquidSplit {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

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
    uint256 public constant PERCENTAGE_SCALE = 1e6;
    uint256 public constant MAX_DISTRIBUTOR_FEE = 1e5; // = 10% * PERCENTAGE_SCALE

    ISplitMain public immutable splitMain;
    uint32 public immutable distributorFee;
    address public immutable payoutSplit;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _splitMain,
        uint32 _distributorFee
    ) {
        /// checks

        if (_distributorFee > MAX_DISTRIBUTOR_FEE) {
            revert InvalidLiquidSplit__InvalidDistributorFee(_distributorFee);
        }

        /// effects

        splitMain = ISplitMain( _splitMain ); /*Establish interface to splits contract*/
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
        payoutSplit = payable(
            splitMain.createSplit({
                accounts: recipients,
                percentAllocations: initPercentAllocations,
                distributorFee: 0,
                controller: address(this)
            })
        );
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    /// emit event when receiving ETH
    /// @dev implemented w/i clone bytecode
    receive() external virtual payable {
        emit ReceiveETH(msg.value);
    }

    /// distributes ETH & ERC20s to NFT holders
    /// @param token ETH (0x0) or ERC20 token to distribute
    /// @param accounts Ordered, unique list of NFT holders
    /// @param distributorAddress Address to receive distributorFee
    function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external virtual {
        uint256 numRecipients = accounts.length;
        uint32[] memory percentAllocations = new uint32[](numRecipients);
            for (uint256 i; i < numRecipients; ) {
                percentAllocations[i] = scaledPercentBalanceOf(accounts[i]);
                unchecked {
                    ++i;
            }
        }

        // atomically deposit funds, update recipients to reflect current NFT holders, and distribute
        if (token == ETH_ADDRESS) {
            payoutSplit.safeTransferETH(address(this).balance);
            splitMain.updateAndDistributeETH({
                split: payoutSplit,
                accounts: accounts,
                percentAllocations: percentAllocations,
                distributorFee: distributorFee,
                distributorAddress: distributorAddress
            });
        } else {
            token.safeTransfer(payoutSplit, ERC20(token).balanceOf(address(this)));
            splitMain.updateAndDistributeERC20({
                split: payoutSplit,
                token: ERC20(token),
                accounts: accounts,
                percentAllocations: percentAllocations,
                distributorFee: distributorFee,
                distributorAddress: distributorAddress
            });
        }
    }

    /// -----------------------------------------------------------------------
    /// functions - public & external - view & pure
    /// -----------------------------------------------------------------------

    function scaledPercentBalanceOf(address account) internal view virtual returns (uint32) {}
}
