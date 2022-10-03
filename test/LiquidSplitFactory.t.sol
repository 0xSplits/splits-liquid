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
    using SafeTransferLib for address;
    using LibSort for address[];

    event ReceiveETH(uint256 amount);

    uint256 constant BLOCK_NUMBER = 15619912;
    uint256 constant GAS_BLOCK_LIMIT = 30_000_000;

    uint256 constant PERCENTAGE_SCALE = 1e6;
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

    function testGas_create1() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(1);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create10() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(10);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create100() public {
        (address[] memory accounts_, uint32[] memory initAllocations_) = setupSplit(100);
        lsf.createLiquidSplit({accounts: accounts_, initAllocations: initAllocations_, _distributorFee: distributorFee});
    }

    function testGas_create1000() public {
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

    // transfer

    // distribute 2
    // distribute 10
    // distribute 100
    // distribute 1000

    /// -----------------------------------------------------------------------
    /// correctness tests - basic
    /// -----------------------------------------------------------------------

    function testCan_createLS1155() public {
        lsf.createLiquidSplit({accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee});
    }

    function testCan_createLS1155Clone() public {
        lsf.createLiquidSplitClone({
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: distributorFee
        });
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - fuzzing
    /// -----------------------------------------------------------------------

    // create n

    // distribute n

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
        for (uint256 i = 0; i < accounts_.length; i++) {
            accounts_[i] = address(uint160(type(uint256).max - TOTAL_SUPPLY + i));
            initAllocations_[i] = uint32(TOTAL_SUPPLY / size);
        }
    }
}
