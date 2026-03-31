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

```text
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

LinuxCNC remains the motion authority.

---

## Framework Responsibility Model

```text
Framework -> HAL + semantics + architecture
User      -> INI + machine configuration + hardware
```

Important:

- The framework provides HAL examples and diagnostic visibility
- The user provides the machine-specific INI and real hardware integration

---

## Quick Start

See:

```text
docs/quick_start.md
```

---

## Repository Structure

```text
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
```

---

## Public Runtime Entry Point

Runnable simulation entry points:

```text
ini/examples/runtime_validate_xyz.ini
ini/examples/runtime_validate_xy.ini
hal/host/runtime_sim.hal
```

---

## Build Components

Before running the framework from a fresh clone, compile the realtime components:

```bash
find comp -name "*.comp" -exec halcompile --install {} \;
```

On some systems, installation may require:

```bash
find comp -name "*.comp" -exec sudo halcompile --install {} \;
```

---

## Observability

Main diagnostic tools:

```bash
scripts/diag.sh
scripts/obs/snapshot_axis.sh x
scripts/obs/obs_snapshot.sh all
```

These provide direct visibility into runtime behavior, including:

- Per-axis watchdog state (fault, stall, response-timeout, tracking-error)
- Motion supervision signals (pos-cmd vs pos-fb, motion-req, armed)
- Tracking error limits and thresholds
- Raw CiA402 signal paths (controlword/statusword between mux and adapter)

Notes:

- The diagnostics are passive (read-only) and do not modify system state
- Output is based on HAL pin inspection and reflects real runtime behavior
- Advanced internal signals (e.g. mux arbitration internals or full adapter state)
  are not fully expanded and are intentionally kept minimal for clarity

---

## INI Integration

The INI file is user-specific for real machines.

The public simulation INIs are runnable examples.

Minimum HAL integration pattern:

```ini
[HAL]
HALFILE = <your_host_hal>
HALFILE = hal/examples/...
```

Reference examples:

- `ini/examples/example_single_axis.ini`
- `ini/examples/runtime_validate_xy.ini`
- `ini/examples/runtime_validate_xyz.ini`

---

## Hardware Note

The quick start uses a simulated backend.

Real hardware (EtherCAT) requires:

- Proper real-time kernel configuration
- Stable low jitter
- Correct backend setup

---

## License

See `LICENSE`.

---

## Author

Marcos Duque Cesar
