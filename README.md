# ACT Protocol

**Autonomous Contract for Services**

ACT is a minimal, neutral Ethereum settlement protocol for real-world, non-digital services.

Examples include personal training, massage, psychologist sessions, cleaning, consulting, repairs, construction, contracting, and other services performed outside the blockchain.

Authors of ACT Protocol are not responsible in any way for any kind of service registered.

ACT does not operate a marketplace, does not verify service delivery, and does not manage identity, reputation, scheduling, safety, disputes, or compliance.

ACT is a protocol, not a platform.

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts implementing a neutral settlement protocol.

The authors and contributors:

* do not operate a service marketplace or platform
* do not verify or supervise service providers or customers
* do not guarantee service delivery or outcomes
* do not perform KYC, AML, or identity verification
* do not provide legal, financial, or regulatory advice
* are not responsible for deployments, integrations, or real-world usage

All deployments of ACT Protocol are performed at the risk of the deployer and the integrating platform.

No warranty of any kind is provided.
The software is offered strictly as-is, without guarantees of fitness for any purpose.
The authors are not liable for any damages, losses, claims, or issues arising from the use, misuse, or failure of this software or any derivative work.

By using, deploying, integrating, or interacting with this software in any form, you agree that all responsibility for legal compliance, operation, and outcomes lies solely with you.

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

> It escrow-settles a single real-world service instance.

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

Each accepted service instance is represented by a non-transferable ERC-721 service handle.

Properties:

* 1 tokenId == 1 accepted service instance
* token is mint-only and burn-only
* transfers are disabled
* approvals are disabled
* token cannot be traded, reused, or accumulated
* token is always burned on settlement

The token has no financial or speculative purpose.

It exists solely as cryptographic proof of a single service settlement lifecycle and as an authorization handle for off-chain booking data controlled by the integrating platform.

---

## Service Lifecycle

ACT separates service offering from service acceptance.

The lifecycle is strictly deterministic:

provider -> create offer
buyer -> accept offer and fund escrow
buyer or provider -> finalize
anyone -> finalize after expiry

ACT does not interpret the service itself. It only enforces settlement rules.

---

### 1. Create Service Offer

The service provider creates a service offer on-chain.

Inputs:

* `paymentToken` -> ERC-20 token required for settlement
* `amount` -> price for the service
* `serviceHash` -> hash commitment to off-chain service terms
* `slotStart` -> platform-defined start boundary
* `slotEnd` -> platform-defined end boundary

Notes:

* no funds are moved
* no token is minted
* offers are immutable once published
* offers are publicly discoverable on-chain
* ACT does not validate availability, location, identity, or safety

The `serviceHash` is an opaque commitment to off-chain booking data such as time, place, safety requirements, cancellation terms, or identity checks. ACT never stores that data.

---

### 2. Accept Service Offer

A buyer accepts a published service offer.

On acceptance:

* ERC-20 funds are transferred into escrow
* a non-transferable ERC-721 handle is minted to the buyer
* the service becomes active

Acceptance is the economic commitment point.

From this moment, settlement is guaranteed by protocol rules.

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
There is no arbitration logic.

---

## Deterministic Expiry

For every accepted service, the protocol computes a force-finalization time:

```
expiresAt = slotEnd + (slotLength / 4) + 72 hours
```

This guarantees liveness without encoding service semantics.

Funds can never be locked indefinitely.

---

## Settlement Model and Responsibility Boundary

ACT is intentionally dispute-free at the protocol level.

Once a buyer accepts a service offer:

* funds are escrowed
* settlement is guaranteed
* provider payout is enforced by protocol rules upon finalization

ACT does not determine whether a service was performed correctly.

ACT does not implement refunds, arbitration, chargebacks, or mediation.

Protection mechanisms such as:

* identity verification
* fraud prevention
* cancellation policies
* safety screening
* no-show handling
* dispute resolution
* insurance
* buyer protection funds

must be implemented by the integrating platform.

ACT is a neutral settlement rail. Platforms are responsible for real-world coordination and risk management.

---

## Extensions and Overruns

If a service exceeds its expected scope or duration, for example a construction project running late:

* ACT does not renegotiate
* ACT does not amend escrows
* ACT does not extend deadlines

Recommended pattern:

parties agree off-chain ->
provider creates new offer ->
buyer accepts new offer ->
new handle represents extension ->
new escrow represents additional payment

This preserves determinism and auditability.

---

## Protocol Fee

ACT enforces a fixed, immutable protocol fee:

* 0.5 percent of the escrowed amount
* paid to the protocol treasury
* treasury address is immutable

No platform fees are enforced by the protocol.

---

## Currency Neutrality

ACT is currency-neutral at the platform layer.

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

platform converts inbound payments into an ERC-20 token ->
buyer approves ACT to transfer that ERC-20 token ->
ACT escrows and settles that ERC-20 token

ACT performs no currency conversion and has no knowledge of off-chain payment rails.

---

## Privacy Boundaries

ACT never stores:

* service descriptions
* locations
* personal identities
* communications
* jurisdictions
* ratings or reputation
* booking metadata

Only an opaque `serviceHash` is stored on-chain.

All identifying information remains off-chain under platform control.

The service handle token contains no descriptive metadata and has no transfer functionality.

---

## What ACT Does Not Do

ACT intentionally does not handle:

* service registry or marketplace logic
* discovery or ranking
* identity, KYC, or AML
* scheduling or messaging
* disputes or arbitration
* refunds or chargebacks
* reputation systems
* taxation or compliance
* safety enforcement

All of the above are platform responsibilities.

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
* no fractionalization
* guaranteed burn on settlement

They exist solely as deterministic settlement proofs.

---

## Contact

**[Contact Email](pablo-chacon-ai@proton.me)**
