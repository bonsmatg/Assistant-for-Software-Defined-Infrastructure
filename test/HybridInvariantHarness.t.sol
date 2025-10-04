// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CommitRevealRingBufferAnchorRegistryBound.sol";

contract HybridInvariantHarness is Test {
    CommitRevealRingBufferAnchorRegistryBound registry;
    address owner = address(0x1);
    
    bytes32[] submittedRoots;
    uint64[] submittedTimestamps;
    bytes32[] localRollingHashHistory;
    
    function setUp() public {
        registry = new CommitRevealRingBufferAnchorRegistryBound(5, 1000, owner);
        localRollingHashHistory.push(bytes32(0));
    }
    
    function testInvariantRetainedRootsInEverRoot() public {
        _submitMultipleAnchors(7);
        
        uint256 retained = registry.retainedCount();
        (uint256 firstSeq, uint256 lastSeq) = registry.windowBounds();
        
        for (uint256 seq = firstSeq; seq <= lastSeq; seq++) {
            (bytes32 root,,,) = registry.getBySeq(seq);
            assertTrue(registry.everRoot(root), "Retained root must be in everRoot");
        }
    }
    
    function testInvariantMonotonicTimestamps() public {
        _submitMultipleAnchors(5);
        
        (uint256 firstSeq, uint256 lastSeq) = registry.windowBounds();
        
        uint64 prevTimestamp = 0;
        for (uint256 seq = firstSeq; seq <= lastSeq; seq++) {
            (, uint256 timestamp,,) = registry.getBySeq(seq);
            if (prevTimestamp > 0) {
                assertTrue(timestamp >= prevTimestamp, "Timestamps must be monotonic");
            }
            prevTimestamp = uint64(timestamp);
        }
    }
    
    function testInvariantSeqCounterMatchesTotalSubmitted() public {
        _submitMultipleAnchors(8);
        
        assertEq(registry.seqCounter(), registry.totalSubmitted(), "seqCounter must equal totalSubmitted");
    }
    
    function testInvariantRetentionCount() public {
        uint256 submitCount = 7;
        _submitMultipleAnchors(submitCount);
        
        uint256 retained = registry.retainedCount();
        uint256 capacity = registry.capacity();
        uint256 submitted = registry.totalSubmitted();
        
        uint256 expected = submitted < capacity ? submitted : capacity;
        assertEq(retained, expected, "Retention count must match min(submitted, capacity)");
    }
    
    function testInvariantRollingHashReconstruction() public {
        _submitMultipleAnchors(5);
        
        bytes32 expected = _reconstructRollingHash();
        bytes32 actual = registry.rollingHash();
        
        assertEq(actual, expected, "Rolling hash must match local reconstruction");
    }
    
    function _submitMultipleAnchors(uint256 count) internal {
        address user = address(0x2);
        
        for (uint256 i = 0; i < count; i++) {
            bytes32 root = keccak256(abi.encodePacked("root", i));
            bytes32 batchHash = keccak256(abi.encodePacked("batch", i));
            bytes32 salt = keccak256(abi.encodePacked("salt", i));
            bytes32 commitHash = keccak256(abi.encodePacked(user, root, batchHash, salt));
            
            vm.prank(user);
            registry.commit(commitHash);
            
            vm.warp(block.timestamp + 10);
            
            vm.prank(user);
            registry.reveal(root, batchHash, salt);
            
            submittedRoots.push(root);
            submittedTimestamps.push(uint64(block.timestamp));
            
            bytes32 prevHash = localRollingHashHistory[localRollingHashHistory.length - 1];
            bytes32 newHash = keccak256(abi.encodePacked(prevHash, registry.DOMAIN(), root, batchHash, uint64(i + 1), uint64(block.timestamp)));
            localRollingHashHistory.push(newHash);
        }
    }
    
    function _reconstructRollingHash() internal view returns (bytes32) {
        bytes32 hash = bytes32(0);
        (uint256 firstSeq, uint256 lastSeq) = registry.windowBounds();
        
        for (uint256 seq = 1; seq <= lastSeq; seq++) {
            if (seq >= firstSeq) {
                (bytes32 root, uint256 timestamp, bytes32 batchHash,) = registry.getBySeq(seq);
                hash = keccak256(abi.encodePacked(hash, registry.DOMAIN(), root, batchHash, uint64(seq), uint64(timestamp)));
            }
        }
        
        return hash;
    }
}
