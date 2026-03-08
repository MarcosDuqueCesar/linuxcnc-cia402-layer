# Drive Integration

This document explains how the CiA402 semantic layer connects to real hardware
backends while keeping the core architecture vendor‑agnostic.

The project intentionally separates three concerns:

1. Machine policy
2. CiA402 semantic interpretation
3. Hardware / transport integration

Only the adapter layer interacts with real drives.

---

## Architectural Position

Complete control pipeline:

LinuxCNC motion
→ machine_safety_gate
→ cia402_pds
→ cia402_homing
→ cia402_cw_compose
→ drive_adapter
→ transport backend
→ drive

The semantic layer never talks directly to EtherCAT, Mesa, or any specific bus.

---

## Adapter Responsibility

The adapter translates between:

CiA402 semantic signals (HAL)
and
transport‑specific objects.

The adapter does **not implement CiA402 logic**.  
It only moves data between layers.

---

## Minimal Interface

The semantic layer only requires four CiA402 objects.

### Commands sent to drive

| Object | Description |
|------|-------------|
| 6040h | Controlword |
| 6060h | Mode of operation |

### Feedback from drive

| Object | Description |
|------|-------------|
| 6041h | Statusword |
| 6061h | Mode display |

These signals form the stable boundary between the semantic layer and hardware.

---

## HAL Signal Mapping

Semantic layer → adapter:

cw_final → controlword  
mode_cmd → mode_of_operation  

Adapter → semantic layer:

statusword → sw  
mode_display → mode_disp  

No additional semantics are introduced at this level.

---

## Example Backends

### EtherCAT (lcec)

Typical mapping:

controlword → lcec.<slave>.6040  
statusword  ← lcec.<slave>.6041  

mode_cmd    → lcec.<slave>.6060  
mode_disp   ← lcec.<slave>.6061  

---

### Mesa Hardware

The adapter maps the same objects to Mesa registers or firmware endpoints.

Example concept:

controlword → mesa register  
statusword  ← mesa register  

Mode objects follow the same pattern.

---

### Simulation / Stub

The simulation adapter connects directly to a HAL stub component.

controlword → stub  
statusword  ← stub  

This allows the semantic layer to be validated without real hardware.

---

## Multi‑Axis Nodes

Some EtherCAT drives expose multiple axes inside a single node.

Example:

Axis1 → 6040 / 6041  
Axis2 → 6840 / 6841  
Axis3 → 7040 / 7041  
Axis4 → 7840 / 7841  

The adapter handles these offsets.

The semantic layer still runs **one instance per axis**.

---

## Important Design Rule

The adapter **must not interpret drive state**.

Signals such as:

op_enabled  
fault  
state  

are produced exclusively by `cia402_pds`.

This keeps the semantic layer transport‑agnostic.

---

## Error Handling

Transport failures should be surfaced as:

backend_not_ready  
communication_loss  

These conditions are handled by `machine_safety_gate` rather than the adapter.

---

## Summary

The adapter layer ensures that:

• CiA402 semantics remain independent of hardware  
• the same logic works with EtherCAT, Mesa, or simulation  
• new backends can be added without modifying the semantic layer
