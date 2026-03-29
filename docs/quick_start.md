# Quick Start (5 minutes)

This guide gets you from zero to a running system using the CiA402 framework with a simulated backend.

---

## Requirements

- LinuxCNC installed and working
- `linuxcnc` command available in terminal
- `halcompile` available in terminal

---

## 1. Get the project

Clone:

```bash
git clone https://github.com/MarcosDuqueCesar/linuxcnc-cia402-layer
cd linuxcnc-cia402-layer
```

You can also download the repository as a ZIP and extract it anywhere.

---

## 2. Build the realtime components

Compile all `.comp` files before starting LinuxCNC:

```bash
find comp -name "*.comp" -exec halcompile --install {} \;
```

If your system requires elevated privileges for installation:

```bash
find comp -name "*.comp" -exec sudo halcompile --install {} \;
```

---

## 3. Select a driver profile

```bash
scripts/framework.sh list-profiles
scripts/framework.sh set-profile profiles/driver/stepperonline_a6_ec.driver.yaml
```

---

## 4. Select topology

```bash
scripts/framework.sh set-topology multi_axis
```

---

## 5. Get suggestions

```bash
scripts/framework.sh suggest
```

Expected result:

- profile metadata shown correctly
- suggested HAL example
- INI guidance

---

## 6. Run the public simulation example

```bash
linuxcnc ini/examples/runtime_validate_xyz.ini
```

This example uses:

- `hal/host/runtime_sim.hal`
- `hal/examples/multi_axis/example_multi_axis_generic_xyz.hal`

---

## 7. Observe system state

In another terminal:

```bash
scripts/diag.sh
```

Optional per-axis snapshots:

```bash
scripts/obs/snapshot_axis.sh x
scripts/obs/obs_snapshot.sh all
```

You should see:

- no watchdog faults
- valid adapter feedback
- visible CiA402 runtime state

---

## Done

The framework is now running in simulated mode.

---

## Notes

- This quick start is runnable out-of-the-box after component compilation
- The simulation setup is included in the repository
- Real hardware requires proper real-time and backend configuration
- The framework is designed to help separate framework issues from hardware/backend issues
