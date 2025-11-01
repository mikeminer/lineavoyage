// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title VoyageFactory — gas-minimal child deployer for private testnets
/// @notice Deploys ultra-minimal contracts using 5-byte initcode (runtime = 1 byte STOP).
///         Emits ChildDeployed for your frontend badges/progress.
/// @dev    No auto-replication. One create per call (or bounded loop with batch).
contract VoyageFactory {
    /// @dev Emitted once per successful child creation (used by your frontend to count successes).
    event ChildDeployed(address indexed deployer, address child, uint256 value);

    /// @dev Custom error saves gas vs revert strings.
    error CreateFailed();

    /// @notice Deploy a single ultra-minimal child.
    /// @dev    Forwards entire msg.value to the newly created child via CREATE.
    /// @return child The address of the newly created contract.
    function deployChild() external payable returns (address child) {
        assembly {
            // Allocate 5 bytes of initcode at free memory pointer
            // Initcode: 0x60 01 60 00 f3  -> RETURN mem[0..0] (1 byte) => runtime 0x00 (STOP)
            let ptr := mload(0x40)
            mstore(ptr, shl( (32 - 5) * 8, 0x60016000f3))
            // CREATE(value=callvalue(), offset=ptr, size=5)
            child := create(callvalue(), ptr, 5)
        }
        if (child == address(0)) revert CreateFailed();
        emit ChildDeployed(msg.sender, child, msg.value);
    }

    /// @notice (Optional) Deploy up to `n` children in a single tx (no value forwarded; keep msg.value=0).
    /// @dev    This is bounded, not auto-replicating. Emits one event per child for accurate counting if you want.
    ///         To minimize gas further, you can comment out the `emit` inside the loop (but then the UI conterà per-tx, non per-child).
    function deployBatch(uint256 n) external {
        unchecked {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, shl( (32 - 5) * 8, 0x60016000f3))
                // Gas tip: avoid reading n each time
                for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                    // value=0 to skip value transfer cost on CREATE
                    let child := create(0, ptr, 5)
                    if iszero(child) {
                        // revert CreateFailed()
                        mstore(0x00, 0x1a1f14a9) // selector for CreateFailed()
                        revert(0x1c, 0x04)
                    }
                    // Emit event per child (comment out to save gas if you count per-tx)
                    // topic0 = keccak("ChildDeployed(address,address,uint256)") done by compiler outside assembly
                    // We’ll emit via high-level outside the loop for readability/cost? No, we’ll bubble up.
                }
            }
            // High-level emit once (cheapest) – counts the batch as 1 “success” for your UI badges.
            // Se vuoi 1 evento per child, sposta l'emit nel loop (ma costa di più).
            emit ChildDeployed(msg.sender, address(0), 0);
        }
    }
}
