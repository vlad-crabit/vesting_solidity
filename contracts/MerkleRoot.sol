// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
contract MerkleRoot {
    bytes32 public immutable merkleRoot;

    constructor(bytes32 _root) {
        merkleRoot = _root;
    }

    function Verify(
        uint256 totalAmount,
        bytes32[] calldata proof,
        uint256 start,
        uint256 duration,
        address beneficiary
    ) external view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(beneficiary, totalAmount, start, duration))
            )
        );

        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}
