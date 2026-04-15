// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./MerkleRoot.sol";

contract Vesting is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    MerkleRoot public immutable merkleRoot;

    error ScheduleExists();
    error NoSchedule();
    error NothingToRelease();
    error InvalidProof();
    error InsufficientContractBalance();
    error InvalidBeneficiary();
    error InvalidAmount();
    error TransferFailed();

    struct Schedule {
        uint256 totalAmount;
        uint256 released;
        uint256 start;
        uint256 duration;
    }

    mapping(address => uint256) public adminAllocations;
    mapping(address => Schedule) public vestingSchedules;

    uint256 public immutable tokenRate = 10 * 1e18; // 10 tokens per 1 eth

    constructor(address _token, address _root) Ownable(msg.sender) {
        token = IERC20(_token);
        merkleRoot = MerkleRoot(_root);
    }

    function invest(
        bytes32[] calldata proof,
        uint256 duration,
        uint256 start
    ) external payable nonReentrant {
        uint256 tokenAmount = (msg.value * tokenRate) / 1e18;

        if (tokenAmount <= 0) revert InvalidAmount();

        if (
            !merkleRoot.Verify(tokenAmount, proof, start, duration, msg.sender)
        ) {
            revert InvalidProof();
        }

        _addAllocation(msg.sender, tokenAmount);
    }

    function addAllocation(
        address beneficiary,
        uint256 amount
    ) external onlyOwner {
        _addAllocation(beneficiary, amount);
    }

    function _addAllocation(address beneficiary, uint256 amount) internal {
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (amount == 0) revert InvalidAmount();
        adminAllocations[beneficiary] += amount;
    }

    function claimAirdrop(
        uint256 amount,
        uint256 start,
        uint256 duration,
        bytes32[] calldata proof
    ) external nonReentrant {
        if (adminAllocations[msg.sender] != amount) {
            revert InvalidAmount();
        }

        if (!merkleRoot.Verify(amount, proof, start, duration, msg.sender)) {
            revert InvalidProof();
        }

        if (vestingSchedules[msg.sender].totalAmount > 0) {
            revert ScheduleExists();
        }

        vestingSchedules[msg.sender] = Schedule({
            totalAmount: amount,
            released: 0,
            start: start,
            duration: duration
        });

        adminAllocations[msg.sender] = 0;
    }

    function release() external {
        Schedule storage schedule = vestingSchedules[msg.sender];

        if (schedule.totalAmount == 0) {
            revert NoSchedule();
        }

        uint256 vested = _vestedAmount(schedule);
        uint256 releasable = vested - schedule.released;

        if (releasable == 0) {
            revert NothingToRelease();
        }

        if (token.balanceOf(address(this)) < releasable) {
            revert InsufficientContractBalance();
        }

        schedule.released += releasable;
        token.transfer(msg.sender, releasable);
    }

    function _vestedAmount(
        Schedule memory schedule
    ) internal view returns (uint256) {
        if (block.timestamp < schedule.start) return 0;
        if (block.timestamp >= schedule.start + schedule.duration)
            return schedule.totalAmount;

        return
            (schedule.totalAmount * (block.timestamp - schedule.start)) /
            schedule.duration;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}(
            ""
        );
        if (!success) revert TransferFailed();
    }
}
