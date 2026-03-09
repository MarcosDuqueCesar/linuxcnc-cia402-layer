# linuxcnc-cia402-layer

> Experimental project. Not production-ready and not safety certified.

Vendor‑agnostic **CiA402 (DS402) semantic layer for LinuxCNC**.

The project separates **machine policy**, **CiA402 protocol semantics**, and **hardware transport/backends**.  
This allows validating behavior without hardware while keeping **LinuxCNC as the motion authority**.

The same semantic layer can be reused with different backends such as:

- EtherCAT
- Mesa
- simulation harnesses
- future adapters

---

# Architectural Model

LinuxCNC motion  
↓  
machine_safety_gate  
↓  
cia402_pds  
↓  
cia402_homing  
↓  
cia402_cw_compose  
↓  
cia402_drive_adapter  
↓  
transport / backend  
↓  
drive (Power Drive System)

Key rule:

Only **one component writes the final controlword (6040h)**.

```
cia402_pds        → base controlword intent
cia402_homing     → procedural bits
cia402_cw_compose → final controlword
```

---

# Repository Structure

```
linuxcnc-cia402-layer
│
├─ comp/
│   ├─ cia402_pds.comp
│   ├─ cia402_homing.comp
│   ├─ cia402_cw_compose.comp
│   ├─ cia402_drive_adapter.comp
│   ├─ cia402_stub.comp
│   └─ machine_safety_gate.comp
│
├─ hal/
│   └─ stub_test_modular_pds.hal
│
├─ docs/
│   ├─ architecture.md
│   ├─ drive_integration.md
│   ├─ error_codes.md
│   ├─ pds_validation_matrix.md
│   └─ homing_validation_matrix.md
│
├─ LICENSE
└─ README.md
```

---

# Current Scope

The semantic layer currently focuses on CiA402 modes typically used in CNC systems:

- CSP (Cyclic Synchronous Position)
- HM (Homing Mode)

LinuxCNC remains responsible for trajectory generation while the drive executes cyclic position commands.

---

# Validation

The repository includes a **HAL simulation harness** using `cia402_stub`.

This allows validating:

- PDS state transitions
- homing procedures
- timeout conditions
- negative procedural scenarios

All validation can be performed **without real hardware**.

---

# Documentation

Detailed documentation is available in:

- `docs/architecture.md`
- `docs/drive_integration.md`
- `docs/error_codes.md`
- `docs/pds_validation_matrix.md`
- `docs/homing_validation_matrix.md`

---

# License

MIT
