# Quick Start (5 minutes)

This guide gets you from zero to a running system using the CiA402 framework with a simulated backend.

---

## Requirements

- LinuxCNC installed and working
- `linuxcnc` command available in terminal

---

## 1. Get the project

Clone:

```
git clone https://github.com/MarcosDuqueCesar/linuxcnc-cia402-layer
cd linuxcnc-cia402-layer
```

Or download ZIP and extract.

---

## 2. Select a driver profile

```
scripts/framework.sh list-profiles
```

Example:

```
scripts/framework.sh set-profile profiles/driver/stepperonline_a6_ec.driver.yaml
```

---

## 3. Select topology

```
scripts/framework.sh set-topology multi_axis
```

---

## 4. Get suggestions

```
scripts/framework.sh suggest
```

---

## 5. Run with a ready INI

```
linuxcnc ini/examples/runtime_validate_xyz.ini
```

---

## 6. Observe system

In another terminal:

```
scripts/diag.sh
```

You should see:

- CiA402 states
- controlword / statusword
- mux behavior
- no faults

---

## Done

Framework is running in simulated mode.

---

## Notes

- This uses a simulated backend
- Real hardware requires proper real-time setup
- The framework helps diagnose whether issues come from logic or hardware
