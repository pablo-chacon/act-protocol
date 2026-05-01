# **ACT Protocol Whitepaper**

**Neutral Settlement Infrastructure for Real-World Services**

---

## Abstract

ACT Protocol is a minimal, immutable settlement rail for peer-to-peer real-world services.
It provides trustless escrow, deterministic finalization, and time-bounded fund release without verifying service delivery, enforcing safety, or mediating disputes.

ACT is not a marketplace, not a service directory, and not a governance system.
It is infrastructure.

Once deployed, ACT requires no operators, administrators, or maintainers.
Its behavior is fully defined by immutable smart contracts and Ethereum consensus.

---

## 1. Motivation

Real-world service providers operate in conditions of asymmetric vulnerability.

A personal trainer, massage therapist, or psychologist accepts a session before payment is confirmed.
A contractor, mechanic, or cleaner performs work before settlement is guaranteed.
A consultant delivers value before funds are released.

Centralized platforms that attempt to solve this problem introduce their own asymmetries:

* Custody of funds controlled by the platform
* Mutable fee structures extracted from both parties
* Dispute arbitration that is opaque, slow, and biased by platform incentives
* Identity requirements that create surveillance and exclusion
* Data extraction as a condition of access
* Platform governance that changes the rules unilaterally

ACT separates **settlement** from **platform behavior**.

By removing discretion, identity enforcement, and governance from the settlement layer, ACT enables any platform, application, or individual to provide real-world service settlement without depending on a central authority.

---

## 2. Design Principles

ACT is built on five non-negotiable principles:

1. **Neutrality**
   The protocol does not evaluate, verify, rank, or control services or participants.

2. **Finality**
   The protocol is finished infrastructure with no upgrade path.

3. **Determinism**
   Outcomes are derived solely from on-chain state, time, and ERC-20 balances.

4. **Permissionlessness**
   Anyone may integrate ACT, create service offers, or trigger auto-finalization.

5. **Non-Extractive Economics**
   The protocol enforces a single, immutable fee and nothing more.

---

## 3. Scope and Non-Goals

### In Scope

* Trustless escrow for service payments
* Deterministic finalization logic
* Time-bounded fund release
* Cryptographic service commitment via hash anchoring
* Non-transferable settlement proof via ERC-721 handle

### Explicitly Out of Scope

* Service discovery, ranking, or listings
* Identity, KYC, AML, or background screening
* Compliance, taxation, or regulation
* Dispute resolution or arbitration
* Safety enforcement or service quality evaluation
* Refunds, chargebacks, or insurance
* Scheduling, messaging, or platform coordination
* UX, APIs, or governance

All such concerns must be handled **off-chain** or **above** the protocol.

This boundary is not a limitation. It is the architecture.

---

## 4. System Overview

ACT consists of three immutable on-chain components:

### 4.1 ActCore

The settlement state machine governing:

* Service offer creation and lifecycle
* Offer acceptance and escrow funding
* Dual-party and single-party finalization
* Deterministic expiry computation
* Fee enforcement

ActCore has no owner, no admin keys, and no governance logic.

---

### 4.2 ActEscrow

A value-holding contract that:

* Holds ERC-20 funds during the service lifecycle
* Releases funds only when instructed by ActCore
* Enforces the immutable protocol fee on every settlement

ActEscrow is permanently bound to ActCore at deployment and cannot be repointed.

---

### 4.3 ActToken

A non-transferable ERC-721 service handle that:

* Is minted to the buyer on service acceptance
* Serves as a deterministic reference for the service lifecycle
* Cannot be transferred, approved, or traded
* Is burned on finalization

The token has no financial or speculative purpose.
It exists solely as cryptographic proof of a single service settlement lifecycle.

---

## 5. Service Lifecycle

ACT separates service offering from service acceptance.

The full lifecycle is deterministic and permissionless:

