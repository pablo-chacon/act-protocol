// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


/// @title ActToken
/// @notice Non-transferable ERC-721 service handle.
/// @dev 1 tokenId == 1 service instance. Mint/burn are core-only.
///      Transfers are blocked. Approvals are disabled to avoid UX confusion.
contract ActToken is ERC721 {
    address public immutable core;

    error InvalidCore();
    error OnlyCore();
    error TransfersDisabled();
    error ApprovalsDisabled();


    constructor(address _core) ERC721("ACT Service Handle", "ACT") {
        if (_core == address(0)) revert InvalidCore();
        core = _core;
    }


    modifier onlyCore() {
        if (msg.sender != core) revert OnlyCore();
        _;
    }


    function mint(address to, uint256 tokenId) external onlyCore {
        _mint(to, tokenId);
    }


    function burn(uint256 tokenId) external onlyCore {
        _burn(tokenId);
    }


    function approve(address, uint256) public pure override {
        revert ApprovalsDisabled();
    }


    function setApprovalForAll(address, bool) public pure override {
        revert ApprovalsDisabled();
    }

    /// @dev OZ v5 transfer hook. Allow only mint (from=0) and burn (to=0).
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address from)
    {
        from = super._update(to, tokenId, auth);
        if (from != address(0) && to != address(0)) revert TransfersDisabled();
        return from;
    }
}
