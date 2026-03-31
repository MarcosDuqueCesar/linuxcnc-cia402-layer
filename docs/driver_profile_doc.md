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
- scaling rules (conceptual bridge)
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

Defines required signals between framework and backend.

Naming follows a consistent pattern:

adapter_{axis}.in-controlword  
adapter_{axis}.in-opmode  
adapter_{axis}.in-target-position  

adapter_{axis}.out-statusword  
adapter_{axis}.out-opmode-display  
adapter_{axis}.out-actual-position  

These signals form the integration boundary.

---

## Control Authority

Defines who is allowed to write critical signals.

Important rule:

- controlword must have a single writer

---

## Scaling

Defines how values are conceptually converted:

- raw counts → framework units
- feedback scaling
- command scaling

Important:

Scaling definitions represent a conceptual bridge.

The actual HAL implementation may include additional stages such as:

- filtering (e.g. apf)
- intermediate conversion
- fault injection paths
- watchdog-specific signals

Always verify the real signal path using HAL.

---

## How Profiles Are Used

Profiles are optional for initial usage.

Recommended workflow:

1. Run simulation example (INI + HAL)
2. Validate runtime behavior (diag.sh)
3. Then explore profiles and topology (optional)

Example commands:

scripts/framework.sh list-profiles  
scripts/framework.sh set-profile profiles/driver/<profile>.yaml  
scripts/framework.sh set-topology multi_axis  
scripts/framework.sh suggest  

Note:

These commands do not affect the example INI directly.

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

Profiles are validated by comparing their declared contract
with the actual HAL runtime.

This can be verified using:

halcmd show pin  
scripts/diag.sh  

---

## Important Rules

- no logic inside profiles
- no controlword manipulation
- no bypass of semantic layer
- no multiple writers

Profiles must remain declarative.

---

## Important Note

Profiles describe expected contract and semantics.

They do NOT guarantee that:

- component names are identical in HAL
- intermediate stages match exactly

Always validate the real runtime wiring.

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
