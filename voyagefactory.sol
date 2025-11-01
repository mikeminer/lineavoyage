// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VoyageFactory {
    event ChildDeployed(address indexed deployer, address child, uint256 value);
    error CreateFailed();

    /// @notice deploy a single ultra-minimal child (runtime = 0x00)
    function deployChild() external payable returns (address child) {
        assembly {
            let ptr := mload(0x40)

            // Store the 5-byte initcode:
            // 0x60 01 60 00 f3
            // PUSH1 0x01  | return 1 byte |
            // PUSH1 0x00  | from memory position 0 |
            // RETURN
            mstore(ptr, 0x60016000f3000000000000000000000000000000000000000000000000000000)
            // ↑ padded to 32 bytes on the right

            // CREATE(msg.value, ptr, 5)
            child := create(callvalue(), ptr, 5)
        }
        if (child == address(0)) revert CreateFailed();
        emit ChildDeployed(msg.sender, child, msg.value);
    }

    /// @notice bounded batch deploy (no value forwarding)
    function deployBatch(uint256 n) external {
        unchecked {
            for (uint256 i = 0; i < n; ++i) {
                address child;
                assembly {
                    let ptr := mload(0x40)
                    mstore(ptr, 0x60016000f3000000000000000000000000000000000000000000000000000000)
                    child := create(0, ptr, 5)
                }
                if (child == address(0)) revert CreateFailed();
            }
            emit ChildDeployed(msg.sender, address(0), 0);
        }
    }
}
