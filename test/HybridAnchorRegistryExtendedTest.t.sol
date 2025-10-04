// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CommitRevealRingBufferAnchorRegistryBound.sol";

contract HybridAnchorRegistryExtendedTest is Test {
    CommitRevealRingBufferAnchorRegistryBound registry;
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        registry = new CommitRevealRingBufferAnchorRegistryBound(10, 100, owner);
    }

    function testCommitRevealSuccess() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt = keccak256("salt1");
        bytes32 commitHash = keccak256(abi.encodePacked(user1, root, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        
        vm.prank(user1);
        registry.reveal(root, batchHash, salt);
        
        assertEq(registry.totalSubmitted(), 1);
        assertTrue(registry.everRoot(root));
    }

    function testRootUniqueness() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash1 = keccak256("batch1");
        bytes32 batchHash2 = keccak256("batch2");
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        
        bytes32 commitHash1 = keccak256(abi.encodePacked(user1, root, batchHash1, salt1));
        bytes32 commitHash2 = keccak256(abi.encodePacked(user1, root, batchHash2, salt2));
        
        vm.prank(user1);
        registry.commit(commitHash1);
        
        vm.prank(user1);
        registry.reveal(root, batchHash1, salt1);
        
        vm.prank(user1);
        registry.commit(commitHash2);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(CommitRevealRingBufferAnchorRegistryBound.DuplicateRoot.selector, root));
        registry.reveal(root, batchHash2, salt2);
    }

    function testBatchReuseAllowed() public {
        bytes32 root1 = keccak256("root1");
        bytes32 root2 = keccak256("root2");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        
        bytes32 commitHash1 = keccak256(abi.encodePacked(user1, root1, batchHash, salt1));
        bytes32 commitHash2 = keccak256(abi.encodePacked(user1, root2, batchHash, salt2));
        
        vm.prank(user1);
        registry.commit(commitHash1);
        vm.prank(user1);
        registry.reveal(root1, batchHash, salt1);
        
        vm.prank(user1);
        registry.commit(commitHash2);
        vm.prank(user1);
        registry.reveal(root2, batchHash, salt2);
        
        assertEq(registry.totalSubmitted(), 2);
    }

    function testSenderBindingFailure() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt = keccak256("salt1");
        bytes32 commitHash = keccak256(abi.encodePacked(user1, root, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(CommitRevealRingBufferAnchorRegistryBound.CommitNotFound.selector, keccak256(abi.encodePacked(user2, root, batchHash, salt))));
        registry.reveal(root, batchHash, salt);
    }

    function testCommitExpiration() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt = keccak256("salt1");
        bytes32 commitHash = keccak256(abi.encodePacked(user1, root, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        
        vm.warp(block.timestamp + 101);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(CommitRevealRingBufferAnchorRegistryBound.CommitExpired.selector, commitHash));
        registry.reveal(root, batchHash, salt);
    }

    function testPruneExpired() public {
        bytes32 commitHash1 = keccak256("commit1");
        bytes32 commitHash2 = keccak256("commit2");
        
        vm.prank(user1);
        registry.commit(commitHash1);
        
        vm.warp(block.timestamp + 50);
        
        vm.prank(user1);
        registry.commit(commitHash2);
        
        vm.warp(block.timestamp + 60);
        
        bytes32[] memory list = new bytes32[](2);
        list[0] = commitHash1;
        list[1] = commitHash2;
        
        registry.pruneExpired(list);
        
        (uint64 ts1, bool used1, bool expired1) = registry.getCommit(commitHash1);
        assertEq(ts1, 0);
        
        (uint64 ts2, bool used2, bool expired2) = registry.getCommit(commitHash2);
        assertTrue(ts2 > 0);
    }

    function testMonotonicTimeRevert() public {
        bytes32 root1 = keccak256("root1");
        bytes32 root2 = keccak256("root2");
        bytes32 batchHash1 = keccak256("batch1");
        bytes32 batchHash2 = keccak256("batch2");
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        
        bytes32 commitHash1 = keccak256(abi.encodePacked(user1, root1, batchHash1, salt1));
        bytes32 commitHash2 = keccak256(abi.encodePacked(user1, root2, batchHash2, salt2));
        
        vm.prank(user1);
        registry.commit(commitHash1);
        
        vm.warp(100);
        vm.prank(user1);
        registry.reveal(root1, batchHash1, salt1);
        
        vm.prank(user1);
        registry.commit(commitHash2);
        
        vm.warp(99);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(CommitRevealRingBufferAnchorRegistryBound.NonMonotonic.selector, 100, 99));
        registry.reveal(root2, batchHash2, salt2);
    }

    function testCommitGating() public {
        bytes32 commitHash = keccak256("commit1");
        
        vm.prank(owner);
        registry.setCommitGating(true);
        
        vm.prank(user1);
        vm.expectRevert(CommitRevealRingBufferAnchorRegistryBound.NotCommitter.selector);
        registry.commit(commitHash);
        
        vm.prank(owner);
        registry.setCommitter(user1, true);
        
        vm.prank(user1);
        registry.commit(commitHash);
    }

    function testRevealGating() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt = keccak256("salt1");
        bytes32 commitHash = keccak256(abi.encodePacked(user1, root, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        
        vm.prank(owner);
        registry.setRevealGating(true);
        
        vm.prank(user1);
        vm.expectRevert(CommitRevealRingBufferAnchorRegistryBound.NotRevealer.selector);
        registry.reveal(root, batchHash, salt);
        
        vm.prank(owner);
        registry.setRevealer(user1, true);
        
        vm.prank(user1);
        registry.reveal(root, batchHash, salt);
    }

    function testRollingHashProgression() public {
        bytes32 initialHash = registry.rollingHash();
        
        bytes32 root1 = keccak256("root1");
        bytes32 batchHash1 = keccak256("batch1");
        bytes32 salt1 = keccak256("salt1");
        bytes32 commitHash1 = keccak256(abi.encodePacked(user1, root1, batchHash1, salt1));
        
        vm.prank(user1);
        registry.commit(commitHash1);
        vm.prank(user1);
        registry.reveal(root1, batchHash1, salt1);
        
        bytes32 hash1 = registry.rollingHash();
        assertTrue(hash1 != initialHash);
        
        bytes32 root2 = keccak256("root2");
        bytes32 batchHash2 = keccak256("batch2");
        bytes32 salt2 = keccak256("salt2");
        bytes32 commitHash2 = keccak256(abi.encodePacked(user1, root2, batchHash2, salt2));
        
        vm.prank(user1);
        registry.commit(commitHash2);
        vm.prank(user1);
        registry.reveal(root2, batchHash2, salt2);
        
        bytes32 hash2 = registry.rollingHash();
        assertTrue(hash2 != hash1);
    }

    function testMerkleProofVerification() public {
        bytes32 root = keccak256("root1");
        bytes32 batchHash = keccak256("batch1");
        bytes32 salt = keccak256("salt1");
        bytes32 commitHash = keccak256(abi.encodePacked(user1, root, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        vm.prank(user1);
        registry.reveal(root, batchHash, salt);
        
        bytes32 leaf = keccak256("leaf");
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256("sibling1");
        proof[1] = keccak256("sibling2");
        
        bytes32 computed = leaf;
        computed = keccak256(abi.encodePacked(computed, proof[0]));
        computed = keccak256(abi.encodePacked(proof[1], computed));
        
        registry = new CommitRevealRingBufferAnchorRegistryBound(10, 100, owner);
        commitHash = keccak256(abi.encodePacked(user1, computed, batchHash, salt));
        
        vm.prank(user1);
        registry.commit(commitHash);
        vm.prank(user1);
        registry.reveal(computed, batchHash, salt);
        
        bool result = registry.verifyLeafInAnchor(1, leaf, proof, 0);
        assertTrue(result);
    }

    function testDomainConstant() public {
        assertEq(registry.DOMAIN(), keccak256("ANCHOR_V1"));
    }
}
