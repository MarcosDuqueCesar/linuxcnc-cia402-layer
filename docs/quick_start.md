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

---

## 2. Build the realtime components

Compile all `.comp` files before starting LinuxCNC:

```bash
find comp -name "*.comp" -exec halcompile --install {} \;
```

If required:

```bash
find comp -name "*.comp" -exec sudo halcompile --install {} \;
```

---

## 3. Run simulation (minimal path)

Run directly:

```bash
linuxcnc ini/examples/runtime_validate_xyz.ini
```

This example is fully self-contained and uses:

- `hal/host/runtime_sim.hal`
- `hal/examples/multi_axis/example_multi_axis_generic_xyz.hal`

No hardware is required.

---

## 4. Observe runtime

In another terminal:

```bash
scripts/diag.sh
```

Optional:

```bash
scripts/obs/snapshot_axis.sh x
scripts/obs/obs_snapshot.sh all
```

You should see:

- no watchdog faults
- valid motion supervision signals
- CiA402 controlword/statusword activity

---

## Optional: Framework CLI exploration

These commands are **not required** to run the simulation above.

They are useful to explore profiles and topology configuration:

```bash
scripts/framework.sh list-profiles
scripts/framework.sh set-profile profiles/driver/stepperonline_a6_ec.driver.yaml
scripts/framework.sh set-topology multi_axis
scripts/framework.sh suggest
```

Note:

- These commands do not modify the example INI used above
- They are part of the framework configuration workflow, not the simulation entrypoint

---

## Done

The framework is now running in simulated mode.

---

## Notes

- The quick start is designed to work without hardware
- Simulation is the reference validation path
- Real hardware integration requires additional backend configuration
