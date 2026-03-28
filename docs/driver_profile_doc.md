# Driver Profile

Driver profiles define how a CiA402 drive integrates with the framework.

They act as a declarative contract between:

- the framework (semantics + HAL)
- the backend (EtherCAT / hardware)
- the drive itself

Profiles are stored as YAML files under:

profiles/driver/

---

## What a Profile Defines

A driver profile describes:

- drive identity (vendor, model)
- supported CiA402 modes
- required signals
- scaling rules
- backend contract
- integration constraints

It does NOT contain:

- runtime logic
- HAL wiring
- procedural behavior

---

## Structure Overview

A typical profile contains:

- identity
- contract
- capabilities
- backend_contract
- statusword_contract
- control_authority
- scaling

---

## Identity

Defines the drive:

identity:
  name: stepperonline_a6_ec
  vendor: stepperonline
  model: A6-EC

Used by the CLI and documentation.

---

## Capabilities

Declares what the drive supports:

- CSP mode
- homing
- watchdogs
- fault reset

---

## Backend Contract

Defines required signals between framework and backend:

Inputs (to drive):

- controlword
- operation mode
- target position

Outputs (from drive):

- statusword
- operation mode display
- actual position

---

## Control Authority

Defines who is allowed to write critical signals.

Important rule:

- controlword must have a single writer

---

## Scaling

Defines how values are converted:

- raw counts → framework units
- feedback scaling
- command scaling

---

## How Profiles Are Used

Typical workflow:

1. Select a profile:

scripts/framework.sh set-profile profiles/driver/<profile>.yaml

2. Select topology:

scripts/framework.sh set-topology multi_axis

3. Use suggested HAL example:

scripts/framework.sh suggest

---

## Relationship with HAL

Profiles do NOT generate HAL automatically.

- HAL examples implement the pipeline
- profiles define the contract those HAL files must respect

---

## Relationship with Adapter

The adapter connects:

framework ↔ backend ↔ drive

Profiles define what signals must exist.

Adapters implement those signals.

---

## Validation

Profiles can be validated:

- in simulation (recommended first)
- with real hardware

---

## Important Rules

- no logic inside profiles
- no controlword manipulation
- no bypass of semantic layer
- no multiple writers

Profiles must remain declarative.

---

## Summary

Driver profiles define:

- what the drive is
- what it supports
- how it connects

They ensure:

- consistent integration
- reusable configuration
- separation between semantics and hardware