```
provider    -> createServiceOffer()
buyer       -> acceptService()       [escrow funded, handle minted]
buyer       -> finalizeService()     [at any time]
provider    -> finalizeService()     [after slotStart]
anyone      -> finalizeService()     [after expiresAt]
```

ACT does not interpret the service itself. It only enforces settlement rules.

---

### 5.1 Service Offer

The provider creates an on-chain service offer specifying:

* `paymentToken` — ERC-20 token required for settlement
* `amount` — price for the service
* `serviceHash` — cryptographic commitment to off-chain service terms
* `slotStart` — platform-defined start boundary
* `slotEnd` — platform-defined end boundary

No funds are moved at this stage.
Offers are immutable once published.
Offers are publicly discoverable on-chain.

The `serviceHash` is an opaque commitment to off-chain terms such as time, location, safety requirements, cancellation policies, or identity checks. ACT never stores that data. The hash is the on-chain proof that those terms existed at acceptance time.

Offers automatically expire at `slotStart + slotLength / 2`. A service cannot be accepted after its midpoint has passed.

---

### 5.2 Service Acceptance

A buyer accepts a published offer.

On acceptance:

* ERC-20 funds are transferred into escrow
* A non-transferable ERC-721 handle is minted to the buyer
* The service enters the active state

Acceptance is the economic commitment point.

From this moment, settlement is guaranteed by protocol rules. Funds will always be released. They cannot be frozen indefinitely.

---

### 5.3 Finalization

Finalization rules are deterministic:

* The buyer may finalize at any time after acceptance
* The provider may finalize at any time after `slotStart`
* Anyone may finalize after `expiresAt`

On finalization:

* Escrow releases funds to the provider
* Protocol fee is sent to the treasury
* The service handle token is burned

Finalization is irreversible. There is no rollback and no arbitration logic.

---

## 6. Deterministic Expiry

For every accepted service, the protocol computes a force-finalization time:

```
expiresAt = slotEnd + (slotLength / 4) + 72 hours
```

This guarantees liveness without encoding any knowledge of the service itself.

The formula provides a grace period proportional to slot length, plus a fixed 72-hour buffer. For short sessions such as a 1-hour massage, expiry occurs approximately 73 hours after the session ends. For long projects such as a multi-week construction contract, the grace period scales accordingly.

Funds can never be locked indefinitely. Time is the only arbitrator.

---

## 7. The Responsibility Boundary

The most important architectural decision in ACT is where the protocol ends and where the platform begins.

ACT's trust model is not that all services are honest. It is that **protection happens before `acceptService()` is called.**

By the time a buyer accepts a service offer, the platform has already:

* Verified identity or credentials if required
* Communicated cancellation and refund policies
* Performed safety screening appropriate to the service type
* Established jurisdiction-specific legal terms
* Converted inbound payment into an ERC-20 token

The `serviceHash` cryptographically anchors all of this off-chain work to the on-chain record. The hash is stored permanently. The plaintext terms remain off-chain under platform control. This is sufficient — and it is more legally enforceable than any on-chain arbitration mechanism could be, because the platform's terms can be jurisdiction-aware, service-type-aware, and legally binding in ways that immutable smart contract logic cannot be.

ACT's guarantee is not that services are performed correctly. ACT's guarantee is that funds always move and never get stuck.

---

## 8. Economic Model

### 8.1 Protocol Fee

* **0.5% (50 basis points)**
* Hard-coded and immutable
* Paid automatically to the protocol treasury on every finalization

The fee cannot be changed, removed, or bypassed.

---

### 8.2 Platform Fees

Platforms handle their own fee structures entirely off-chain.

The protocol has no knowledge of business models, pricing strategies, or revenue distribution between parties and platforms.

---

### 8.3 Currency Neutrality

ACT is currency-neutral at the platform layer.

On-chain settlement operates exclusively over ERC-20 tokens. Platforms may accept any inbound payment rail, including fiat, ETH, stablecoins, or any other currency, and convert it into an ERC-20 before interacting with ACT.

