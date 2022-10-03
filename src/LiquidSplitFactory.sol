// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {LS1155} from "./LS1155.sol";
import {LS1155Impl} from "./LS1155Impl.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title LiquidSplitFactory
/// @author 0xSplits
// TODO
/// @notice A factory contract for cheaply deploying LiquidSplits.
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

    // TODO: want creator?
    event CreateLS1155(LS1155 indexed ls, address indexed creator);

    // TODO: want creator?
    event CreateLS1155Clone(LS1155Impl indexed ls, address indexed creator);

    /// -----------------------------------------------------------------------
    /// storage
    /// -----------------------------------------------------------------------

    address public immutable splitMain;
    address public immutable ls1155Impl;

    /// -----------------------------------------------------------------------
    /// constructor
    /// -----------------------------------------------------------------------

    constructor(address _splitMain) {
        /// checks

        /// effects

        splitMain = _splitMain;
        ls1155Impl = address(new LS1155Impl(_splitMain));

        /// interactions
    }

    /// -----------------------------------------------------------------------
    /// functions
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// functions - public & external
    /// -----------------------------------------------------------------------

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
        emit CreateLS1155(ls, msg.sender);
    }

    function createLiquidSplitClone(
        address[] memory accounts, // vs calldata
        uint32[] memory initAllocations, // vs calldata
        uint32 _distributorFee
    ) external returns (LS1155Impl ls) {
        ls = LS1155Impl(ls1155Impl.clone(""));
        emit CreateLS1155Clone(ls, msg.sender);
        ls.initializer({accounts: accounts, initAllocations: initAllocations, _distributorFee: _distributorFee});
    }
}
