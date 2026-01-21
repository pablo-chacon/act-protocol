
---

# ACT Protocol

**Autonomous Contract for Services**

ACT is a **minimal, neutral Ethereum settlement protocol** for real-world, non-digital services.

Examples include: personal training, massage, psychologist sessions, cleaning, consulting, repairs, construction, contracting, and other services performed outside the blockchain.

Authors of ACT Protocol is **NOT** responsible in any way for any kind of service registered. 

ACT does not operate a marketplace, does not verify service delivery, and does not manage identity, reputation, scheduling, or disputes.

ACT is a protocol, not a platform.

---

## Design Goals

ACT is designed to be:

* minimal
* deterministic
* neutral
* immutable
* composable
* privacy-preserving

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
* no emergency controls

All behavior is fully defined by the deployed contracts.

Once deployed, ACT is never changed.

---

## Core Concept

Each service instance is represented by a **non-transferable ERC-721 service handle**.

Properties:

* 1 tokenId == 1 service instance
* token is mint-only and burn-only
* transfers are disabled
* approvals are disabled
* token cannot be traded, reused, or accumulated
* token is always burned on settlement

The token has **no financial or speculative purpose**.

It exists solely as cryptographic proof of a single service settlement lifecycle.

---

## Service Lifecycle

ACT separates **service offering** from **service acceptance**.

This protects both buyers and service providers and enables open on-chain price discovery.

---

### 1. Create Service Offer

The **service provider** creates a service offer on-chain.

Inputs:

* `paymentToken` -> ERC-20 token required for settlement
* `amount` -> price for the service
* `serviceHash` -> hash of off-chain service terms
* `slotStart` -> platform-defined start boundary
* `slotEnd` -> platform-defined end boundary

Notes:

* no funds are moved
* no token is minted
* offers are immutable once published
* offers are publicly discoverable on-chain

Slot meaning is entirely platform-defined.

ACT does not interpret schedules, deadlines, or SLAs.

Slot bounds are used only to compute a deterministic force-finalization time.

---

### 2. Accept Service Offer

A **buyer** accepts a published service offer.

On acceptance:

* ERC-20 funds are transferred into escrow
* a non-transferable ERC-721 handle is minted to the buyer
* the service becomes active

The service handle represents the buyer’s cryptographic claim on settlement.

---

### 3. Finalize Service

Finalization rules are deterministic:

* buyer can finalize at any time
* provider can finalize at any time
* anyone can finalize after `expiresAt`

On finalization:

* escrow releases funds
* provider receives payout
* protocol fee is sent to treasury
* service handle token is burned

Finalization is irreversible.

There is no rollback.

---

## Deterministic Expiry

For every service offer, the protocol computes a force-finalization time:

```
expiresAt = slotEnd + (slotLength / 4) + 72 hours
```

This guarantees liveness without encoding service semantics.

Funds can never be locked indefinitely.

---

## Escrow Guarantees

ACT guarantees:

* buyers cannot lock funds indefinitely
* providers cannot be unpaid indefinitely
* settlement always becomes force-finalizable
* protocol cannot intervene
* outcomes are deterministic and auditable

ACT does **not** guarantee:

* service quality
* service completion
* deadline compliance
* customer satisfaction
* dispute resolution

Those are platform responsibilities.

---

## Extensions and Overruns

If a service exceeds its expected scope or duration, for example a construction or kitchen build running late:

* ACT does not renegotiate
* ACT does not amend escrows
* ACT does not extend deadlines

The recommended pattern is:

* parties agree off-chain
* a **new service offer** is created
* a **new handle token** represents the extension
* a **new escrow** represents additional payment

This preserves determinism and auditability.

---

## Protocol Fee

ACT enforces a fixed, immutable protocol fee:

* **0.5% (50 bps)** of the escrowed amount
* paid to the protocol treasury
* treasury address is immutable

No platform fees are enforced by the protocol.

---

## Currency Neutrality

ACT is **currency-agnostic at the platform layer**.

On-chain settlement uses ERC-20 tokens only.

Platforms may accept any inbound payment rail, including:

* ETH
* ERC-20 tokens
* Bitcoin
* Monero
* Fiat
* Lightning
* Any other payment system

Before interacting with ACT:

* platforms convert inbound payments into an ERC-20 token
* buyers approve ACT to transfer that ERC-20 token

ACT itself performs no conversion.

---

## Privacy Boundaries

To preserve neutrality and privacy, ACT never stores:

* service descriptions
* locations
* identities
* communications
* jurisdictions
* ratings or reputation
* metadata that identifies the service

Only an opaque `serviceHash` is stored on-chain.

All identifying information remains off-chain.

---

## What ACT Does Not Do

ACT intentionally does not handle:

* discovery or search
* pricing logic beyond published offers
* identity, KYC, or AML
* scheduling or messaging
* disputes or arbitration
* refunds or chargebacks
* reputation systems
* taxation or compliance

All of the above are platform concerns.

---

## Contract Architecture

```
contracts/
├── ActCore.sol    -> service offer, acceptance, and finalization
├── ActEscrow.sol  -> ERC-20 escrow and protocol fee enforcement
└── ActToken.sol   -> non-transferable ERC-721 service handle
```

---

## Non-Speculative Guarantees

ACT service handles are not assets.

* no transfers
* no secondary markets
* no accumulation
* no partial settlement
* guaranteed burn on completion

They exist solely as deterministic settlement proofs.

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

All deployments and integrations are performed at the sole risk of deployers and users.

This software is provided “as is”, without warranty of any kind.

---

