// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ActToken.sol";
import "./ActEscrow.sol";

/// @title ActCore
/// @notice Neutral settlement core for off-chain services.
/// @dev Provider publishes immutable service offers. Buyer accepts by funding escrow.
///      Finalization is deterministic. No disputes, no identity, no upgrades.
contract ActCore {
    
    using SafeERC20 for IERC20;

    ActToken public immutable token;
    ActEscrow public immutable escrow;

    uint64 public constant EXTRA_BUFFER = 72 hours;

    struct Service {
        address buyer;          // set on acceptance
        address provider;       // set on offer creation
        address paymentToken;   // ERC-20
        uint256 amount;         // price
        bytes32 serviceHash;    // commitment to off-chain terms
        uint64 slotStart;       // platform-defined
        uint64 slotEnd;         // platform-defined
        uint64 expiresAt;       // computed deterministically
        bool accepted;          // buyer accepted and escrow funded
        bool finalized;         // settled
    }

    /// @dev serviceId -> Service
    mapping(bytes32 => Service) public services;

    /// @dev deterministic nonce per provider for serviceId generation
    mapping(address => uint256) public nonces;

    // Events
    event ServiceOffered(
        bytes32 indexed serviceId,
        address indexed provider,
        address paymentToken,
        uint256 amount,
        uint64 expiresAt
    );

    event ServiceAccepted(
        bytes32 indexed serviceId,
        uint256 indexed tokenId,
        address indexed buyer
    );

    event ServiceFinalized(
        bytes32 indexed serviceId,
        uint256 indexed tokenId,
        address indexed finalizer
    );


    error InvalidToken();
    error ZeroAmount();
    error InvalidSlot();
    error AlreadyExists();
    error InvalidServiceId();
    error AlreadyAccepted();
    error NotAccepted();
    error AlreadyFinalized();
    error NotAuthorized();


    constructor(address treasury) {
        escrow = new ActEscrow(treasury, address(this));
        token = new ActToken(address(this));
    }

    /// @notice Provider publishes an immutable service offer.
    /// @dev No funds move. No token is minted.
    function createServiceOffer(
        address paymentToken,
        uint256 amount,
        bytes32 serviceHash,
        uint64 slotStart,
        uint64 slotEnd
    ) external returns (bytes32 serviceId) {
        if (paymentToken == address(0)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        // slot bounds for deterministic expiry computation
        if (slotEnd <= slotStart) revert InvalidSlot();
        if (slotEnd <= uint64(block.timestamp)) revert InvalidSlot();

        uint64 slotLength = slotEnd - slotStart;
        uint64 grace = slotLength / 4; // 25%
        uint64 expiresAt = slotEnd + grace + EXTRA_BUFFER;

        uint256 n = nonces[msg.sender]++;
        serviceId = keccak256(
            abi.encodePacked(
                msg.sender,
                paymentToken,
                amount,
                serviceHash,
                slotStart,
                slotEnd,
                n
            )
        );

        // hard guard against overwrite
        if (services[serviceId].provider != address(0)) revert AlreadyExists();

        services[serviceId] = Service({
            buyer: address(0),
            provider: msg.sender,
            paymentToken: paymentToken,
            amount: amount,
            serviceHash: serviceHash,
            slotStart: slotStart,
            slotEnd: slotEnd,
            expiresAt: expiresAt,
            accepted: false,
            finalized: false
        });

        emit ServiceOffered(
            serviceId,
            msg.sender,
            paymentToken,
            amount,
            expiresAt
        );
    }

    /// @notice Buyer accepts a published service offer and funds escrow.
    function acceptService(bytes32 serviceId) external returns (uint256 tokenId) {
        Service storage s = services[serviceId];
        if (s.provider == address(0)) revert InvalidServiceId();
        if (s.accepted) revert AlreadyAccepted();

        s.accepted = true;
        s.buyer = msg.sender;

        // Fund escrow atomically
        IERC20(s.paymentToken).safeTransferFrom(
            msg.sender,
            address(escrow),
            s.amount
        );

        escrow.lock(
            serviceId,
            msg.sender,
            s.provider,
            s.paymentToken,
            s.amount,
            s.expiresAt
        );

        tokenId = uint256(serviceId);

        // Mint non-transferable ERC-721 handle to buyer
        token.mint(msg.sender, tokenId);

        emit ServiceAccepted(serviceId, tokenId, msg.sender);
    }

    // Finalize service
    function finalize(bytes32 serviceId) external {
        Service storage s = services[serviceId];
        if (s.provider == address(0)) revert InvalidServiceId();
        if (!s.accepted) revert NotAccepted();
        if (s.finalized) revert AlreadyFinalized();

        // buyer or provider anytime, anyone after expiry
        if (
            msg.sender != s.buyer &&
            msg.sender != s.provider &&
            block.timestamp < s.expiresAt
        ) {
            revert NotAuthorized();
        }

        s.finalized = true;

        uint256 tokenId = uint256(serviceId);

        // Release escrow
        escrow.release(serviceId);

        // Burn service handle
        token.burn(tokenId);

        emit ServiceFinalized(serviceId, tokenId, msg.sender);
    }
}
