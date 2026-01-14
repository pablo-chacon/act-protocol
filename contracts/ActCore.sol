// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ActToken.sol";
import "./ActEscrow.sol";

contract ActCore {
    ActToken public immutable token;
    ActEscrow public immutable escrow;

    uint64 public constant EXTRA_BUFFER = 72 hours;

    struct Service {
        address buyer;
        address provider;
        bytes32 serviceHash;
        uint64 slotStart;
        uint64 slotEnd;
        uint64 expiresAt;
        bool finalized;
    }

    mapping(bytes32 => Service) public services;

    event ServiceCreated(bytes32 indexed serviceId, address indexed buyer, address indexed provider, uint64 expiresAt);
    event ServiceFinalized(bytes32 indexed serviceId, address indexed finalizer);

    error ZeroProvider();
    error InvalidSlot();
    error ZeroValue();
    error AlreadyFinalized();
    error NotAuthorized();
    error AlreadyExists();

    constructor(address treasury) {
        escrow = new ActEscrow(treasury, address(this));
        token = new ActToken(address(this));
    }

    function createService(
        address provider,
        bytes32 serviceHash,
        uint64 slotStart,
        uint64 slotEnd
    ) external payable returns (bytes32 serviceId) {
        if (provider == address(0)) revert ZeroProvider();
        if (msg.value == 0) revert ZeroValue();

        // slotEnd must be after slotStart and in the future
        if (slotEnd <= slotStart) revert InvalidSlot();
        if (slotEnd <= uint64(block.timestamp)) revert InvalidSlot();

        uint64 slotLength = slotEnd - slotStart;
        uint64 grace = slotLength / 4; // 25%
        uint64 expiresAt = slotEnd + grace + EXTRA_BUFFER;

        // serviceId uniqueness: include buyer, provider, serviceHash, slot times, and block.timestamp
        serviceId = keccak256(
            abi.encodePacked(msg.sender, provider, serviceHash, slotStart, slotEnd, block.timestamp)
        );

        // hard guard against accidental overwrite
        if (services[serviceId].buyer != address(0)) revert AlreadyExists();

        services[serviceId] = Service({
            buyer: msg.sender,
            provider: provider,
            serviceHash: serviceHash,
            slotStart: slotStart,
            slotEnd: slotEnd,
            expiresAt: expiresAt,
            finalized: false
        });

        escrow.lock{value: msg.value}(serviceId, msg.sender, provider, expiresAt);
        token.mint(msg.sender);

        emit ServiceCreated(serviceId, msg.sender, provider, expiresAt);
    }

    function finalize(bytes32 serviceId) external {
        Service storage s = services[serviceId];
        if (s.buyer == address(0)) revert NotAuthorized(); // invalid id treated as unauthorized
        if (s.finalized) revert AlreadyFinalized();

        // buyer or provider anytime, anyone after expiry
        if (msg.sender != s.buyer && msg.sender != s.provider && block.timestamp < s.expiresAt) {
            revert NotAuthorized();
        }

        s.finalized = true;

        // escrow release is core-only, no bypass
        escrow.release(serviceId);

        // burn one handle token from buyer
        token.burn(s.buyer);

        emit ServiceFinalized(serviceId, msg.sender);
    }
}
