# linuxcnc-cia402-layer

A modular CiA402 semantic layer for LinuxCNC, designed to decouple machine behavior, motion semantics, and hardware backends.

---

## Overview

This project implements a clean, layered CiA402 architecture for LinuxCNC using HAL real-time components.

The goal is to provide:

- A deterministic semantic layer (CiA402-compliant)
- A clear separation of responsibilities
- A backend-agnostic integration model (EtherCAT, etc.)
- A framework that can be validated without hardware
- A structure that allows third-party driver integration

---

## Key Feature

The framework is designed to make faults observable and diagnosable.

It helps distinguish between:

- Framework logic issues
- Configuration problems
- Hardware/backend faults

---

## Architecture

LinuxCNC Motion
↓
CiA402 Semantic Layer
↓
Adapter (contract boundary)
↓
Binding (HAL wiring)
↓
Backend (simulated / EtherCAT)

LinuxCNC remains the motion authority.

---

## Framework Responsibility Model

Framework -> HAL + semantics + architecture  
User      -> INI + machine configuration + hardware  

Important:

- The framework provides HAL examples and diagnostic visibility
- The user provides the machine-specific INI and real hardware integration

---

## Quick Start

See:

docs/quick_start.md

---

## Repository Structure

hal/
  core/
  topology/
  examples/
  adapters/
  host/

profiles/
  driver/
  reference/
  validated/

scripts/
  framework.sh
  diag.sh
  obs/

docs/

---

## Public Runtime Entry Point

Runnable simulation entry points:

ini/examples/runtime_validate_xyz.ini  
ini/examples/runtime_validate_xy.ini  
hal/host/runtime_sim.hal  

---

## Observability

Main diagnostic tools:

scripts/diag.sh  
scripts/obs/snapshot_axis.sh x  
scripts/obs/obs_snapshot.sh all  

These expose:

- CiA402 state
- watchdog status
- mux ownership
- adapter feedback
- per-axis runtime state

---

## INI Integration

The INI file is user-specific for real machines.

The public simulation INIs are runnable examples.

Minimum HAL integration pattern:

[HAL]
HALFILE = <your_host_hal>
HALFILE = hal/examples/...

---

## Hardware Note

The quick start uses a simulated backend.

Real hardware (EtherCAT) requires:

- Proper real-time kernel configuration
- Stable low jitter
- Correct backend setup

---

## License

See LICENSE.

---

## Author

Marcos Duque Cesar
