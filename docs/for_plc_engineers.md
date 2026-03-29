# For PLC Engineers: Understanding LinuxCNC + cia402-layer

## 1. Purpose

This document is intended for engineers with background in PLC systems, industrial motion control, and fieldbus systems.

It does NOT teach automation fundamentals.

Its purpose is to translate the PLC mental model → LinuxCNC + cia402-layer architecture.

---

## 2. The Core Paradigm Shift

### LinuxCNC is NOT a PLC

If you approach LinuxCNC expecting a TIA Portal / Studio 5000 style workflow, you will struggle.

### PLC Model

- Closed environment  
- Hardware + runtime tightly integrated  
- Motion and fieldbus abstracted  
- You write control logic  

### LinuxCNC + cia402-layer

- Open architecture  
- You assemble the system  
- Motion is separate from logic  
- Fieldbus is not integrated by default and must be configured externally  
- HAL is the execution layer  

### Key Insight

In PLCs, you program the machine  
In LinuxCNC, you build the system that runs the machine

---

## 3. Concept Mapping (PLC → LinuxCNC)

| PLC Concept | LinuxCNC + Framework |
|------------|---------------------|
| Hardware Configuration | INI |
| Task / Scan Cycle | servo-thread |
| Tags / Variables | HAL pins / signals |
| Function Blocks | HAL components (.comp) |
| Ladder / ST / FBD | HAL connections |
| Motion FB | cia402_motion_csp |
| Axis Object | semantic axis pipeline |
| Drive Interface | adapter |
| Fieldbus Mapping | binding |

---

## 4. Framework Architecture (PLC View)

Each axis is a modular pipeline:

- cia402_pds → drive state machine  
- cia402_motion_csp → motion  
- cia402_homing → homing logic  
- cia402_axis_semantic_mux → arbitration  
- cia402_cw_compose → controlword  

---

## 5. Role of the INI File

Defines:

- axes  
- limits  
- threads  
- HAL files  

Equivalent to PLC hardware configuration.

---

## 6. Role of HAL

HAL is where:

- signals are connected  
- logic runs  
- hardware is integrated  

---

## 7. Adapter and Binding

Adapter = contract  
Binding = real hardware wiring  

---

## 8. Driver Profiles

Define capabilities and constraints.  
They do NOT generate HAL automatically.

---

## 9. Integration Flow

0. Build realtime components (.comp)  
1. Select profile  
2. Bring up EtherCAT  
3. Inspect pins  
4. Create binding  
5. Run LinuxCNC  
6. Validate  

---

## 10. Common Mistakes

- Expecting wizard  
- Expecting plug-and-play  
- Ignoring controlword semantics  

---

## 11. Final Summary

INI = system definition  
HAL = machine logic  
Adapter = interface  
Binding = connection  
Profile = contract  

---

If you understand PLCs, you already understand most of the system.
