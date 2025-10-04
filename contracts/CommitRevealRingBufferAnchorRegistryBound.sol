// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MerkleProofLib {
    function verify(bytes32 root, bytes32 leaf, bytes32[] memory proof, uint256 index) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i; i < proof.length; ++i) {
            bytes32 sib = proof[i];
            if (index & 1 == 1) computed = keccak256(abi.encodePacked(sib, computed));
            else computed = keccak256(abi.encodePacked(computed, sib));
            index >>= 1;
        }
        return computed == root;
    }
}

contract CommitRevealRingBufferAnchorRegistryBound {
    event CommitRegistered(address indexed submitter, bytes32 indexed commitHash, uint256 timestamp);
    event CommitCleared(address indexed submitter, bytes32 indexed commitHash, bool expired);
    event AnchorSubmittedDetailed(uint256 indexed slot, bytes32 indexed root, bytes32 indexed batchHash, uint256 timestamp, address submitter, uint256 seq);
    event AnchorFrozen();
    event RollingHashUpdated(bytes32 newRollingHash, uint256 seq);
    event CommitGatingUpdated(bool enabled);
    event CommitterSet(address indexed committer, bool allowed);
    event RevealGatingUpdated(bool enabled);
    event RevealerSet(address indexed revealer, bool allowed);

    error AnchoringFrozen(); error DuplicateRoot(bytes32 root); error AlreadyFrozen(); error NotOwner(); error ZeroValue();
    error CommitAlreadyExists(bytes32 commitHash); error CommitNotFound(bytes32 commitHash); error CommitAlreadyUsed(bytes32 commitHash);
    error CommitExpired(bytes32 commitHash); error NoAnchors(); error IndexOutOfRange(uint256 query); error NonMonotonic(uint256 previous, uint256 current);
    error NotCommitter(); error NotRevealer();

    struct Anchor { bytes32 root; bytes32 batchHash; uint64 timestamp; address submitter; uint64 seq; }
    struct CommitInfo { uint64 timestamp; bool used; }

    bytes32 public constant DOMAIN = keccak256("ANCHOR_V1");
    uint256 public immutable capacity; uint256 public immutable commitLifetime; address public immutable owner; bool public frozen;
    uint64 public seqCounter; uint64 public storedCount; uint64 public lastTimestamp; Anchor[] private buffer;
    mapping(bytes32 => bool) public everRoot; mapping(bytes32 => CommitInfo) public commits;
    bool public commitGatingEnabled; mapping(address => bool) public allowedCommitter; bool public revealGatingEnabled; mapping(address => bool) public allowedRevealer;
    bytes32 public rollingHash;

    modifier onlyOwner(){ if(msg.sender!=owner) revert NotOwner(); _; }

    constructor(uint256 _capacity, uint256 _commitLifetime, address _owner){ require(_capacity>1,"cap>1"); require(_commitLifetime>0,"life>0"); require(_owner!=address(0),"owner=0"); capacity=_capacity; commitLifetime=_commitLifetime; owner=_owner; buffer=new Anchor[](_capacity);}    

    function setCommitGating(bool enabled) external onlyOwner { commitGatingEnabled = enabled; emit CommitGatingUpdated(enabled);}    
    function setCommitter(address committer, bool allowed) external onlyOwner { allowedCommitter[committer]=allowed; emit CommitterSet(committer,allowed);}    
    function setRevealGating(bool enabled) external onlyOwner { revealGatingEnabled=enabled; emit RevealGatingUpdated(enabled);}    
    function setRevealer(address revealer, bool allowed) external onlyOwner { allowedRevealer[revealer]=allowed; emit RevealerSet(revealer,allowed);}    

    function commit(bytes32 commitHash) external { if(commitGatingEnabled && !allowedCommitter[msg.sender]) revert NotCommitter(); CommitInfo storage c=commits[commitHash]; if(c.timestamp!=0) revert CommitAlreadyExists(commitHash); c.timestamp=uint64(block.timestamp); emit CommitRegistered(msg.sender,commitHash,block.timestamp);}    

    function reveal(bytes32 root, bytes32 batchHash, bytes32 salt) external {
        if(frozen) revert AnchoringFrozen(); if(revealGatingEnabled && !allowedRevealer[msg.sender]) revert NotRevealer(); if(root==bytes32(0)||batchHash==bytes32(0)) revert ZeroValue();
        bytes32 ch = keccak256(abi.encodePacked(msg.sender, root, batchHash, salt)); CommitInfo storage c=commits[ch]; if(c.timestamp==0) revert CommitNotFound(ch); if(c.used) revert CommitAlreadyUsed(ch);
        if(block.timestamp > c.timestamp + commitLifetime){ emit CommitCleared(msg.sender,ch,true); delete commits[ch]; revert CommitExpired(ch);} if(everRoot[root]) revert DuplicateRoot(root);
        uint64 nowTs=uint64(block.timestamp); uint64 prev=lastTimestamp; if(prev!=0 && nowTs<prev) revert NonMonotonic(prev,nowTs); lastTimestamp=nowTs; c.used=true;
        unchecked{++seqCounter;} uint64 newSeq=seqCounter; uint256 slot=(newSeq-1)%capacity; Anchor storage a=buffer[slot]; if(storedCount<capacity) storedCount++; a.root=root; a.batchHash=batchHash; a.timestamp=nowTs; a.submitter=msg.sender; a.seq=newSeq; everRoot[root]=true;
        rollingHash = keccak256(abi.encodePacked(rollingHash, DOMAIN, root, batchHash, newSeq, nowTs));
        emit AnchorSubmittedDetailed(slot, root, batchHash, nowTs, msg.sender, newSeq); emit CommitCleared(msg.sender, ch, false); emit RollingHashUpdated(rollingHash, newSeq);
    }

    function freezeAnchors() external onlyOwner { if(frozen) revert AlreadyFrozen(); frozen=true; emit AnchorFrozen(); }
    function pruneExpired(bytes32[] calldata list) external { uint256 nowTs=block.timestamp; for(uint256 i; i<list.length;++i){ bytes32 h=list[i]; CommitInfo storage c=commits[h]; if(c.timestamp!=0 && !c.used && nowTs>c.timestamp+commitLifetime){ emit CommitCleared(msg.sender,h,true); delete commits[h]; } } }

    function latest() external view returns(bytes32 root,uint256 time,bytes32 batchHash,address submitter,uint256 seq){ if(seqCounter==0) revert NoAnchors(); uint256 slot=(seqCounter-1)%capacity; Anchor storage a=buffer[slot]; return(a.root,a.timestamp,a.batchHash,a.submitter,a.seq);}    
    function totalSubmitted() external view returns(uint256){ return seqCounter;} function retainedCount() external view returns(uint256){ return storedCount; }
    function windowBounds() external view returns(uint256 firstSeq,uint256 lastSeq){ if(seqCounter==0) return(0,0); lastSeq=seqCounter; firstSeq=seqCounter>capacity? (seqCounter-capacity+1):1; }
    function getBySeq(uint256 sequence) public view returns(bytes32 root,uint256 time,bytes32 batchHash,address submitter){ if(sequence==0||sequence>seqCounter) revert IndexOutOfRange(sequence); if(seqCounter>capacity && sequence<=seqCounter-capacity) revert IndexOutOfRange(sequence); uint256 slot=(sequence-1)%capacity; Anchor storage a=buffer[slot]; if(a.seq!=sequence) revert IndexOutOfRange(sequence); return(a.root,a.timestamp,a.batchHash,a.submitter);}    
    function getCommit(bytes32 commitHash) external view returns(uint64 timestamp,bool used,bool expired){ CommitInfo storage c=commits[commitHash]; timestamp=c.timestamp; used=c.used; expired=(timestamp!=0 && !used && block.timestamp>timestamp+commitLifetime); }
    function verifyLeafInAnchor(uint256 sequence, bytes32 leaf, bytes32[] calldata proof, uint256 index) external view returns(bool){ (bytes32 root,,,) = getBySeq(sequence); return MerkleProofLib.verify(root, leaf, proof, index); }
}
