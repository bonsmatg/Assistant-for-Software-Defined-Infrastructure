# Solidity Subsystem Validation Checklist

This document provides a step-by-step verification process for the implemented Solidity subsystem.

## ✅ Pre-CI Validation (Completed)

### File Structure
- [x] `contracts/CommitRevealRingBufferAnchorRegistryBound.sol` exists
- [x] `contracts/interfaces/IAnchorRegistry.sol` exists
- [x] `test/HybridAnchorRegistryExtendedTest.t.sol` exists
- [x] `test/HybridInvariantHarness.t.sol` exists
- [x] `foundry.toml` exists with correct settings
- [x] `.github/workflows/solidity-gas.yml` exists
- [x] `.github/workflows/event-guard.yml` exists
- [x] `scripts/abi/events.lock` exists
- [x] `scripts/abi/extract-events.js` exists
- [x] `docs/hybrid-anchor-registry.md` exists
- [x] `README.md` updated with Solidity section
- [x] `.gitignore` updated for Solidity artifacts

### Contract Requirements
- [x] DOMAIN constant = keccak256("ANCHOR_V1")
- [x] Root-only uniqueness via everRoot mapping
- [x] Commit-reveal pattern with sender binding
- [x] Rolling hash formula: keccak256(rollingHash, DOMAIN, root, batchHash, seq, timestamp)
- [x] MerkleProofLib embedded for Merkle verification
- [x] Commit/reveal gating (allowlists)
- [x] Monotonic timestamp enforcement
- [x] Expired commit pruning function
- [x] All 9 required events defined

### Events Validation
```bash
# Verify events in contract
grep "event " contracts/CommitRevealRingBufferAnchorRegistryBound.sol

# Verify events in lock file
cat scripts/abi/events.lock

# Expected events:
# 1. CommitRegistered(address,bytes32,uint256)
# 2. CommitCleared(address,bytes32,bool)
# 3. AnchorSubmittedDetailed(uint256,bytes32,bytes32,uint256,address,uint256)
# 4. AnchorFrozen()
# 5. RollingHashUpdated(bytes32,uint256)
# 6. CommitGatingUpdated(bool)
# 7. CommitterSet(address,bool)
# 8. RevealGatingUpdated(bool)
# 9. RevealerSet(address,bool)
```
- [x] All 9 events match between contract and lock file

### Interface Requirements
- [x] latest() function exposed
- [x] windowBounds() function exposed
- [x] getBySeq(uint256) function exposed
- [x] rollingHash() function exposed
- [x] everRoot(bytes32) function exposed
- [x] DOMAIN() function exposed
- [x] totalSubmitted() function exposed
- [x] retainedCount() function exposed

### Test Coverage
**Unit Tests (HybridAnchorRegistryExtendedTest.t.sol):**
- [x] testCommitRevealSuccess
- [x] testRootUniqueness
- [x] testBatchReuseAllowed
- [x] testSenderBindingFailure
- [x] testCommitExpiration
- [x] testPruneExpired
- [x] testMonotonicTimeRevert
- [x] testCommitGating
- [x] testRevealGating
- [x] testRollingHashProgression
- [x] testMerkleProofVerification
- [x] testDomainConstant

**Invariant Tests (HybridInvariantHarness.t.sol):**
- [x] testInvariantRetainedRootsInEverRoot
- [x] testInvariantMonotonicTimestamps
- [x] testInvariantSeqCounterMatchesTotalSubmitted
- [x] testInvariantRetentionCount
- [x] testInvariantRollingHashReconstruction

### Documentation
- [x] Architecture section
- [x] Domain separation explained
- [x] Workflow documentation (commit/reveal)
- [x] Root-only uniqueness explained with examples
- [x] Rolling hash accumulator documented
- [x] Security features documented
- [x] Merkle proof verification usage
- [x] Invariants listed
- [x] Gas optimization notes
- [x] Events listing
- [x] Testing approach
- [x] Deployment instructions
- [x] Interface usage examples
- [x] CI/CD integration documented

## ⏳ CI Validation (Pending)

These checks will be performed automatically by CI workflows when the PR is opened:

### Build Validation
```bash
forge build
```
Expected: ✅ Build succeeds with no errors

### Test Execution
```bash
forge test
```
Expected: ✅ All 17 tests pass (12 unit + 5 invariant)

### Gas Reporting
```bash
forge test --gas-report
```
Expected thresholds:
- ✅ Commit function: < 43,000 gas
- ✅ Reveal function: < 125,000 gas

