# User Guide

This guide explains how to use the linuxcnc-cia402-layer framework in practice.

It assumes you have already completed the Quick Start and have a working simulated setup.

---

## 1. Recommended Workflow

The framework should be approached in this order:

1. Run a simulation example (reference flow)
2. Observe runtime behavior using diagnostics
3. Then explore profiles and topology (optional)

---

## 2. Running the Reference System

Run:

```
linuxcnc ini/examples/runtime_validate_xyz.ini
```

Then in another terminal:

```
scripts/diag.sh
```

This is the canonical entry point and does not require hardware.

---

## 3. Understanding diag.sh

The diagnostic tool provides visibility into:

- watchdog state (fault, stall, response-timeout, tracking-error)
- motion supervision signals (pos-cmd vs pos-fb, motion-req, armed)
- controlword / statusword paths

Expected behavior:

- No unexpected faults
- Stable state transitions
- Controlword follows CiA402 state machine

---

## 4. Profiles (Optional)

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

Note:

- Profile selection is part of the framework CLI workflow
- It does not affect the example INI used in simulation

---

## 5. Topology (Optional)

```
scripts/framework.sh set-topology multi_axis
```

Common options:

- single_axis → one axis only
- multi_axis  → X/Y/Z setups
- gantry      → experimental

Topology defines axis organization and arbitration behavior.

---

## 6. Using HAL Examples

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
- Connect CSP, homing, arbitration
- Connect adapter boundary

You typically DO NOT modify core logic.

---

## 7. INI Integration

The INI file is user-specific.

Minimum pattern:

```
[HAL]
HALFILE = <your_host_hal>
HALFILE = hal/examples/...
```

Important:

- First HALFILE → your machine / host HAL
- Second HALFILE → framework example
- Order matters

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
- Arbitration is handled internally

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

The goal is to clearly identify whether issues come from:

- framework logic
- configuration
- backend / hardware

---

## 10. Simulation vs Real Hardware

Simulation uses:

- virtual backend (cia402_backend_adapter)

This allows full validation without hardware.

---

## 11. Moving to Real Hardware

When integrating hardware:

- configure backend (e.g. EtherCAT / LCEC)
- create or adapt HAL bindings
- map required signals (controlword, statusword, position, opmode)

Inspect pins:

```
halcmd show pin | grep -E "lcec|cia402|adapter"
```

Important:

- Binding is not part of the simulation path
- Adapter defines the signal contract
- Good real-time performance is required

---

## 12. What You Should NOT Do

- Do not modify core components
- Do not create multiple writers for controlword
- Do not bypass arbitration
- Do not mix semantics with backend logic

---

## 13. Typical Problems

If something does not work:

Check:

- HAL loaded correctly
- No missing pins
- Correct INI references

Then inspect:

```
scripts/diag.sh
```

---

## 14. Next Steps

- Explore different profiles
- Use fault injection scripts
- Integrate real hardware
- Review architecture documentation

---

## Summary

The framework provides:

- CiA402 semantic layer
- HAL pipeline
- observability

The user provides:

- INI
- machine configuration
- hardware integration
