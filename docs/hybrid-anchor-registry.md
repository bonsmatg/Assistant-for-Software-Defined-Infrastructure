# Hybrid Anchor Registry

## Overview

The Hybrid Anchor Registry is a Solidity-based commit-reveal ring buffer system designed to provide tamper-evident anchoring with root-only global uniqueness guarantees. It implements a rolling hash accumulator and supports optional commit/reveal gating for access control.

## Architecture

### Core Components

1. **CommitRevealRingBufferAnchorRegistryBound.sol**
   - Main contract implementing the commit-reveal pattern
   - Ring buffer storage with configurable capacity
   - Root-only uniqueness enforcement via `everRoot` mapping
   - Sender-bound commits preventing front-running
   - Optional allowlist gating for commits and reveals

2. **IAnchorRegistry.sol**
   - Minimal read-only interface for registry queries
   - Exposes latest anchor, window bounds, sequence lookups, rolling hash, and domain

3. **MerkleProofLib**
   - Embedded library for binary Keccak Merkle tree verification
   - Supports proof validation against anchored roots

## Domain Separation

All rolling hash computations use a domain constant to prevent cross-system replay attacks:

```solidity
bytes32 public constant DOMAIN = keccak256("ANCHOR_V1");
```

## Workflow

### 1. Commit Phase

Users commit to an anchor before revealing it:

```solidity
bytes32 commitHash = keccak256(abi.encodePacked(msg.sender, root, batchHash, salt));
registry.commit(commitHash);
```

**Features:**
- Commits are sender-bound (msg.sender is part of the hash)
- Optional commit gating via allowlist
- Commits expire after `commitLifetime` seconds
- Duplicate commits revert

### 2. Reveal Phase

After committing, users reveal the anchor data:

```solidity
registry.reveal(root, batchHash, salt);
```

**Validations:**
- Commit must exist and match sender
- Commit must not be expired
- Root must be globally unique (checked via `everRoot`)
- Timestamps must be monotonically increasing
- Optional reveal gating via allowlist

### 3. Anchor Storage

Accepted anchors are stored in a ring buffer:
- **Capacity:** Configurable max number of retained anchors
- **Sequence:** Each anchor gets a monotonically increasing sequence number
- **Window:** Older anchors are overwritten in ring buffer fashion
- **Permanence:** `everRoot[root] = true` persists even after buffer overwrite

## Root-Only Uniqueness

The registry enforces **root-only** uniqueness:
- Each `root` can only be anchored once (globally unique)
- `batchHash` can be reused across different roots
- This design optimizes gas by removing batch-level deduplication

**Example:**
```
✅ Anchor 1: root=R1, batchHash=B1
✅ Anchor 2: root=R2, batchHash=B1  (same batch, different root - allowed)
❌ Anchor 3: root=R1, batchHash=B2  (duplicate root - rejected)
```

## Rolling Hash Accumulator

The registry maintains a cryptographic rolling hash over all anchored data:

```solidity
rollingHash = keccak256(abi.encodePacked(
    rollingHash,
    DOMAIN,
    root,
    batchHash,
    seq,
    timestamp
));
```

**Properties:**
- Commitment to anchor history
- Tamper-evident: any change to history invalidates the hash
- Includes domain separation constant
- Progresses monotonically with each anchor

## Security Features

### 1. Sender Binding
Commits include `msg.sender` in the hash, preventing front-running attacks where an attacker observes a commit and tries to reveal it themselves.

### 2. Monotonic Timestamps
The registry enforces monotonically increasing timestamps to prevent time-travel attacks and maintain temporal consistency.

### 3. Expiration & Pruning
- Commits expire after `commitLifetime` seconds
- The `pruneExpired()` function allows batch cleanup of expired commits
- Protects against state bloat from abandoned commits

### 4. Gating (Optional)
- **Commit Gating:** Restrict who can commit (allowlist-based)
- **Reveal Gating:** Restrict who can reveal (allowlist-based)
- Owner-controlled via `setCommitGating()`, `setCommitter()`, etc.

