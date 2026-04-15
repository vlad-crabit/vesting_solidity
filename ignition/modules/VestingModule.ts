import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MERKLE_ROOT =
  "0xdc5df5fbd718781c20ff8021587d245ce4e8c5df9952241a0e6e9c70bf05aa03";
const INITIAL_SUPPLY = 1000000n;

export default buildModule("VestingModule", (m) => {
  const token = m.contract("Token", [INITIAL_SUPPLY]);

  const merkleRootContract = m.contract("MerkleRoot", [MERKLE_ROOT]);

  const vesting = m.contract("Vesting", [token, merkleRootContract]);

  m.call(token, "approve", [vesting, INITIAL_SUPPLY * 10n ** 18n]);

  return { token, merkleRootContract, vesting };
});
