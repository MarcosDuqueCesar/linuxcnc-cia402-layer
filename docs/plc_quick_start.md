# PLC-Oriented Quick Start

## 1. Goal

Provide a practical entry point for PLC engineers using the framework in simulation-first mode.

---

## 2. Mental Model

- INI = configuration (machine + runtime entrypoint)  
- HAL = logic (signal wiring + behavior)  
- Framework = motion semantics (CiA402 layer)  

---

## 3. Clone and Build

```bash
git clone https://github.com/MarcosDuqueCesar/linuxcnc-cia402-layer
cd linuxcnc-cia402-layer

find comp -name "*.comp" -exec halcompile --install {} \;
```

If needed:

```bash
find comp -name "*.comp" -exec sudo halcompile --install {} \;
```

---

## 4. Run Simulation (Reference Path)

```bash
linuxcnc ini/examples/runtime_validate_xyz.ini
```

Notes:

- Run from repository root  
- This configuration is fully self-contained  
- No hardware is required  

This uses:

- `hal/host/runtime_sim.hal`  
- `hal/examples/multi_axis/example_multi_axis_generic_xyz.hal`  

---

## 5. Observe System

```bash
scripts/diag.sh
```

Optional:

```bash
scripts/obs/snapshot_axis.sh x
scripts/obs/obs_snapshot.sh all
```

Focus on:

- watchdog state  
- motion request vs feedback  
- controlword / statusword paths  

---

## 6. Simulation vs Real Hardware

Simulation uses:

- virtual backend (`cia402_backend_adapter`)

Real hardware requires:

- explicit binding (HAL mapping)  
- backend configuration (e.g. EtherCAT / LCEC)  

Simulation is the reference validation path.

---

## 7. Binding (Real Hardware)

Only relevant when integrating real hardware.

Example inspection:

```bash
halcmd show pin | grep -E "lcec|cia402|adapter"
```

Typical mapping:

- statusword → semantic layer input  
- opmode display → semantic layer  
- position feedback → motion supervision  
- controlword → drive  

Note:

- Binding is NOT part of the simulation path  
- Adapter layer already defines the contract  

---

## 8. Debug Strategy

If no motion:

- check enable path (machine_safety_gate)  
- check mux arbitration (CSP vs HOMING)  
- check controlword path (cw-final → adapter)  
- check opmode  

Use:

```bash
scripts/diag.sh
```

as primary observability tool.

---

## 9. Recommended Approach

- start with simulation  
- validate behavior (watchdog, mux, controlword)  
- only then integrate hardware  

---

## 10. Key Insight

LinuxCNC exposes everything.  
The framework structures semantics and observability.
