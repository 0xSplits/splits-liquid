// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {LS1155} from "./LS1155.sol";
import {LS1155CloneImpl} from "./CloneImpl/LS1155CloneImpl.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title LiquidSplitFactory
/// @author 0xSplits
/// @notice A factory contract for deploying 0xSplits' minimal liquid splits.
contract LiquidSplitFactory {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

    /// Invalid distributorFee: `distributorFee` cannot be greater than `MAX_DISTRIBUTOR_FEE`
    /// @param distributorFee Invalid distributorFee amount
    error InvalidLiquidSplit__InvalidDistributorFee(uint32 distributorFee);

    /// -----------------------------------------------------------------------
    /// libraries
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// events
    /// -----------------------------------------------------------------------

    event CreateLS1155(LS1155 indexed ls);

    event CreateLS1155Clone(LS1155CloneImpl indexed ls);

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    uint256 public constant MAX_DISTRIBUTOR_FEE = 1e5; // = 10% * PERCENTAGE_SCALE

    address public immutable splitMain;
    address public immutable ls1155CloneImpl;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(address _splitMain) {
        /// checks

        /// effects

        splitMain = _splitMain;

        /// interactions

        ls1155CloneImpl = address(new LS1155CloneImpl(_splitMain));
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    function createLiquidSplit(address[] calldata accounts, uint32[] calldata initAllocations, uint32 _distributorFee)
        external
        returns (LS1155 ls)
    {
        /// checks

        // params are validated inside LS1155 constructor

        /// effects

        /// interactions
        ls = new LS1155({
            _splitMain: splitMain,
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: _distributorFee
            });
        emit CreateLS1155(ls);
    }

    function createLiquidSplitClone(
        address[] calldata accounts,
        uint32[] calldata initAllocations,
        uint32 _distributorFee
    ) external returns (LS1155CloneImpl ls) {
        /// checks

        // accounts & initAllocations are validated inside initializer

        if (_distributorFee > MAX_DISTRIBUTOR_FEE) {
            revert InvalidLiquidSplit__InvalidDistributorFee(_distributorFee);
        }

        /// effects

        /// interactions

        ls = LS1155CloneImpl(ls1155CloneImpl.clone(abi.encodePacked(_distributorFee)));
        emit CreateLS1155Clone(ls);
        ls.initializer({accounts: accounts, initAllocations: initAllocations});
    }
}
