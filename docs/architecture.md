# Architecture

This document describes the architecture of the `linuxcnc-cia402-layer` project.

The design separates machine policy, CiA402 protocol semantics, and hardware transport integration into independent layers. This separation allows CiA402 behavior to be validated in simulation and reused across different hardware backends.

The project does **not modify the LinuxCNC motion controller**. LinuxCNC remains the authority for trajectory planning and coordinated motion.

The CiA402 layer acts as a semantic bridge between LinuxCNC motion and CiA402 drives.

---

# Architectural Overview

```text
LinuxCNC motion
        |
        v
machine_safety_gate
        |
        v
CiA402 semantic layer
        |
        v
drive / transport adapter
        |
        v
CiA402 drive (Power Drive System)
```

The architecture is intentionally layered so that each part of the system has a single clear responsibility.

---

# Responsibility Split

The project is organized around a strict split of authority:

| Responsibility | Authority |
|---|---|
| trajectory / coordinated motion | LinuxCNC motion |
| machine policy | `machine_safety_gate` |
| PDS state semantics | `cia402_pds` |
| procedure supervision | `cia402_homing` |
| final 6040 ownership | `cia402_cw_compose` |
| hardware / transport mapping | adapter/backend |

This avoids a common ambiguity in CiA402 integrations where trajectory control, PDS control, and machine policy are mixed together.

---

# LinuxCNC Motion

LinuxCNC motion remains responsible for:

- trajectory planning
- interpolation
- kinematics
- joint coordination
- global motion synchronization

LinuxCNC therefore acts as the **Control Device** in the CiA402 architecture.

The drive acts as the **Power Drive System (PDS)**.

In the preferred CNC model, LinuxCNC generates the trajectory and the drive follows commanded targets.

For this reason the current project scope prioritizes:

```text
Cyclic Synchronous Position (CSP)
Homing Mode (HM)
```

CSP preserves LinuxCNC as the motion authority. The project does not use the drive as the primary trajectory generator.

---

# Machine Safety Gate

The `machine_safety_gate` component implements **machine policy gating**.

Its role is to decide whether higher-level machine conditions allow requests to propagate toward the CiA402 semantic layer.

Typical responsibilities include gating:

- enable permission
- motion permission
- homing permission
- fault reset permission

This layer is intentionally **generic** and **transport-independent**.

It can be reused with:

- EtherCAT drives
- Mesa hardware
- simulated drives
- future backends

Important notes:

- It does **not** implement CiA402 semantics.
- It does **not** write the final controlword.
- It does **not** replace certified functional safety.
- It does **not** replace E-stop circuits, STO, contactors, or safety relays.

Those mechanisms must always exist in hardware.

---

# CiA402 Semantic Layer

The CiA402 semantic layer translates between LinuxCNC machine intent and the CiA402 drive interface.

Main modules:

```text
cia402_pds
cia402_homing
cia402_cw_compose
```

Each module has a narrow and explicit role.

---

# PDS State Manager (`cia402_pds`)

The `cia402_pds` component interprets the CiA402 statusword (6041h) and manages the Power Drive System state machine.

Responsibilities include:

- decoding PDS states
- generating the base controlword (6040h)
- exposing `op_enabled`
- exposing fault-related state
- handling fault reset requests
- honoring machine-policy gating for enable and fault reset

The implementation uses mask-based decoding to tolerate vendor variation, including robust handling of the common Switch On Disabled exception.

Examples of masked decode paths include:

```text
sw & 0x006F
sw & 0x004F
```

The current decode is intended to classify valid DS402 states explicitly, including states that are often mishandled in simple implementations, such as:

- Quick Stop Active
- Fault Reaction Active

These states should not silently fall into a generic unknown-state path.

## Policy interaction

`cia402_pds` remains the semantic owner of the PDS, but it now accepts machine-policy gating inputs such as:

- `allow-enable`
- `allow-fault-reset`

Conceptually:

```text
effective_enable      = enable && allow_enable
effective_fault_reset = fault_reset && allow_fault_reset
```

This keeps machine policy outside the PDS logic while still letting policy decisions affect PDS progression deterministically.

---

# Homing Supervisor (`cia402_homing`)

