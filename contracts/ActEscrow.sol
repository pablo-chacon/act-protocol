// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ActEscrow {
    struct Escrow {
        address payer;
        address provider;
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
    error ZeroAmount();
    error AlreadyLocked();
    error AlreadyReleased();
    error OnlyCore();
    error PayoutFailed();
    error FeeFailed();

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

    function lock(
        bytes32 serviceId,
        address payer,
        address provider,
        uint64 expiresAt
    ) external payable onlyCore {
        if (msg.value == 0) revert ZeroAmount();

        Escrow storage e = escrows[serviceId];
        if (e.amount != 0) revert AlreadyLocked();

        escrows[serviceId] = Escrow({
            payer: payer,
            provider: provider,
            amount: msg.value,
            expiresAt: expiresAt,
            released: false
        });
    }

    function release(bytes32 serviceId) external onlyCore {
        Escrow storage e = escrows[serviceId];
        if (e.released) revert AlreadyReleased();

        e.released = true;

        uint256 fee = (e.amount * FEE_BPS) / BPS_DENOM;
        uint256 payout = e.amount - fee;

        if (fee > 0) {
            (bool okFee, ) = payable(treasury).call{value: fee}("");
            if (!okFee) revert FeeFailed();
        }

        (bool okPay, ) = payable(e.provider).call{value: payout}("");
        if (!okPay) revert PayoutFailed();
    }
}
