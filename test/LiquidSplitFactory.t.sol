// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibSort} from "solady/utils/LibSort.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

import {LiquidSplitFactory} from "src/LiquidSplitFactory.sol";

contract LiquidSplitFactoryTest is Test {
    error InvalidLiquidSplit__InvalidDistributorFee(uint32 distributorFee);
    error InvalidSplit__InvalidDistributorFee(uint32 distributorFee);

    using SafeTransferLib for address;
    using LibSort for address[];

    event ReceiveETH(uint256 amount);

    uint256 constant BLOCK_NUMBER = 15619912;
    uint256 constant GAS_BLOCK_LIMIT = 30_000_000;

    uint256 constant PERCENTAGE_SCALE = 1e6;
    uint32 constant MAX_DISTRIBUTOR_FEE = 1e5; // = 10% * PERCENTAGE_SCALE
    uint256 constant TOTAL_SUPPLY = 1e3;
    address constant ETH_ADDRESS = address(0);
    uint256 constant TOKEN_ID = 0;

    ISplitMain public splitMain = ISplitMain(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
    MockERC20 public mERC20;
    LiquidSplitFactory public lsf;

    address[] public accounts;
    uint32[] public initAllocations;
    uint32 public distributorFee;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(MAINNET_RPC_URL, BLOCK_NUMBER);

        accounts = new address[](2);
        accounts[0] = makeAddr("0xSplits.alice");
        accounts[1] = makeAddr("0xSplits.bob");

        initAllocations = new uint32[](2);
        initAllocations[0] = uint32(500);
        initAllocations[1] = uint32(500);

        distributorFee = 0;

        lsf = new LiquidSplitFactory(address(splitMain));
    }

    /// -----------------------------------------------------------------------
    /// gas tests
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// gas tests - LS1155
    /// -----------------------------------------------------------------------

    function testGas_create1_base() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(1);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create10_base() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(10);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create100_base() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(100);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create1000_base() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(1000);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    /// -----------------------------------------------------------------------
    /// gas tests - LS1155Clone
    /// -----------------------------------------------------------------------

    function testGas_create1_clone() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(1);
        lsf.createLiquidSplitClone({
            accounts: accounts_,
            initAllocations: initAllocations_,
            _distributorFee: distributorFee
        });
    }

    function testGas_create10_clone() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(10);
        lsf.createLiquidSplitClone({
            accounts: accounts_,
            initAllocations: initAllocations_,
            _distributorFee: distributorFee
        });
    }

    function testGas_create100_clone() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(100);
        lsf.createLiquidSplitClone({
            accounts: accounts_,
            initAllocations: initAllocations_,
            _distributorFee: distributorFee
        });
    }

    function testGas_create1000_clone() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(1000);
        lsf.createLiquidSplitClone({
            accounts: accounts_,
            initAllocations: initAllocations_,
            _distributorFee: distributorFee
        });
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - basic
    /// -----------------------------------------------------------------------

    function testCan_createLS1155_base() public {
        lsf.createLiquidSplit({
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: MAX_DISTRIBUTOR_FEE
        });
    }

    function testCan_createLS1155_clone() public {
        lsf.createLiquidSplitClone({
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: MAX_DISTRIBUTOR_FEE
        });
    }

    function testCannot_createLS1155WithTooLargeDistributorFee_base() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidSplit__InvalidDistributorFee.selector, MAX_DISTRIBUTOR_FEE + 1));
        lsf.createLiquidSplit({
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: MAX_DISTRIBUTOR_FEE + 1
        });
    }

    function testCannot_createLS1155WithTooLargeDistributorFee_clone() public {
        vm.expectRevert(
            abi.encodeWithSelector(InvalidLiquidSplit__InvalidDistributorFee.selector, MAX_DISTRIBUTOR_FEE + 1)
        );
        lsf.createLiquidSplitClone({
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: MAX_DISTRIBUTOR_FEE + 1
        });
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - fuzzing
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// helpers
    /// -----------------------------------------------------------------------

    // TOTAL_SUPPLY must be divisible by `size`

    function setupSplit(uint256 size)
        internal
        pure
        returns (address[] memory accounts_, uint32[] memory initAllocations_)
    {
        accounts_ = new address[](size);
        initAllocations_ = new uint32[](size);
        uint160 account = uint160(type(uint256).max - TOTAL_SUPPLY);
        uint32 initAllocation = uint32(TOTAL_SUPPLY / size);
        for (uint160 i = 0; i < accounts_.length; i++) {
            accounts_[i] = address(account + i);
            initAllocations_[i] = initAllocation;
        }
    }
}
