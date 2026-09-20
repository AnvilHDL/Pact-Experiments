# TileLink benchmark RTL

Run `bash scripts/build_tilelink_rtl.sh` from the repository root. This compiles
the local TileLink Scala sources with Scala 2.13.10 and Chisel 3.6.1, using Mill
0.11.13. A JDK 17 or newer is required (`JAVA_HOME`/`JAVA_CMD` may select it).
Mill and Maven dependencies are cached under `src/build/tilelink_tools`.

The generator uses two clients, two managers, 8-bit data, 16-bit addresses,
even/odd manager address ranges, and one local source ID per client. RTL is
written to `src/build/tilelink_rtl/TLCrossBar.v`, including its arbiter modules.

`TLArbiter.patch` is applied to a build copy of the upstream Scala sources.
It fixes the payload mux using the previous grant while `valid` uses the current
grant. The submodule is left untouched, and an incompatible upstream change
causes generation to fail rather than silently applying a different patch.
