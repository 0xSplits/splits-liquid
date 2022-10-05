// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {LS1155} from "./LS1155.sol";
import {LS1155CloneImpl} from "./CloneImpl/LS1155CloneImpl.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title LiquidSplitFactory
/// @author 0xSplits
/// @notice A factory contract for deploying liquid splits.
/// @dev This factory uses our own extension of clones-with-immutable-args to avoid
/// `DELEGATECALL` inside `receive()` to accept hard gas-capped `sends` & `transfers`
/// for maximum backwards composability.
contract LiquidSplitFactory {
    /// -----------------------------------------------------------------------
    /// errors
    /// -----------------------------------------------------------------------

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

    address public immutable splitMain;
    address public immutable ls1155CloneImpl;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(address _splitMain) {
        /// checks

        /// effects

        splitMain = _splitMain;
        ls1155CloneImpl = address(new LS1155CloneImpl(_splitMain));

        /// interactions
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

    // TODO: verify subgraph can pull xfer events to reconstruct accounts & initAllocations
    // TODO: verify subgraph can pull distributorFee from contract

    // TODO: memory vs calldata

    function createLiquidSplit(
        address[] memory accounts, // vs calldata
        uint32[] memory initAllocations, // vs calldata
        uint32 _distributorFee
    ) external returns (LS1155 ls) {
        ls = new LS1155({
            _splitMain: splitMain,
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: _distributorFee
        });
        emit CreateLS1155(ls);
    }

    function createLiquidSplitClone(
        address[] memory accounts, // vs calldata
        uint32[] memory initAllocations, // vs calldata
        uint32 _distributorFee
    ) external returns (LS1155CloneImpl ls) {
        ls = LS1155CloneImpl(ls1155CloneImpl.clone(""));
        emit CreateLS1155Clone(ls);
        ls.initializer({accounts: accounts, initAllocations: initAllocations, _distributorFee: _distributorFee});
    }
}
