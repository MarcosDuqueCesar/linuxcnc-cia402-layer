# User Guide

This guide explains how to use the linuxcnc-cia402-layer framework in practice.

It assumes you have already completed the Quick Start and have a working simulated setup.

---

## 1. Basic Workflow

The framework is used in three steps:

1. Select a driver profile
2. Select a topology
3. Use a HAL example with your INI

---

## 2. Selecting a Profile

List available profiles:

```
scripts/framework.sh list-profiles
```

Select one:

```
scripts/framework.sh set-profile profiles/driver/stepperonline_a6_ec.driver.yaml
```

A profile defines:

- Supported modes (CSP, homing)
- Required signals
- Scaling rules
- Backend contract

---

## 3. Selecting a Topology

```
scripts/framework.sh set-topology multi_axis
```

Common options:

- single_axis → one axis only
- multi_axis  → X/Y/Z setups
- gantry      → experimental

Topology defines how axes are organized and how arbitration works.

---

## 4. Using HAL Examples

HAL examples are located in:

```
hal/examples/
```

Examples:

- example_single_axis_*.hal
- example_multi_axis_generic_xy.hal
- example_multi_axis_generic_xyz.hal

These files already:

- Instantiate the semantic pipeline
- Connect mux, CSP, homing
- Connect adapter boundary

You typically DO NOT modify core logic.

---

## 5. INI Integration

The INI file is user-specific.

Minimum requirement:

```
[HAL]
HALFILE = <your_host_hal>
HALFILE = hal/examples/...
```

Important:

- First HALFILE → your machine / host HAL
- Second HALFILE → framework example

Order matters.

---

## 6. Running the System

```
linuxcnc <your_ini_file>
```

Then in another terminal:

```
scripts/diag.sh
```

---

## 7. Understanding diag.sh

The diagnostic tool shows:

- CiA402 state (PDS)
- controlword / statusword
- mux selection (HOME vs CSP)
- watchdog states

Expected behavior:

- No unexpected faults
- Stable state transitions
- mux selects correct owner
- controlword follows state machine

---

## 8. Motion Behavior

CSP (Cyclic Synchronous Position):

- Activated when motion is requested
- Requires:
  - motion-req = TRUE
  - allow-motion = TRUE
  - op-enabled = TRUE

Homing:

- Has priority over CSP
- Controlled via semantic path
- mux ensures arbitration (HOME > CSP)

---

## 9. Faults and Diagnostics

The framework exposes faults explicitly:

- tracking error
- stall
- response timeout

These are visible in:

```
motion_wd_* pins
```

The goal is to make it clear whether a problem comes from:

- framework logic
- configuration
- backend / hardware

---

## 10. Working Without Hardware

The framework can run fully simulated:

- backend is virtual
- motion pipeline is active
- watchdogs are functional

This allows validation before connecting real drives.

---

## 11. Moving to Real Hardware

When integrating hardware:

1. Install EtherCAT (lcec)
2. Load hardware configuration
3. Inspect pins:

```
halcmd show pin | grep lcec
```

4. Update binding in:

```
hal/adapters/
```

5. Validate again using:

```
scripts/diag.sh
```

Important:

- System must have good real-time performance
- High jitter can break motion and EtherCAT

---

## 12. What You Should NOT Do

- Do not modify core components
- Do not create multiple writers for controlword
- Do not bypass mux arbitration
- Do not mix semantic layers with backend logic

---

## 13. Typical Problems

If something does not work:

Check:

- HAL loaded correctly
- No missing pins
- Correct profile selected
- INI references correct HAL files

Then check:

```
scripts/diag.sh
```

---

## 14. Next Steps

- Explore different profiles
- Test fault injection scripts
- Integrate real hardware
- Read architecture documentation

---

## Summary

The framework provides:

- Semantic layer (CiA402)
- HAL pipeline
- Diagnostics

The user provides:

- INI
- machine configuration
- hardware integration