The protocol never performs currency conversion and has no knowledge of off-chain payment rails.

---

## 9. Privacy Model

ACT never stores:

* Service descriptions or categories
* Locations or addresses
* Personal identities
* Communications or agreements
* Ratings or reputation
* Scheduling metadata

Only an opaque `serviceHash` is stored on-chain.

All identifying information remains off-chain under platform control.

The service handle token contains no descriptive metadata and has no transfer functionality.

---

## 10. Security Model

ACT intentionally minimizes attack surface:

* No admin roles
* No upgrade hooks
* No pause or emergency controls
* No arbitration branches
* No discretionary logic

Provider finalization is gated on `slotStart` to prevent immediate drain after acceptance.
Buyer finalization is unrestricted — the buyer may release funds at any time.
Anyone may trigger finalization after expiry — liveness is always guaranteed.

Security derives from:

* Ethereum consensus
* ERC-20 token mechanics
* Deterministic execution
* Bounded time-based release

---

## 11. Trust Model

Participants trust:

* The deployed bytecode
* Ethereum liveness and finality
* The ERC-20 token contracts used for settlement

They do **not** trust:

* Platforms
* Operators
* Arbitrators
* The protocol author

Once deployed, ACT does not require trust in any human actor.

---

## 12. The Non-Transferable Token as Infrastructure

ACT uses ERC-721 tokens as non-speculative infrastructure primitives.

The service handle is:

* A globally unique reference to a single accepted service
* An authorization anchor for off-chain booking data
* A deterministic proof of lifecycle state

It is not:

* A tradeable asset
* A speculative instrument
* A reputation signal
* A record of service quality

The token cannot be transferred. It cannot be approved. It cannot accumulate.
It is minted on acceptance and burned on finalization.

Its only purpose is to make the settlement lifecycle auditable and unambiguous.

---

## 13. Non-Standard Use Cases

ACT is optimized for discrete service sessions with defined time slots.

For complex or long-running engagements such as extended construction projects, ongoing consulting, or subscription services:

* Parties agree to scope and terms off-chain
* The provider creates a new offer for each phase or milestone
* The buyer accepts each offer independently
* Each escrow is settled atomically

This preserves determinism and auditability across multi-phase engagements without requiring the protocol to understand project structure.

The protocol remains unchanged. Complexity lives in the platform layer where it belongs.

---

## 14. Comparison to Centralized Platforms

| Dimension           | Centralized Platforms    | ACT Protocol     |
| ------------------- | ------------------------ | ---------------- |
| Fund custody        | Platform-controlled      | Trustless escrow |
| Fees                | Mutable, extractive      | Immutable 0.5%   |
| Governance          | Centralized              | None             |
| Dispute resolution  | Platform arbitration     | None             |
| Identity            | Mandatory                | Optional         |
| Service verification| Platform-dependent       | Out of scope     |
| Data extraction     | Yes                      | No               |
| Exit possibility    | Low                      | Always           |
| Liveness guarantee  | Platform uptime          | Ethereum         |

---

## 15. Finality Statement

ACT Protocol is **finished infrastructure**.

It will not be upgraded, governed, or extended.

The protocol does not evolve.
Ecosystems around it may.

---

## 16. Conclusion

ACT provides neutral settlement infrastructure for real-world services by removing discretion, custody, and governance from the settlement layer.

The protocol does not determine whether a service was performed correctly.
It does not arbitrate disputes between parties.
It does not verify identity, credentials, or safety.

These are platform responsibilities.

ACT's responsibility is narrower and more durable: it guarantees that funds always move, that timing is always deterministic, and that no human actor can freeze, redirect, or control settlement once a service is accepted.

It does not promise fairness, safety, or convenience.

It promises **determinism, neutrality, and exit**.

---

**ACT Protocol**
Neutral settlement, enforced by code.

---