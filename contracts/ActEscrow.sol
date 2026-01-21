// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActEscrow {
    using SafeERC20 for IERC20;

    struct Escrow {
        address payer;
        address provider;
        address paymentToken; // ERC-20
        uint256 amount;
        uint64 expiresAt;
        bool released;
    }

    mapping(bytes32 => Escrow) public escrows;

    address public immutable treasury;
    address public immutable core;

    uint16 public constant FEE_BPS = 50;      // 0.5%
    uint16 public constant BPS_DENOM = 10_000;

    error InvalidTreasury();
    error InvalidCore();
    error InvalidToken();
    error ZeroAmount();
    error ZeroProvider();
    error AlreadyLocked();
    error AlreadyReleased();
    error InvalidEscrow();
    error OnlyCore();

    modifier onlyCore() {
        if (msg.sender != core) revert OnlyCore();
        _;
    }

    constructor(address _treasury, address _core) {
        if (_treasury == address(0)) revert InvalidTreasury();
        if (_core == address(0)) revert InvalidCore();
        treasury = _treasury;
        core = _core;
    }

    /// @notice Records an escrow that has already been funded (tokens transferred in by core).
    function lock(
        bytes32 serviceId,
        address payer,
        address provider,
        address paymentToken,
        uint256 amount,
        uint64 expiresAt
    ) external onlyCore {
        if (amount == 0) revert ZeroAmount();
        if (provider == address(0)) revert ZeroProvider();
        if (paymentToken == address(0)) revert InvalidToken();

        Escrow storage e = escrows[serviceId];
        if (e.amount != 0) revert AlreadyLocked();

        escrows[serviceId] = Escrow({
            payer: payer,
            provider: provider,
            paymentToken: paymentToken,
            amount: amount,
            expiresAt: expiresAt,
            released: false
        });
    }

    /// @notice Releases escrowed funds (core-only).
    function release(bytes32 serviceId) external onlyCore {
        Escrow storage e = escrows[serviceId];
        if (e.amount == 0) revert InvalidEscrow();
        if (e.released) revert AlreadyReleased();

        e.released = true;

        uint256 fee = (e.amount * FEE_BPS) / BPS_DENOM;
        uint256 payout = e.amount - fee;

        IERC20 t = IERC20(e.paymentToken);

        if (fee > 0) t.safeTransfer(treasury, fee);
        t.safeTransfer(e.provider, payout);
    }
}
