// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IAnchorRegistry {
    function latest() external view returns (bytes32 root,uint256 time,bytes32 batchHash,address submitter,uint256 seq);
    function totalSubmitted() external view returns (uint256); function retainedCount() external view returns (uint256);
    function windowBounds() external view returns (uint256 firstSeq, uint256 lastSeq);
    function getBySeq(uint256 sequence) external view returns (bytes32 root,uint256 time,bytes32 batchHash,address submitter);
    function rollingHash() external view returns (bytes32); function everRoot(bytes32 root) external view returns (bool);
    function DOMAIN() external view returns (bytes32);
}
