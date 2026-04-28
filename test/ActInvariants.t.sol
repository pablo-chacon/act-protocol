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

    // Handler actions
    /// @notice Provider creates a service offer with bounded slots.
    function createOffer(
        uint256 providerSeed,
        uint64 startOffset,
        uint64 duration,
        bytes32 serviceHash
    ) external {
        if (serviceIds.length >= MAX_SERVICES) return;

        address provider = (providerSeed % 2 == 0) ? providerA : providerB;

        uint64 nowTs = uint64(block.timestamp);

        // Constrain start in [now+1h, now+30d]
        uint64 start = nowTs + 1 hours + (startOffset % (30 days));

        // Constrain duration in [1h, 7d]
        uint64 dur = 1 hours + (duration % (7 days));
        uint64 end = start + dur;

        // Constrain amount in [1e6 .. 1e18] without needing extra seeds
        uint256 amt = 1e6 + (uint256(uint160(provider)) % 1e18);

        vm.startPrank(provider);
        bytes32 serviceId = core.createServiceOffer(
            address(payToken),
            amt,
            serviceHash,
            start,
            end
        );
        vm.stopPrank();

        serviceIds.push(serviceId);
    }

    /// @notice Buyer accepts an existing offer and funds escrow. Mints handle to buyer.
    function acceptOffer(uint256 buyerSeed, uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];

        (
            address buyer,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool accepted,
            bool finalized
        ) = core.services(serviceId);

        if (finalized) return;
        if (accepted) return;
        if (buyer != address(0)) return; // sanity

        address buyerAddr = (buyerSeed % 2 == 0) ? buyerA : buyerB;

        vm.startPrank(buyerAddr);
        try core.acceptService(serviceId) returns (uint256 tokenId) {
            // Basic sanity: token minted to buyer
            assertEq(handle.ownerOf(tokenId), buyerAddr);

            // Escrow entry must exist and be unreleased immediately after accept
            (, , , uint256 amount, , bool released) = escrow.escrows(serviceId);
            assertTrue(amount != 0);
            assertTrue(!released);
        } catch {}
        vm.stopPrank();
    }

    /// @notice Attempt finalize as buyer (may revert if not accepted, wrong buyer, or already finalized).
    function finalizeAsBuyer(uint256 buyerSeed, uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];
        (address buyer, , , , , , , , bool accepted, bool finalized) = core.services(serviceId);
        if (!accepted || finalized) return;

        address caller = (buyerSeed % 2 == 0) ? buyerA : buyerB;
        vm.prank(caller);
        try core.finalize(serviceId) {} catch {}
        buyer; // silence unused
    }

    /// @notice Attempt finalize as provider (may revert if not accepted, wrong provider, or already finalized).
    function finalizeAsProvider(uint256 providerSeed, uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];
        (, address provider, , , , , , , bool accepted, bool finalized) = core.services(serviceId);
        if (!accepted || finalized) return;

        address caller = (providerSeed % 2 == 0) ? providerA : providerB;
        vm.prank(caller);
        try core.finalize(serviceId) {} catch {}
        provider; // silence unused
    }

    /// @notice Attempt finalize as random address. Only valid after expiry.
    function finalizeAsRando(uint256 serviceSeed) external {
        if (serviceIds.length == 0) return;

        bytes32 serviceId = serviceIds[serviceSeed % serviceIds.length];
        (, , , , , , , uint64 expiresAt, bool accepted, bool finalized) = core.services(serviceId);
        if (!accepted || finalized) return;

        vm.prank(rando);
        if (block.timestamp < expiresAt) {
            // Must not be allowed pre-expiry
            try core.finalize(serviceId) {
                fail("rando finalized before expiry");
            } catch {}
        } else {
            // May succeed after expiry
            try core.finalize(serviceId) {} catch {}
        }
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
/// @notice Invariant suite proving:
///   - handle (ERC-721) is non-transferable and only exists after acceptance
///   - escrow cannot double-release
///   - after expiry, finalization is always possible (liveness)
///   - fee math is bounded and does not exceed 0.5%
///   - settlement burns the handle token
///   - finalize authorization cannot be bypassed pre-expiry
contract ActInvariants is StdInvariant, Test {
    ActCore internal core;
    ActEscrow internal escrow;
    ActToken internal handle;
    MockERC20 internal payToken;

    address internal treasury;
    ActHandler internal handler;

    function setUp() external {
        treasury = address(0x000000000000000000000000000000000000dEaD);

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

    // Invariant: handle exists only after acceptance and is non-transferable
    function invariant_handleNonTransferableAndLifecycleCorrect() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);

            (
                address buyer,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                bool accepted,
                bool finalized
            ) = core.services(serviceId);

            uint256 tokenId = uint256(serviceId);

            if (!accepted) {
                // Not accepted -> token must not exist
                vm.expectRevert();
                handle.ownerOf(tokenId);
                continue;
            }

            if (finalized) {
                // Finalized -> burned -> ownerOf must revert
                vm.expectRevert();
                handle.ownerOf(tokenId);
            } else {
                // Accepted and not finalized -> token exists for buyer and cannot be transferred
                address owner = handle.ownerOf(tokenId);
                assertEq(owner, buyer);

                vm.startPrank(owner);
                vm.expectRevert(ActToken.TransfersDisabled.selector);
                handle.transferFrom(owner, address(0x000000000000000000000000000000000000dEaD), tokenId);
                vm.stopPrank();
            }
        }
    }

    // Invariant: escrow cannot be released twice (and only core can release)
    function invariant_escrowNoDoubleRelease() external {
        uint256 n = handler.servicesLength();
        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);

            (address payer, address provider, address tokenAddr, uint256 amount, uint64 expiresAt, bool released) =
                escrow.escrows(serviceId);

            // Escrow only exists after acceptance
            if (amount == 0) continue;

            assertTrue(payer != address(0));
            assertTrue(provider != address(0));
            assertEq(tokenAddr, address(payToken));
            assertTrue(expiresAt != 0);

            if (released) {
                uint256 snap = vm.snapshot();

                // Non-core must never be able to release
                vm.prank(address(0xBAD));
                vm.expectRevert(ActEscrow.OnlyCore.selector);
                escrow.release(serviceId);

                // Core cannot release twice
                vm.startPrank(address(core));
                vm.expectRevert(ActEscrow.AlreadyReleased.selector);
                escrow.release(serviceId);
                vm.stopPrank();

                vm.revertTo(snap);
            }
        }
    }

    // Invariant: fee bounded (<= 0.5%) and escrow balance equals outstanding unreleased sums
    function invariant_feeBoundedAndEscrowBalanceCorrect() external {
        uint256 n = handler.servicesLength();

        uint256 expectedEscrowBal = 0;

        for (uint256 i = 0; i < n; i++) {
            bytes32 serviceId = handler.serviceIdAt(i);
            (, , , uint256 amount, , bool released) = escrow.escrows(serviceId);
            if (amount == 0) continue;

            uint256 fee = (amount * escrow.FEE_BPS()) / escrow.BPS_DENOM();
            assertLe(fee, (amount * 50) / 10_000);

            if (!released) expectedEscrowBal += amount;
        }

        assertEq(payToken.balanceOf(address(escrow)), expectedEscrowBal);
    }

    // ----------------------------
    // Invariant: liveness (funds cannot be locked indefinitely)
    //
    // For any accepted service not finalized:
    // - buyer or provider can finalize pre-expiry
    // - anyone can finalize after expiry
    // We prove possibility via snapshot/revert.
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
                bool accepted,
                bool finalized
            ) = core.services(serviceId);

            if (!accepted || finalized) continue;

            uint256 snap = vm.snapshot();

            if (block.timestamp < expiresAt) {
                // Buyer can always finalize pre-expiry
                vm.prank(buyer);
                core.finalize(serviceId);
            } else {
                // Anyone can finalize after expiry
                vm.prank(address(0x000000000000000000000000000000000000dEaD));
                core.finalize(serviceId);
            }

            // After finalize: token burned + escrow released
            uint256 tokenId = uint256(serviceId);
            vm.expectRevert();
            handle.ownerOf(tokenId);

            (, , , , , bool released) = escrow.escrows(serviceId);
            assertTrue(released);

            vm.revertTo(snap);

            provider; // silence unused in some optimizer paths
        }
    }

    // ----------------------------
    // Invariant: finalize authorization cannot be bypassed pre-expiry
    // ----------------------------
    function invariant_noUnauthorizedFinalizeBeforeExpiry() external {
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
                bool accepted,
                bool finalized
            ) = core.services(serviceId);

            if (!accepted || finalized) continue;

            if (block.timestamp < expiresAt) {
                uint256 snap = vm.snapshot();

                // Random address must not be able to finalize before expiry
                vm.prank(address(0xBAD));
                vm.expectRevert(ActCore.NotAuthorized.selector);
                core.finalize(serviceId);

                // Buyer must be able to finalize
                vm.prank(buyer);
                core.finalize(serviceId);

                vm.revertTo(snap);
            }

            provider; // silence unused in some optimizer paths
        }
    }
}