### Event Guard
```bash
forge build
node scripts/abi/extract-events.js
```
Expected: ✅ All 9 events validated against lock file

## Manual Verification Commands

Run these commands to verify the implementation locally (requires Foundry):

### 1. Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Build Contracts
```bash
cd /path/to/repo
forge build
```

### 3. Run Tests
```bash
# All tests
forge test -vv

# With gas report
forge test --gas-report

# Specific test
forge test --match-test testCommitRevealSuccess -vvv

# Invariant tests only
forge test --match-contract HybridInvariantHarness -vv
```

### 4. Validate Events
```bash
# After building
node scripts/abi/extract-events.js
```

### 5. Check Coverage (Optional)
```bash
forge coverage
```

## Acceptance Criteria Matrix

| Criterion | Status | Verification Method |
|-----------|--------|---------------------|
| **1. CommitRevealRingBufferAnchorRegistryBound.sol** |
| Root-only uniqueness | ✅ | Code review: everRoot mapping |
| Commit/reveal gating | ✅ | Code review: commitGatingEnabled, revealGatingEnabled |
| Monotonic timestamps | ✅ | Code review: NonMonotonic error + test |
| Expired pruning | ✅ | Code review: pruneExpired() + test |
| Rolling hash | ✅ | Code review: formula in reveal() + test |
| DOMAIN constant | ✅ | Code review: keccak256("ANCHOR_V1") |
| MerkleProofLib | ✅ | Code review: embedded library + test |
| 9 Events | ✅ | Code review: event declarations |
| **2. IAnchorRegistry.sol** |
| Interface complete | ✅ | Code review: 8 view functions |
| **3. HybridAnchorRegistryExtendedTest.t.sol** |
| 12 unit tests | ✅ | Code review: test functions |
| Coverage complete | ✅ | Tests cover all features |
| **4. HybridInvariantHarness.t.sol** |
| 5 invariants | ✅ | Code review: invariant tests |
| **5. events.lock** |
| 9 signatures | ✅ | File review: matches contract |
| **6. extract-events.js** |
| Validation logic | ✅ | Code review: extraction + validation |
| **7. foundry.toml** |
| Solc 0.8.20 | ✅ | Config review |
| Optimizer 500 | ✅ | Config review |
| **8. solidity-gas.yml** |
| Gas thresholds | ✅ | Workflow review: 43k/125k |
| Build/test | ✅ | Workflow review: forge commands |
| **9. event-guard.yml** |
| Event validation | ✅ | Workflow review: extract-events.js |
| **10. hybrid-anchor-registry.md** |
| Complete docs | ✅ | Documentation review |
| **11. README.md** |
| Solidity section | ✅ | README review |

## Success Criteria

All items marked with ✅ must remain passing, and ⏳ items will be validated by CI:

- ✅ **Code Complete**: All 12 components implemented
- ✅ **Tests Written**: 17 tests covering all features
- ✅ **Documentation**: Complete architecture and usage guide
- ✅ **CI Configured**: Both workflows ready
- ⏳ **Tests Pass**: Will be validated in CI
- ⏳ **Gas Thresholds**: Will be validated in CI
- ⏳ **Event Guard**: Will be validated in CI

## Notes

1. **Network Access Required**: Building and testing requires internet access to download:
   - Solidity compiler (solc 0.8.20)
   - Foundry standard library
   - Node.js dependencies (implicit)

2. **CI Environment**: The workflows are configured for GitHub Actions with:
   - Ubuntu latest runner
   - Foundry nightly toolchain
   - Node.js 18

3. **Local Testing**: To test locally, ensure you have:
   - Foundry installed (forge, cast, anvil)
   - Node.js 18+ (for event validation)
   - Internet access (first build only)

## Issue Resolution

If any CI check fails:

1. **Build Failure**
   - Check Solidity syntax
   - Verify imports
   - Check compiler version compatibility

2. **Test Failure**
   - Review test output
   - Check gas limits
   - Verify assertions

3. **Gas Threshold Exceeded**
   - Optimize contract code
   - Review storage patterns
   - Update thresholds if necessary

4. **Event Guard Failure**
   - Verify event signatures match
   - Update events.lock if intentional change
   - Check for typos in event parameters

## Conclusion

✅ **All pre-CI validation checks passed**
⏳ **CI validation pending**

The implementation is complete and ready for CI validation. All acceptance criteria are met and documented.
