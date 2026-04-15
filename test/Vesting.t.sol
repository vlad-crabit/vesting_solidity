// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/Vesting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VestingTest is Test {
    Vesting vesting;
    MockERC20 token;
    MockMerkleRoot merkle;

    address user = address(1);

    function setUp() public {
        token = new MockERC20();
        merkle = new MockMerkleRoot();

        vesting = new Vesting(address(token), address(merkle));

        token.mint(address(vesting), 1_000_000 ether);
    }

    function testInvestSuccess() public {
        vm.deal(user, 1 ether);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.invest{value: 1 ether}(proof, 1000, 0);

        uint256 allocation = vesting.adminAllocations(user);
        assertEq(allocation, 10 ether);
    }

    function testInvestRevertInvalidProof() public {
        merkle.setVerify(false);
        vm.deal(user, 1 ether);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vm.expectRevert(Vesting.InvalidProof.selector);
        vesting.invest{value: 1 ether}(proof, 1000, 0);
    }

    function testInvestRevertInvalidAmount() public {
        bytes32[] memory proof = new bytes32[](1);
        vm.prank(user);
        vm.expectRevert(Vesting.InvalidAmount.selector);
        vesting.invest{value: 0}(proof, 1000, 0);
    }

    function testAddAllocation() public {
        vesting.addAllocation(user, 100);
        assertEq(vesting.adminAllocations(user), 100);
    }

    function testAddAllocationRevertZeroAddress() public {
        vm.expectRevert(Vesting.InvalidBeneficiary.selector);
        vesting.addAllocation(address(0), 100);
    }

    function testAddAllocationRevertZeroAmount() public {
        vm.expectRevert(Vesting.InvalidAmount.selector);
        vesting.addAllocation(user, 0);
    }

    function testClaimAirdropSuccess() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, 0, 1000, proof);

        (uint total, , , ) = vesting.vestingSchedules(user);
        assertEq(total, 100);
    }

    function testClaimAirdropRevertInvalidAmount() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vm.expectRevert(Vesting.InvalidAmount.selector);
        vesting.claimAirdrop(50, 0, 1000, proof);
    }

    function testClaimAirdropRevertInvalidProof() public {
        vesting.addAllocation(user, 100);
        merkle.setVerify(false);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vm.expectRevert(Vesting.InvalidProof.selector);
        vesting.claimAirdrop(100, 0, 1000, proof);
    }

    function testClaimAirdropRevertScheduleExists() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, 0, 1000, proof);

        vesting.addAllocation(user, 100);

        vm.prank(user);
        vm.expectRevert(Vesting.ScheduleExists.selector);
        vesting.claimAirdrop(100, 0, 1000, proof);
    }

    function testReleaseRevertNoSchedule() public {
        vm.prank(user);
        vm.expectRevert(Vesting.NoSchedule.selector);
        vesting.release();
    }

    function testReleaseRevertNothingToRelease() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, block.timestamp + 1000, 1000, proof);

        vm.prank(user);
        vm.expectRevert(Vesting.NothingToRelease.selector);
        vesting.release();
    }

    function testReleasePartial() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, block.timestamp, 1000, proof);

        vm.warp(block.timestamp + 500);

        vm.prank(user);
        vesting.release();

        assertGt(token.balanceOf(user), 0);
    }

    function testReleaseFull() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, block.timestamp, 1000, proof);

        vm.warp(block.timestamp + 2000);

        vm.prank(user);
        vesting.release();

        assertEq(token.balanceOf(user), 100);
    }

    function testReleaseRevertInsufficientBalance() public {
        vesting.addAllocation(user, 100);
        bytes32[] memory proof = new bytes32[](1);

        vm.prank(user);
        vesting.claimAirdrop(100, block.timestamp, 1, proof);

        deal(address(token), address(vesting), 0);
        vm.warp(block.timestamp + 2);

        vm.prank(user);
        vm.expectRevert(Vesting.InsufficientContractBalance.selector);
        vesting.release();
    }

    receive() external payable {}

    function testWithdraw() public {
        vm.deal(user, 1 ether);
        bytes32[] memory proof = new bytes32[](1);
        vm.prank(user);
        vesting.invest{value: 1 ether}(proof, 1000, 0);

        uint256 beforeBal = address(this).balance;

        vesting.withdraw();

        assertGt(address(this).balance, beforeBal);
    }

    function testWithdrawTransferFailed() public {
        Rejector r = new Rejector();

        Vesting v = new Vesting(address(token), address(merkle));

        vm.prank(v.owner());
        v.transferOwnership(address(r));

        vm.deal(address(v), 1 ether);
        vm.expectRevert(Vesting.TransferFailed.selector);
        vm.prank(address(r));
        v.withdraw();
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockMerkleRoot {
    bool public shouldVerify = true;

    function setVerify(bool value) external {
        shouldVerify = value;
    }

    function Verify(
        uint256,
        bytes32[] calldata,
        uint256,
        uint256,
        address
    ) external view returns (bool) {
        return shouldVerify;
    }
}

contract Rejector {
    receive() external payable {
        revert();
    }
}
