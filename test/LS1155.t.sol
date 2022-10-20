// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibSort} from "solady/utils/LibSort.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

import {LS1155} from "src/LS1155.sol";

contract LS1155Test is Test {
    using SafeTransferLib for address;
    using LibSort for address[];

    event CreateLiquidSplit(address indexed payoutSplit);
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event ReceiveETH(uint256 amount);

    uint256 constant BLOCK_NUMBER = 15619912;
    uint256 constant GAS_BLOCK_LIMIT = 30_000_000;

    uint256 constant PERCENTAGE_SCALE = 1e6;
    uint256 constant TOTAL_SUPPLY = 1e3;
    address constant ETH_ADDRESS = address(0);
    uint256 constant TOKEN_ID = 0;

    ISplitMain public splitMain = ISplitMain(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
    MockERC20 public mERC20;
    LS1155 public ls;

    address[] public accounts;
    uint32[] public initAllocations;
    uint32 public distributorFee;
    address public owner;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(MAINNET_RPC_URL, BLOCK_NUMBER);

        mERC20 = new MockERC20("Test Token", "TOK", 18);
        mERC20.mint(type(uint256).max);

        accounts = new address[](2);
        accounts[0] = makeAddr("0xSplits.alice");
        accounts[1] = makeAddr("0xSplits.bob");

        initAllocations = new uint32[](2);
        initAllocations[0] = uint32(500);
        initAllocations[1] = uint32(500);

        distributorFee = 0;

        owner = address(this);

        ls =
        new LS1155{salt: keccak256(bytes("0xSplits.liquid.test"))}({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - creation
    /// -----------------------------------------------------------------------

    function testCan_setOwnerOnCreation() public {
        assertEq(address(this), ls.owner());
    }

    function testCan_setNoOwnerOnCreation() public {
        owner = address(0);

        ls =
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        assertEq(address(0), ls.owner());
    }

    function testCan_emitOnCreation() public {
        vm.expectEmit(false, true, true, true);
        emit CreateLiquidSplit(address(this));

        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), address(this));

        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: address(this) });
    }

    function testCan_allocateToSafe721Recipient() public {
        accounts[0] = address(new ERC1155Recipient());
        accounts[1] = makeAddr("0xSplits.bob");

        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    function testCannot_allocateToZeroAddress() public {
        address account = accounts[0];
        accounts[0] = address(0);

        vm.expectRevert("UNSAFE_RECIPIENT");
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        accounts[0] = account;
        accounts[1] = address(0);

        vm.expectRevert("UNSAFE_RECIPIENT");
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    function testCannot_allocateToNon721Recipient() public {
        address account = accounts[0];
        accounts[0] = address(new NonERC1155Recipient());

        vm.expectRevert();
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        accounts[0] = account;
        accounts[1] = address(new NonERC1155Recipient());

        vm.expectRevert();
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    function testCannot_allocateToUnsafe721Recipient() public {
        address account = accounts[0];
        accounts[0] = address(new WrongReturnDataERC1155Recipient());

        vm.expectRevert("UNSAFE_RECIPIENT");
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        accounts[0] = account;
        accounts[1] = address(new WrongReturnDataERC1155Recipient());

        vm.expectRevert("UNSAFE_RECIPIENT");
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    function testCannot_allocateToReverting721Recipient() public {
        address account = accounts[0];
        accounts[0] = address(new RevertingERC1155Recipient());

        vm.expectRevert(abi.encodeWithSelector(ERC1155TokenReceiver.onERC1155Received.selector));
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        accounts[0] = account;
        accounts[1] = address(new RevertingERC1155Recipient());

        vm.expectRevert(abi.encodeWithSelector(ERC1155TokenReceiver.onERC1155Received.selector));
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - basic
    /// -----------------------------------------------------------------------

    function testCan_transferOwnership() public {
        assertEq(address(this), ls.owner());

        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(this), address(0));

        ls.transferOwnership(address(0));

        assertEq(address(0), ls.owner());
    }

    function testCannot_transferOwnershipByNonOwner() public {
        assertEq(address(this), ls.owner());

        vm.prank(address(0xDEADBEEF));
        vm.expectRevert("UNAUTHORIZED");
        ls.transferOwnership(address(0));

        assertEq(address(this), ls.owner());
    }

    function testCan_receiveETH() public {
        address(ls).safeTransferETH(1 ether);
        assertEq(address(ls).balance, 1 ether);
    }

    function testCan_emitOnReceiveETH() public {
        vm.expectEmit(true, true, true, true);
        emit ReceiveETH(1 ether);

        address(ls).safeTransferETH(1 ether);
    }

    function testCan_receiveTransfer() public {
        payable(address(ls)).transfer(1 ether);
        assertEq(address(ls).balance, 1 ether);
    }

    function testCan_receiveERC20() public {
        address(mERC20).safeTransfer(address(ls), 1 ether);
        assertEq(mERC20.balanceOf(address(ls)), 1 ether);
    }

    function testCan_callUpdateAndDistribute() public {
        address[] memory _accounts = accounts;
        _accounts.sort();
        _accounts.uniquifySorted();

        address(ls).safeTransferETH(1 ether);
        vm.expectCall(address(splitMain), abi.encodeWithSelector(splitMain.updateAndDistributeETH.selector));
        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));

        address(mERC20).safeTransfer(address(ls), 1 ether);
        vm.expectCall(address(splitMain), abi.encodeWithSelector(splitMain.updateAndDistributeERC20.selector));
        ls.distributeFunds(address(mERC20), _accounts, address(this));
    }

    function testCan_distributeToTwoHolders() public {
        address[] memory _accounts = accounts;
        _accounts.sort();
        _accounts.uniquifySorted();

        address(ls).safeTransferETH(1 ether);
        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getETHBalance(_accounts[i]), 0.5 ether);
        }

        address(mERC20).safeTransfer(address(ls), 1 ether);
        ls.distributeFunds(address(mERC20), _accounts, address(this));
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getERC20Balance(_accounts[i], mERC20), (uint256(1 ether) - 1) / 2);
        }
    }

    function testCannot_distributeToSingleHolder() public {
        vm.prank(accounts[1]);
        ls.safeTransferFrom(accounts[1], accounts[0], TOKEN_ID, 500, "");

        address[] memory _accounts = new address[](1);
        _accounts[0] = accounts[0];

        address(ls).safeTransferETH(1 ether);
        vm.expectRevert(abi.encodeWithSelector(ISplitMain.InvalidSplit__TooFewAccounts.selector, 1));
        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));
    }

    function testCan_distributeToCurrentHolders() public {
        address(ls).safeTransferETH(4 ether);

        accounts.push(makeAddr("0xSplits.charlie"));
        accounts.push(makeAddr("0xSplits.don"));

        vm.prank(accounts[0]);
        ls.safeTransferFrom(accounts[0], accounts[2], TOKEN_ID, 250, "");
        vm.prank(accounts[1]);
        ls.safeTransferFrom(accounts[1], accounts[3], TOKEN_ID, 250, "");

        address[] memory _accounts = accounts;
        _accounts.sort();
        _accounts.uniquifySorted();

        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getETHBalance(_accounts[i]), 1 ether);
        }

        address(mERC20).safeTransfer(address(ls), 4 ether);
        ls.distributeFunds(address(mERC20), _accounts, address(this));
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getERC20Balance(_accounts[i], mERC20), uint256(1 ether) - 1);
        }
    }

    function testCan_distributeToMaxUniqueHolders() public {
        accounts = new address[](TOTAL_SUPPLY);
        initAllocations = new uint32[](TOTAL_SUPPLY);
        for (uint256 i = 0; i < accounts.length; i++) {
            accounts[i] = address(uint160(type(uint256).max - TOTAL_SUPPLY + i));
            initAllocations[i] = uint32(1);
        }

        address[] memory _accounts = accounts;
        uint32[] memory _initAllocations = initAllocations;

        ls =
        new LS1155({ _splitMain: address(splitMain), accounts: _accounts, initAllocations: _initAllocations, _distributorFee: distributorFee, _owner: owner });

        address(ls).safeTransferETH(TOTAL_SUPPLY * 1 ether);
        uint256 gasStart = gasleft();
        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));
        assert(gasStart - gasleft() < GAS_BLOCK_LIMIT);
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getETHBalance(_accounts[i]), 1 ether);
        }

        address(mERC20).safeTransfer(address(ls), TOTAL_SUPPLY * 1 ether);
        gasStart = gasleft();
        ls.distributeFunds(address(mERC20), _accounts, address(this));
        assert(gasStart - gasleft() < GAS_BLOCK_LIMIT);
        for (uint256 i = 0; i < _accounts.length; i++) {
            assertEq(splitMain.getERC20Balance(_accounts[i], mERC20), uint256(1 ether) - 1);
        }
    }

    function testCan_payDistributorFee() public {
        distributorFee = uint32(PERCENTAGE_SCALE / 10); // = 10%

        ls =
        new LS1155({ _splitMain: address(splitMain), accounts: accounts, initAllocations: initAllocations, _distributorFee: distributorFee, _owner: owner });

        address[] memory _accounts = accounts;
        _accounts.sort();
        _accounts.uniquifySorted();

        address(ls).safeTransferETH(10 ether);
        vm.expectCall(address(splitMain), abi.encodeWithSelector(splitMain.updateAndDistributeETH.selector));
        ls.distributeFunds(ETH_ADDRESS, _accounts, address(this));
        assertEq(splitMain.getETHBalance(address(this)), 1 ether);

        address(mERC20).safeTransfer(address(ls), 10 ether);
        vm.expectCall(address(splitMain), abi.encodeWithSelector(splitMain.updateAndDistributeERC20.selector));
        ls.distributeFunds(address(mERC20), _accounts, address(this));
        assertEq(splitMain.getERC20Balance(address(this), mERC20), uint256(1 ether) - 1);
    }

    /// -----------------------------------------------------------------------
    /// correctness tests - fuzzing
    /// -----------------------------------------------------------------------

    function testCan_storeMintedOnTimestamp(uint128 tsStart, uint128 tsSkip) public {
        vm.warp(tsStart);

        ls = new LS1155({
            _splitMain: address(splitMain),
            accounts: accounts,
            initAllocations: initAllocations,
            _distributorFee: distributorFee,
            _owner: owner
            });

        skip(tsSkip);

        assertEq(tsStart, ls.mintedOnTimestamp());
    }
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }
}

contract NonERC1155Recipient {}

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        revert(string(abi.encodePacked(ERC1155TokenReceiver.onERC1155Received.selector)));
    }
}

contract WrongReturnDataERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        override
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }
}
