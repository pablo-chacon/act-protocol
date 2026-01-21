// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "../contracts/ActCore.sol";
import "../contracts/ActEscrow.sol";
import "../contracts/ActToken.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Minimal ERC-20 for invariant testing.
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Payment Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Handler drives state transitions with randomized sequences.
contract ActHandler is Test {
    ActCore public immutable core;
    ActEscrow public immutable escrow;
    ActToken public immutable handle;
    MockERC20 public immutable payToken;

    address public immutable treasury;

    // Actors (kept small and fixed for deterministic coverage)
    address public buyerA;
    address public buyerB;
    address public providerA;
    address public providerB;
    address public rando;

    // Track created serviceIds to enable invariant checks.
    bytes32[] public serviceIds;
    uint256 public constant MAX_SERVICES = 32;

    // Track last computed expiry for warp helper (not relied upon for correctness).
    uint64 public lastExpiresAt;

    constructor(ActCore _core, MockERC20 _payToken, address _treasury) {
        core = _core;
        escrow = _core.escrow();
        handle = _core.token();
        payToken = _payToken;
        treasury = _treasury;

        buyerA = address(0xA11CE);
        buyerB = address(0xB0B);
        providerA = address(0xCAFE);
        providerB = address(0xBEEF);
        rando = address(0xD00D);

        // Seed balances + approvals for buyers.
        _fundAndApprove(buyerA, 1_000_000e18);
        _fundAndApprove(buyerB, 1_000_000e18);
    }

    function _fundAndApprove(address buyer, uint256 amount) internal {
        payToken.mint(buyer, amount);
        vm.startPrank(buyer);
        payToken.approve(address(core), type(uint256).max);
        vm.stopPrank();
    }

    // ----------------------------
    // Handler actions
    // ----------------------------

    /// @notice Create a new service for a random buyer/provider with bounded slots.
    function createService(uint256 buyerSeed, uint256 providerSeed, uint64 startOffset, uint64 duration, bytes32 serviceHash)
        external
    {
        if (serviceIds.length >= MAX_SERVICES) return;

        address buyer = (buyerSeed % 2 == 0) ? buyerA : buyerB;
        address provider = (providerSeed % 2 == 0) ? providerA : providerB;

        // Ensure valid future slotEnd > now and slotEnd > slotStart.
        uint64 nowTs = uint64(block.timestamp);

        // Constrain start in [now+1h, now+30d]
        uint64 start = nowTs + 1 hours + (startOffset % (30 days));

        // Constrain duration in [1h, 7d]
        uint64 dur = 1 hours + (duration % (7 days));
        uint64 end = start + dur;

        // Constrain amount in [1e6 .. 1e18] to avoid dust edge cases
        uint256 amt = 1e6 + (uint256(uint160(buyer)) % 1e18);

        vm.startPrank(buyer);
        (bytes32 serviceId, uint256 tokenId) =
            core.createService(provider, address(payToken), amt, serviceHash, start, end);
        vm.stopPrank();

        serviceIds.push(serviceId);

        // Cache expiresAt for warp helper
        (, , , , , , , uint64 expiresAt, ) = core.services(serviceId);
        lastExpiresAt = expiresAt;

        // Basic sanity: token minted to buyer
        assertEq(handle.ownerOf(tokenId), buyer);
    }

    /// @notice Attempt finalize as buyer (may revert if wrong buyerSeed/serviceSeed).
    function finalizeAsBuyer(uint256 buyerSeed, uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];
        (address buyer, , , , , , , , bool finalized) = core.services(serviceId);
        if (finalized) return;

        address caller = (buyerSeed % 2 == 0) ? buyerA : buyerB;
        vm.prank(caller);
        // Buyer finalize only succeeds if caller is actual buyer
        try core.finalize(serviceId) {} catch {}
        // no assertions here; invariants cover correctness
        buyer; // silence unused if optimizer rearranges
    }

    /// @notice Attempt finalize as provider (may revert if wrong providerSeed/serviceSeed).
    function finalizeAsProvider(uint256 providerSeed, uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];
        (, address provider, , , , , , , bool finalized) = core.services(serviceId);
        if (finalized) return;

        address caller = (providerSeed % 2 == 0) ? providerA : providerB;
        vm.prank(caller);
        // Provider finalize only succeeds if caller is actual provider
        try core.finalize(serviceId) {} catch {}
        provider; // silence unused
    }

    /// @notice Warp forward by a bounded amount to explore expiry edges.
    function warpForward(uint64 delta) external {
        // Constrain delta in [0, 120d]
        uint64 d = delta % (120 days);
        vm.warp(block.timestamp + d);
    }

    // Expose service count + ids for invariant contract.
    function servicesLength() external view returns (uint256) {
        return serviceIds.length;
    }

    function serviceIdAt(uint256 i) external view returns (bytes32) {
        return serviceIds[i];
    }
}

