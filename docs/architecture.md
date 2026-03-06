# Architecture

This document describes the architecture of the `linuxcnc-cia402-layer` project.

The goal of the design is to separate machine policy, protocol semantics and
transport integration into independent layers.

---

# Layered Model

The intended architecture is:

LinuxCNC motion  
↓  
machine_safety_gate  
↓  
CiA402 semantic layer  
↓  
transport adapter  
↓  
drive / fieldbus

Each layer has a clearly defined responsibility.

---

# LinuxCNC Motion

LinuxCNC motion remains responsible for:

- trajectory planning
- kinematics
- joint coordination
- limits and machine safety

The CiA402 layer **does not replace motion**.

Instead, it translates machine intent into CiA402 protocol semantics.

---

# Machine Safety Gate (planned)

This layer represents **machine policy**.

Responsibilities include:

- machine enable
- estop chain
- drive readiness
- motion permission

This layer is intentionally protocol-independent and can be used with:

- EtherCAT
- Mesa hardware
- simulation setups

---

# CiA402 Semantic Layer

This repository implements the CiA402 semantic layer.

Modules currently implemented:

cia402_pds  
cia402_homing  
cia402_cw_compose  

Responsibilities:

- decode statusword (6041)
- manage CiA402 state machine
- generate controlword (6040)
- supervise homing procedure

---

# Controlword Ownership

One important design rule of this project is **explicit controlword ownership**.

Only one module generates the final controlword.

cw_final = cw_pds | start4

Where:

- `cw_pds` is produced by the PDS state manager
- `start4` is the homing start request

This avoids multiple writers to object **6040**.

---

# Deterministic Execution

All modules execute inside the LinuxCNC servo thread.

Example configuration:

servo-thread: 1 kHz

Execution order:

cia402_pds  
→ cia402_homing  
→ cia402_cw_compose  
→ transport adapter  

Because:

- all modules share the same thread
- execution order is explicit
- controlword ownership is unique

the architecture remains deterministic.

---

# Validation

The architecture is currently validated using a simulated drive.

cia402_stub

The stub implements:

- PDS state simulation
- homing completion signals
- operation mode display
- fault injection
- fault reset timing

This allows the semantic layer to be tested in LinuxCNC AXIS simulation
without requiring EtherCAT hardware.

---

# Future Work

Planned additions:

- machine safety gate module
- EtherCAT adapter examples
- Mesa hardware mapping
- additional CiA402 operation modes
