
---

# ACT Protocol

**Autonomous Contract for Services**

ACT is a **minimal, neutral Ethereum settlement protocol** for real-world physical services.

Examples include personal training, massage, cleaning, consulting, repairs, and other services performed outside the blockchain.

ACT does not operate a marketplace, does not verify service delivery, and does not manage identity, reputation, or disputes.

ACT is a protocol, not a platform.

---

## Design Goals

ACT is designed to be:

* minimal
* deterministic
* neutral
* immutable
* composable

The protocol does exactly one thing:

> **It escrow-settles a single real-world service instance.**

Everything else is intentionally out of scope.

---

## Protocol Finality

ACT is finished infrastructure.

* no upgrades
* no governance
* no admin intervention
* no mutable parameters

All behavior is fully defined by the deployed contracts.

Once deployed, ACT cannot be changed.

---

## Core Concept

Each service instance is represented by a **non-transferable ERC-20 service handle**.

Properties:

* 1 token == 1 service instance
* token is mint-only and burn-only
* transfers are disabled
* token cannot be traded or reused
* token is always burned on settlement

The token has **no financial or speculative purpose**.

It exists only to represent the lifecycle of a service escrow.

---

## Service Lifecycle

### 1. Create Service

The buyer creates a service instance by locking payment into escrow.

Inputs:

* `provider` -> service provider address
* `serviceHash` -> hash of off-chain service terms
* `expiresAt` -> finalization deadline

Actions:

* escrow locks funds
* 1 ACT token is minted to the buyer

---

### 2. Finalize Service

Finalization rules are deterministic:

* buyer can finalize at any time
* provider can finalize at any time
* anyone can finalize after `expiresAt`

On finalization:

* escrow releases funds
* provider receives payout
* protocol fee is sent to treasury
* ACT token is burned

There is no rollback.

---

## Escrow Guarantees

ACT guarantees:

* buyer cannot lock funds indefinitely
* provider cannot be unpaid after expiry
* protocol cannot intervene
* outcome is deterministic

ACT does **not** guarantee:

* service quality
* service completion
* customer satisfaction

Those are platform responsibilities.

---

## Protocol Fee

ACT enforces a fixed, immutable protocol fee:

* **0.5% (50 bps)** of the escrowed amount
* paid to the protocol treasury
* treasury address is immutable

No platform fees are enforced by the protocol.

---

## Currency Neutrality

ACT is ERC-20 based internally but currency agnostic at the platform layer.

Platforms may accept:

* ETH
* ERC-20 tokens
* Bitcoin
* Monero
* Fiat
* Lightning
* Any other payment rail

Inbound payments must be converted to an ERC-20 compatible asset **before** interacting with ACT.

ACT itself does not perform conversion.

---

## What ACT Does Not Do

ACT intentionally does not handle:

* discovery or search
* pricing logic
* identity or KYC
* scheduling or messaging
* disputes or arbitration
* refunds or chargebacks
* reputation systems
* taxation or compliance

All of the above must be handled off-chain by integrating platforms.

---

## Contract Architecture

```
contracts/
├── ActCore.sol
├── ActEscrow.sol
└── ActToken.sol
```

### ActCore.sol

* orchestrates service lifecycle
* validates expiry
* triggers escrow release
* burns ACT tokens

### ActEscrow.sol

* holds locked funds
* releases on finalization
* enforces protocol fee

### ActToken.sol

* restricted ERC-20 implementation
* mint and burn only
* transfers disabled

---

## Non-Speculative Guarantees

ACT tokens are not assets.

* no transfers
* no secondary markets
* no partial fills
* no accumulation
* guaranteed burn

The token exists solely to track service settlement state.

---

## Composability

ACT composes cleanly with other neutral settlement rails:

* DeBNB -> accommodation
* DeDe -> delivery
* KEY -> vehicles
* PASS -> access
* CUT -> media

Platforms may combine these protocols freely without coordination or permission.

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts implementing a neutral settlement protocol.

The authors and contributors:

* do not operate a service marketplace or platform
* do not verify or supervise service providers or customers
* do not guarantee service delivery or outcomes
* do not perform KYC, AML, or identity verification
* do not provide legal, financial, or regulatory advice

All deployments and integrations are performed at the sole risk of the deployer and users.

This software is provided “as is”, without warranty of any kind.

---
