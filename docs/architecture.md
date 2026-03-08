# Architecture

This document describes the architecture of the `linuxcnc-cia402-layer` project.

The design separates machine policy, CiA402 protocol semantics, and hardware transport integration into independent layers. This separation allows the CiA402 behavior to be validated in simulation and reused across different hardware backends.

The project does **not modify the LinuxCNC motion controller**. LinuxCNC remains the authority for trajectory planning and coordinated motion.

The CiA402 layer acts as a semantic bridge between LinuxCNC motion and CiA402 drives.

---

# Architecture

This document describes the architecture of the `linuxcnc-cia402-layer` project.

The design separates machine policy, CiA402 protocol semantics, and hardware transport integration into independent layers. This separation allows the CiA402 behavior to be validated in simulation and reused across different hardware backends.

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

The architecture is intentionally layered to ensure that each part of the system has a clear responsibility.

---

# LinuxCNC Motion

LinuxCNC motion remains responsible for:

- trajectory planning
- interpolation
- kinematics
- joint coordination
- global motion synchronization

LinuxCNC therefore acts as the **Control Device** in the CiA402 architecture.

The CiA402 drive acts as the **Power Drive System (PDS)**.

In the preferred CNC model, LinuxCNC generates the motion trajectory and the drive follows the commanded targets.

---

# Machine Safety Gate

The `machine_safety_gate` component implements **machine policy gating**.

Its purpose is to control when motion-related actions are allowed to reach the drive layer.

Typical responsibilities include gating:

- enable requests
- motion permission
- homing permission
- fault reset requests

The safety gate is intentionally **generic and transport-independent**.

It can be used with:

- EtherCAT drives
- Mesa hardware
- simulated drives
- future transport layers

This layer represents **machine policy**, not protocol semantics.

Important notes:

- It does not implement the CiA402 protocol.
- It does not replace certified functional safety.
- It does not replace E-stop circuits, STO, contactors, or safety relays.

Those mechanisms must always exist in hardware.

---

# CiA402 Semantic Layer

The CiA402 semantic layer implements the behavior defined by the CiA402 specification.

Its purpose is to translate between LinuxCNC motion control logic and the CiA402 drive interface.

The semantic layer is composed of several modular HAL components:


cia402_pds
cia402_homing
cia402_cw_compose


Each module has a clearly defined responsibility.

---

# PDS State Manager (cia402_pds)

The `cia402_pds` component interprets the CiA402 statusword (6041h) and manages the Power Drive System state machine.

Responsibilities include:

- decoding PDS states
- generating the base controlword (6040h)
- tracking operation enabled status
- exposing fault state
- handling fault reset

The implementation uses mask-based decoding to tolerate variations between drive vendors.

Examples include masked checks such as:


sw & 0x006F
sw & 0x004F


This improves compatibility with drives that deviate slightly from the canonical CiA402 patterns.

---

# Homing Supervisor (cia402_homing)

The `cia402_homing` component supervises CiA402 homing mode.

Responsibilities include:

- requesting homing mode
- waiting for mode confirmation
- generating the homing start bit
- monitoring completion
- detecting faults during homing

This component **does not directly write the final controlword**.

Instead, it produces control signals that are merged later in the controlword composition stage.

---

# Controlword Composition (cia402_cw_compose)

To avoid ambiguity and race conditions, the architecture enforces a strict rule:

**only one component writes the final controlword (6040h).**

The composition stage merges the base controlword from the PDS manager with procedure-specific bits such as the homing start command.

Conceptually:


cw_final = cw_pds | start_homing


This ensures deterministic controlword generation and prevents multiple components from writing conflicting values.

---

# HAL Pipeline Determinism

All components execute in the same LinuxCNC realtime thread.

The execution order is defined using `addf`.

Conceptual execution order:


machine_safety_gate
→ cia402_pds
→ cia402_homing
→ cia402_cw_compose
→ drive / stub


Because LinuxCNC HAL threads execute sequentially, there is no real concurrency between these modules.

This guarantees deterministic evaluation of the CiA402 control pipeline.

---

# Drive / Transport Adapter

The transport adapter connects the semantic layer to a real drive.

Typical responsibilities include mapping:

- HAL pins
- fieldbus objects
- PDO structures

Examples of transport layers include:

- EtherCAT (lcec)
- Mesa hardware
- simulated drive stubs

The project intentionally separates transport from protocol semantics so that the same CiA402 logic can run across different hardware environments.

---

# Simulated Drive (cia402_stub)

The repository includes a simulated drive component used for development and validation.

The stub emulates typical CiA402 drive behavior including:

- PDS state transitions
- homing completion
- operation mode reporting
- fault generation
- reset timing

This allows most of the CiA402 logic to be validated without physical hardware.

---

# Operation Modes

The CiA402 specification defines multiple operation modes.

The project currently focuses on the modes most relevant to CNC systems:


Cyclic Synchronous Position (CSP)
Homing Mode (HM)


CSP is the preferred mode for CNC applications because the motion trajectory remains controlled by LinuxCNC.

Other CiA402 modes may be supported in the future.

---

# Gantry and Coupler Logic

Gantry coordination and axis coupling are considered **machine-level coordination**, not protocol semantics.

Typical gantry procedures include:


decouple
home independently
square gantry
recouple


These mechanisms belong to machine coordination layers above the CiA402 semantic layer.

They are therefore intentionally kept separate from the CiA402 protocol components.

---

# Design Goals

The architecture is designed to achieve the following goals:

- clear separation between machine policy and drive protocol
- deterministic controlword generation
- compatibility with different transport layers
- validation without physical hardware
- modular HAL components that are easy to test

This design allows the CiA402 semantic behavior to remain stable while the hardware backend evolves.
