# PLC-Oriented Quick Start

## 1. Goal

Provide a practical entry point for PLC engineers.

---

## 2. Mental Model

- INI = configuration  
- HAL = logic  
- Framework = motion semantics  

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

## 4. Run Simulation

```bash
linuxcnc ini/examples/runtime_validate_xyz.ini
```

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

---

## 6. Simulated vs Real

Simulation uses:

- cia402_stub  

Real hardware requires:

- EtherCAT master  
- binding mapping  

---

## 7. Binding (Real Hardware)

Inspect:

```bash
halcmd show pin | grep lcec
```

Map:

- statusword  
- opmode  
- position  
- controlword  

---

## 8. Debug Strategy

If no motion:

- check enable  
- check mux  
- check controlword  
- check opmode  

---

## 9. Recommended Approach

- start with simulation  
- validate behavior  
- then integrate hardware  

---

## 10. Key Insight

LinuxCNC exposes everything.  
The framework organizes it.
