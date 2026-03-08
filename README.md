# linuxcnc-cia402-layer

Vendor-agnostic CiA402 (DS402) semantic layer for LinuxCNC.

The goal of this project is to separate **machine policy**, **CiA402 protocol semantics**, and **hardware transport/backends**.  
This allows validating behavior without hardware, keeping LinuxCNC as the motion authority, and reusing the same logic with different backends (EtherCAT, Mesa, simulation).

---

# Architectural Model

```
LinuxCNC motion
      ↓
machine_safety_gate
      ↓
CiA402 semantic layer
      ↓
drive adapter
      ↓
transport / backend
      ↓
drive (Power Drive System)
```

Responsibilities:

| Layer | Responsibility |
|------|----------------|
| LinuxCNC motion | trajectory generation and coordination |
| machine_safety_gate | machine policy (enable, homing, reset gating) |
| cia402_pds | CiA402 PDS state machine interpretation |
| cia402_homing | homing procedure supervision |
| cia402_cw_compose | deterministic controlword composition |
| cia402_drive_adapter | boundary between semantic layer and hardware |
| backend | EtherCAT / Mesa / simulation transport |
| drive | CiA402 compliant drive |

Key rule:

Only **one component writes the final controlword (6040)**.

```
cia402_pds       → base controlword
cia402_homing    → procedure bits
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
│   ├─ error_codes.md
│   └─ drive_integration.md
│
├─ LICENSE
└─ README.md
```

---

# Current Scope

The semantic layer currently focuses on CiA402 modes commonly used in CNC systems:

- CSP (Cyclic Synchronous Position)
- HM (Homing Mode)

LinuxCNC remains responsible for trajectory generation while the drive executes cyclic position commands.

---

# Current Status

The repository currently provides:

- modular CiA402 semantic layer
- deterministic controlword composition
- explicit PDS state decoding
- machine policy gating
- adapter interface separating hardware transport
- simulation stub for validation

A modular HAL harness is included to validate the full pipeline without requiring real hardware.

---

# Documentation

Detailed information is available in:

- `docs/architecture.md` — system architecture
- `docs/error_codes.md` — diagnostics and reason codes
- `docs/drive_integration.md` — backend / hardware integration

---

# License

MIT
