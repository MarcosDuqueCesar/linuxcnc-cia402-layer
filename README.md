# linuxcnc-cia402-layer

A modular CiA402 semantic layer for LinuxCNC, designed to decouple machine behavior, motion semantics, and hardware backends.

---

## Overview

This project implements a clean, layered CiA402 architecture for LinuxCNC using HAL real-time components.

The goal is to provide:

* A deterministic semantic layer (CiA402-compliant)
* A clear separation of responsibilities
* A backend-agnostic integration model (EtherCAT, etc.)
* A framework that can be validated without hardware
* A structure that allows third-party driver integration

---

## Architecture

The system is divided into layers:

LinuxCNC Motion
↓
CiA402 Semantic Layer
↓
Adapter (contract boundary)
↓
Binding (HAL wiring)
↓
Backend (simulated / EtherCAT)

---

## Design Principles

* No modification to LinuxCNC motion core
* Single writer for controlword (6040)
* Explicit arbitration via mux (HOME > CSP)
* Strict separation between semantics and transport
* Backend independence
* Deterministic behavior under fault conditions

---

## Current Status

### Fully Validated (Simulated Backend)

* CiA402 semantic layer
* CSP motion pipeline
* Homing integration
* mux arbitration (HOME > CSP)
* Controlword composition
* Watchdog supervision (motion + homing)
* Observability (diag.sh)
* Topologies:

  * Single-axis
  * Multi-axis XY
  * Multi-axis XYZ

### Implemented (Not Yet Hardware-Validated)

* HAL binding layer (scaffold)
* Adapter contract (stable)
* Driver profiles (schema defined)
* EtherCAT-ready integration model

### Experimental

* Gantry topology (community validation required)

---

## Repository Structure

hal/
core/        → CiA402 semantic components
topology/    → axis configurations
examples/    → runnable HAL examples
adapters/    → binding scaffolds
legacy/      → archived configs

profiles/
→ driver profiles

scripts/
→ validation and diagnostics

docs/
→ detailed documentation

---

## Adapter Contract

adapter.in-controlword
adapter.in-opmode
adapter.in-target-position

adapter.out-statusword
adapter.out-opmode-display
adapter.out-actual-position

---

## Observability

Run:

scripts/diag.sh

Provides:

* CiA402 state decoding
* statusword / controlword inspection
* watchdog monitoring
* mux visibility
* fault analysis

---

## Running (Simulated)

linuxcnc opc_validation.ini

Then:

scripts/diag.sh

---

## Hardware Integration (Third-Party)

Typical workflow:

1. Install EtherCAT (lcec)
2. Load hardware configuration
3. Inspect HAL pins:

halcmd show pin | grep lcec

4. Update binding in:
   hal/adapters/

5. Connect backend to adapter

6. Validate with diag.sh

---

## Driver Profiles

Profiles define:

* CiA402 object mapping
* scaling
* behavior expectations

They are the source of truth for bindings.

---

## What This Project Is NOT

* Not a monolithic driver
* Not hardware-specific
* Not modifying LinuxCNC internals
* Not hiding CiA402 semantics

---

## Goals

* Provide a reference CiA402 architecture
* Enable clean multi-drive systems
* Allow community validation
* Reduce integration complexity

---

## License

See LICENSE.

---

## Author

Marcos Duque Cesar
