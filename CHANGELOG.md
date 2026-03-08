# CHANGELOG

All notable changes to this project will be documented in this file.

This project follows a pragmatic changelog style focused on architecture,
diagnostics, and integration milestones rather than strict semantic versioning.

---

# [Unreleased]

## Architecture

- Confirmed modular CiA402 semantic layer architecture separating:
  - machine policy
  - CiA402 semantic interpretation
  - backend/transport integration
- Reinforced rule that **only one module writes the final 6040 controlword**.

Controlword ownership pipeline:

```
cia402_pds        -> cw_pds
cia402_homing     -> procedure bits
cia402_cw_compose -> cw_final
```

---

## Diagnostics Improvements

### cia402_pds.comp

Refactored diagnostic reason codes.

Replaced ambiguous numeric values with explicit enums:

```
PDS_R_NOT_READY
PDS_R_SWITCH_ON_DISABLED
PDS_R_READY_TO_SWITCH_ON
PDS_R_SWITCHED_ON
PDS_R_OPERATION_ENABLED
PDS_R_FAULT_PRESENT
PDS_R_FAULT_RESET_REQUESTED
PDS_R_UNKNOWN_STATE
```

Benefits:

- clearer debug output
- easier documentation
- improved maintainability

The DS402 state decode logic remains unchanged, including:

- `st_6f = sw & 0x006F`
- `st_4f = sw & 0x004F`

which preserves the robust `Switch On Disabled` exception handling.

---

### cia402_homing.comp

Improved internal state and reason diagnostics.

State machine now clearly exposes:

```
H_S_IDLE
H_S_WAIT_OMD6
H_S_SEND_START
H_S_WAIT_DONE
H_S_DONE
H_S_ERROR
```

Reason codes now distinguish different failure paths:

```
H_R_IDLE
H_R_WAITING_MODE_DISPLAY
H_R_SENDING_START_PULSE
H_R_WAITING_DONE
H_R_DONE
H_R_ERROR_STATUS_MATCH
H_R_ERROR_EXEC_DROPPED
H_R_ERROR_INVALID_STATE
```

This improves troubleshooting of procedural homing failures.

---

### machine_safety_gate.comp

Improved diagnostic clarity with explicit reason codes.

Previous numeric values were replaced with:

```
MSG_R_OK
MSG_R_BLOCK_ESTOP
MSG_R_BLOCK_MACHINE_OFF
MSG_R_BLOCK_BACKEND_NOT_READY
```

The module remains intentionally simple and generic.

It continues to act only as a **machine policy gate** and not as a certified safety implementation.

---

## Documentation

### docs/error_codes.md

Rewritten to clearly separate three diagnostic layers:

1. Drive-level faults  
2. CiA402 semantic layer diagnostics  
3. Machine policy diagnostics  

This eliminates ambiguity between:

- drive alarms
- semantic-layer interpretation
- machine-level blocking conditions

---

## HAL Test Harness Cleanup

The HAL validation files were cleaned and aligned with current component names.

### hal/stub_test.hal

Minimal homing-only validation path:

```
cia402_homing -> cia402_stub
```

Used for simple procedural testing.

---

### hal/stub_test_modular.hal

Semi-modular validation path:

```
cia402_homing -> cia402_cw_compose -> cia402_stub
```

Uses a fixed base controlword.

Does **not** include the PDS manager.

---

### hal/stub_test_modular_pds.hal

Full modular validation harness:

```
cia402_pds
    ↓
cia402_homing
    ↓
cia402_cw_compose
    ↓
cia402_stub
```

Used to validate the complete semantic layer stack.

---

## Internal Development Workflow

Development workflow standardized for the current environment:

- Windows + Git Bash
- files generated locally and copied into the repository
- Git workflow:

```
git status
git add
git commit
git push
```

Large code blocks are delivered as downloadable files to avoid formatting issues.

---

## Future Work

Planned evolution areas:

- homing timeout supervision
- optional integration of `machine_safety_gate` into the main HAL validation harness
- real backend adapter implementation:
  - EtherCAT
  - Mesa
- machine-level logic:
  - gantry decouple
  - squaring
  - recouple

---

End of current changelog section.
