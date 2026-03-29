# Quick Start (5 minutes)

This guide gets you from zero to a running system using the CiA402 framework with a simulated backend.

---

## Requirements

- LinuxCNC installed and working
- linuxcnc command available

---

## 1. Get the project

git clone https://github.com/MarcosDuqueCesar/linuxcnc-cia402-layer
cd linuxcnc-cia402-layer

---

## 2. Select a driver profile

scripts/framework.sh list-profiles
scripts/framework.sh set-profile profiles/driver/stepperonline_a6_ec.driver.yaml

---

## 3. Select topology

scripts/framework.sh set-topology multi_axis

---

## 4. Get suggestions

scripts/framework.sh suggest

---

## 5. Run simulation

linuxcnc ini/examples/runtime_validate_xyz.ini

---

## 6. Observe

scripts/diag.sh

Optional:

scripts/obs/snapshot_axis.sh x
scripts/obs/obs_snapshot.sh all

---

## Result

Framework running in simulation with:

- CiA402 pipeline active
- watchdogs visible
- adapter feedback active
