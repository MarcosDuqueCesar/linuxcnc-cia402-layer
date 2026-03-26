OBSERVABILITY — DEBUG AND VALIDATION GUIDE

OBJECTIVE

Provide a minimal and deterministic way to inspect system state.

--------------------------------------------------
1. CORE SIGNALS (PER AXIS)

Motion:
- motion_wd_x.fault
- motion_wd_x.fault-latched
- motion_wd_x.tracking-error

Homing:
- home_wd_x.fault
- home_wd_x.fault-latched

State:
- ut_x.state
- ut_x.owner

Mode:
- mcsp_x.owner
- mux_x.sel-csp
- mux_x.sel-home

--------------------------------------------------
2. QUICK SNAPSHOT COMMAND

Example:

halcmd getp motion_wd_x.fault
halcmd getp motion_wd_x.fault-latched
halcmd getp home_wd_x.fault
halcmd getp ut_x.state

--------------------------------------------------
3. TESTING APPROACH

- force motion: motion-req-x
- force homing: home-req-x
- inject error via gain or stub

--------------------------------------------------
4. INTERPRETATION

- fault TRUE + latched TRUE → persistent failure
- owner mismatch → arbitration issue
- tracking error → motion deviation

--------------------------------------------------
5. RULE

Observability MUST NOT change system behavior.

It is read-only or external injection only.
