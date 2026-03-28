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

```
LinuxCNC Motion
    ↓
CiA402 Semantic Layer
    ↓
Adapter (contract boundary)
    ↓
Binding (HAL wiring)
    ↓
Backend (simulated / EtherCAT)
```

---

## Framework Responsibility Model

```
Framework -> HAL + semantics + architecture
User      -> INI + machine configuration + hardware
```

Important:

- The framework provides HAL examples and semantic behavior
- The INI is user-specific and must be adapted to each machine

---

## Quick Start

See:

```
docs/quick_start.md
```

---

## Repository Structure

```
hal/
  core/
  topology/
  examples/
  adapters/

profiles/
  driver/
  reference/
  validated/

scripts/
  framework.sh
  diag.sh
  faultinj/

docs/
```

---

## INI Integration

The INI file is user-specific.

Minimum requirement:

```
[HAL]
HALFILE = <your_host_hal>
HALFILE = hal/examples/...
```

Reference examples:

- ini/examples/example_single_axis.ini
- ini/examples/runtime_validate_xy.ini
- ini/examples/runtime_validate_xyz.ini

---

## Hardware Note

The quick start uses a simulated backend.

Real hardware (EtherCAT) requires:

- Proper real-time kernel configuration
- Stable system latency
- Correct EtherCAT setup

---

## License

See LICENSE.

---

## Author

Marcos Duque Cesar