### 5. Freeze Mechanism
Owner can freeze anchoring permanently via `freezeAnchors()` for emergency shutdown.

## Merkle Proof Verification

The registry includes built-in Merkle proof verification:

```solidity
bool valid = registry.verifyLeafInAnchor(
    sequence,     // Anchor sequence number
    leaf,         // Leaf hash to verify
    proof,        // Sibling hashes
    index         // Leaf index in tree
);
```

**Use Case:** Prove that a specific transaction or data element was included in an anchored batch without revealing the entire batch.

## Invariants

The system maintains the following invariants (validated via `HybridInvariantHarness.t.sol`):

1. **Retained Root Permanence:** All roots in the retention window exist in `everRoot`
2. **Monotonic Timestamps:** Anchor timestamps are non-decreasing
3. **Sequence Consistency:** `seqCounter == totalSubmitted()`
4. **Retention Bounds:** `retainedCount() == min(submitted, capacity)`
5. **Rolling Hash Integrity:** Rolling hash matches local reconstruction

## Gas Optimization

The contract is optimized for gas efficiency:
- Root-only uniqueness (no batch-level checks)
- Tight packing of storage variables
- Solidity 0.8.20 with 500 optimizer runs
- Unchecked arithmetic where safe

**Thresholds (CI-enforced):**
- Commit: < 43,000 gas
- Reveal: < 125,000 gas

## Events

All state changes emit events for off-chain monitoring:

- `CommitRegistered(address submitter, bytes32 commitHash, uint256 timestamp)`
- `CommitCleared(address submitter, bytes32 commitHash, bool expired)`
- `AnchorSubmittedDetailed(uint256 slot, bytes32 root, bytes32 batchHash, uint256 timestamp, address submitter, uint256 seq)`
- `AnchorFrozen()`
- `RollingHashUpdated(bytes32 newRollingHash, uint256 seq)`
- `CommitGatingUpdated(bool enabled)`
- `CommitterSet(address committer, bool allowed)`
- `RevealGatingUpdated(bool enabled)`
- `RevealerSet(address revealer, bool allowed)`

## Testing

### Unit Tests (`HybridAnchorRegistryExtendedTest.t.sol`)
- Commit/reveal success flows
- Root uniqueness enforcement
- Batch reuse validation
- Sender binding failure cases
- Expiration and pruning
- Monotonic timestamp enforcement
- Gating mechanisms
- Rolling hash progression
- Merkle proof verification

### Invariant Tests (`HybridInvariantHarness.t.sol`)
- Fuzz testing of core invariants
- Property-based validation
- State consistency checks

## Deployment

```solidity
CommitRevealRingBufferAnchorRegistryBound registry = 
    new CommitRevealRingBufferAnchorRegistryBound(
        capacity,        // e.g., 100 (ring buffer size)
        commitLifetime,  // e.g., 3600 (1 hour in seconds)
        owner            // Admin address
    );
```

## Interface Usage

External contracts can interact via the `IAnchorRegistry` interface:

```solidity
IAnchorRegistry registry = IAnchorRegistry(registryAddress);

// Get latest anchor
(bytes32 root, uint256 time, bytes32 batchHash, address submitter, uint256 seq) 
    = registry.latest();

// Check if root was ever anchored
bool exists = registry.everRoot(someRoot);

// Get rolling hash
bytes32 hash = registry.rollingHash();

// Get domain constant
bytes32 domain = registry.DOMAIN();
```

## CI/CD

### Gas Reporting (`solidity-gas.yml`)
- Runs on every push/PR
- Enforces gas thresholds
- Generates gas reports via Foundry

### Event Guard (`event-guard.yml`)
- Validates event signatures against `events.lock`
- Prevents accidental event ABI changes
- Ensures off-chain indexer compatibility

## References

- Solidity version: 0.8.20
- Optimizer runs: 500
- Testing framework: Foundry (forge)
- Domain: `ANCHOR_V1`