/// @title ActInvariants
/// @notice Production-grade invariant suite proving:
///   - handles (ERC-721) are non-transferable
///   - escrow cannot double-release
///   - after expiry, finalization is always possible (liveness) without relying on a platform
///   - fee math is bounded and does not exceed 0.5%
///   - settlement burns the handle token
contract ActInvariants is StdInvariant, Test {
    ActCore internal core;
    ActEscrow internal escrow;
    ActToken internal handle;
    MockERC20 internal payToken;

    address internal treasury;
    ActHandler internal handler;

    function setUp() external {
        treasury = address(0xTREA5);

        // Deploy protocol
        core = new ActCore(treasury);
        escrow = core.escrow();
        handle = core.token();

        // Deploy payment token
        payToken = new MockERC20();

        // Deploy handler (seeds balances/approvals)
        handler = new ActHandler(core, payToken, treasury);

        // Target handler for invariant fuzzing
        targetContract(address(handler));
    }

    // ----------------------------
    // Invariant: handle is non-transferable
    // ----------------------------
    function invariant_handleIsNonTransferable() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (, , , , , , , , bool finalized) = core.services(serviceId);
            uint256 tokenId = uint256(serviceId);

            if (finalized) {
                // Burned -> ownerOf must revert
                vm.expectRevert();
                handle.ownerOf(tokenId);
            } else {
                // Exists and cannot be transferred
                address owner = handle.ownerOf(tokenId);

                // Try to transfer; must revert always.
                vm.startPrank(owner);
                vm.expectRevert(ActToken.TransfersDisabled.selector);
                handle.transferFrom(owner, address(0xDEAD), tokenId);
                vm.stopPrank();
            }
        }
    }

    // ----------------------------
    // Invariant: escrow can’t be released twice; release implies immutable accounting.
    // ----------------------------
    function invariant_escrowNoDoubleRelease() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (address payer, address provider, address tokenAddr, uint256 amount, uint64 expiresAt, bool released) =
                escrow.escrows(serviceId);

            // For created services, escrow must be well-formed.
            // Note: payer/provider can be checked against core.service data as well.
            if (amount != 0) {
                assertTrue(payer != address(0));
                assertTrue(provider != address(0));
                assertEq(tokenAddr, address(payToken));
                assertTrue(expiresAt != 0);

                if (released) {
                    // Snapshot -> calling release again must revert (core-only, already released)
                    uint256 snap = vm.snapshot();
                    vm.startPrank(address(core));
                    vm.expectRevert(ActEscrow.AlreadyReleased.selector);
                    escrow.release(serviceId);
                    vm.stopPrank();
                    vm.revertTo(snap);
                }
            }
        }
    }

    // ----------------------------
    // Invariant: fee math bounded (<= 0.5%); settlement conserves value
    // ----------------------------
    function invariant_feeBoundedAndConservesValue() external {
        uint256 n = handler.servicesLength();

        // Compute expected escrowed balance = sum of amounts for unreleased escrows
        uint256 expectedEscrowBal = 0;

        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (, , , uint256 amount, , bool released) = escrow.escrows(serviceId);
            if (amount == 0) continue;

            uint256 fee = (amount * escrow.FEE_BPS()) / escrow.BPS_DENOM();
            assertLe(fee, (amount * 50) / 10_000); // explicit 0.5% cap

            if (!released) expectedEscrowBal += amount;
        }

        // Escrow contract balance should match outstanding unreleased sums.
        // This is true because funding is atomic: buyer -> escrow on create, and release drains that escrow entry.
        assertEq(payToken.balanceOf(address(escrow)), expectedEscrowBal);
    }

    // ----------------------------
    // Invariant: liveness (funds cannot be locked indefinitely)
    //
    // For any service not yet finalized, it must always be possible to finalize
    // by the buyer/provider at any time, or by anyone after expiry.
    //
    // We prove "possibility" without mutating global state by using snapshot/revert.
    // ----------------------------
    function invariant_liveness_finalizeAlwaysPossible() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (
                address buyer,
                address provider,
                ,
                ,
                ,
                ,
                ,
                uint64 expiresAt,
                bool finalized
            ) = core.services(serviceId);

            if (buyer == address(0) || finalized) continue;

            // Snapshot and prove one of the allowed finalizers can always settle.
            uint256 snap = vm.snapshot();

            if (block.timestamp < expiresAt) {
                // Buyer can finalize anytime
                vm.prank(buyer);
                core.finalize(serviceId);
            } else {
                // Anyone can finalize after expiry
                vm.prank(address(0xF1NAL1ZER));
                core.finalize(serviceId);
            }

            // After finalize: token burned + escrow released
            uint256 tokenId = uint256(serviceId);
            vm.expectRevert();
            handle.ownerOf(tokenId);

            (, , , , , bool released) = escrow.escrows(serviceId);
            assertTrue(released);

            vm.revertTo(snap);
        }
    }

    // ----------------------------
    // Invariant: finalize authorization cannot be bypassed pre-expiry
    // ----------------------------
    function invariant_noUnauthorizedFinalizeBeforeExpiry() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (address buyer, address provider, , , , , , uint64 expiresAt, bool finalized) = core.services(serviceId);

            if (buyer == address(0) || finalized) continue;

            if (block.timestamp < expiresAt) {
                uint256 snap = vm.snapshot();

                // A random address must not be able to finalize before expiry.
                vm.prank(address(0xBAD));
                vm.expectRevert(ActCore.NotAuthorized.selector);
                core.finalize(serviceId);

                // But buyer/provider must still be able to
                vm.prank(buyer);
                core.finalize(serviceId);

                vm.revertTo(snap);
                provider; // silence unused
            }
        }
    }
}