The `cia402_homing` component supervises CiA402 homing mode.

Responsibilities include:

- requesting homing mode
- waiting for mode confirmation
- generating the homing start pulse
- monitoring completion
- aborting cleanly on invalid or faulted conditions

This module does **not** directly write the final controlword.

Instead, it produces procedure-specific control intent that is merged later by the controlword composition stage.

In the modular harness, homing permission is typically gated by both:

- `pds.op-enabled`
- machine policy (`allow-homing`)

So homing only proceeds when the drive state and machine policy both allow it.

---

# Controlword Composition (`cia402_cw_compose`)

To avoid ambiguity and race conditions, the architecture enforces a strict rule:

**only one component writes the final controlword (6040h).**

Conceptually:

```text
cw_final = cw_pds | procedure_bits
```

Where:

- `cw_pds` is produced by `cia402_pds`
- `procedure_bits` are produced by procedural supervisors such as `cia402_homing`

This prevents multiple HAL components from writing conflicting 6040 values.

---

# HAL Pipeline Determinism

All components run in the same LinuxCNC realtime thread.

Execution order is controlled through `addf`.

Conceptual order:

```text
machine_safety_gate
→ cia402_pds
→ homing gate logic
→ cia402_homing
→ cia402_cw_compose
→ drive / stub
```

Because LinuxCNC HAL executes functions sequentially in a thread, there is no true concurrency between these modules.

Determinism therefore depends on:

- one writer per signal/output role
- consistent `addf` ordering
- explicit signal ownership

---

# Quick Stop in This Architecture

Quick Stop (QS) is supported as a valid CiA402 concept, but it is **not** the preferred normal stop mechanism for LinuxCNC-controlled motion.

Architecturally, the intended policy is:

- normal stop behavior remains under LinuxCNC motion / planner authority
- Quick Stop is available as an exceptional or policy-driven path
- valid QS-related PDS states must be diagnosed explicitly

This keeps LinuxCNC as the motion authority while still allowing CiA402-specific stop behavior to exist when appropriate.

---

# Drive / Transport Adapter

The transport adapter connects the semantic layer to a real drive or fieldbus backend.

Typical responsibilities include mapping:

- HAL pins
- fieldbus objects
- PDO structures
- slave/channel-specific object offsets

Examples of transport layers include:

- EtherCAT (`lcec`)
- Mesa-based backends
- simulated drive stubs

The adapter is intentionally separated from CiA402 semantics so that the same semantic layer can be reused across backends.

## Multi-axis nodes

Some real EtherCAT slaves expose multiple CiA402 axes inside one node.

In that case the recommended model is:

```text
1 semantic instance = 1 logical axis/channel
1 adapter/backend = maps that axis to the proper node/channel objects
```

This keeps the semantic layer axis-centric and avoids coupling core logic to a specific bus topology.

---

# Simulated Drive (`cia402_stub`)

The repository includes a simulated drive component used for development and validation.

The stub emulates typical CiA402 drive behavior including:

- PDS state transitions
- homing completion
- operation mode reporting
- fault generation
- reset timing

This allows most semantic-layer behavior to be validated without physical hardware.

---

# Validation Harnesses

The repository contains multiple HAL harnesses representing different validation depths.

Typical progression:

```text
stub_test.hal
→ minimal homing-oriented validation

stub_test_modular.hal
→ semi-modular validation without full PDS ownership

stub_test_modular_pds.hal
→ full modular pipeline with machine policy + PDS + homing + cw compose + stub
```

The full modular harness is intended to represent the consolidated architecture most faithfully.

---

# Gantry / Coupler Scope

Gantry decouple/recouple and squaring logic belong to the **machine layer**, not the CiA402 semantic layer.

Typical machine-level procedures include:

```text
decouple
home independently
square gantry
recouple
```

These functions should remain outside the PDS and outside transport-specific logic.

---

# Practical Design Rule

The project follows one central practical rule:

**Do not mix machine policy, PDS semantics, procedural behavior, and transport mapping in the same module.**

This rule is the basis for:

- deterministic 6040 ownership
- reusable semantic logic
- transport independence
- simulation-first validation
- clearer future expansion toward real adapters and machine-level gantry logic
