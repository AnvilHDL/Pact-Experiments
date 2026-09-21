# Measurements

The collectors read the current PACT sources and RTL references. Each run writes
a timestamped result directory. Record repository and tool revisions with the
results; measurements from different configurations are not interchangeable.

## Synthesis

Install Yosys with `slang` and `yosys-abc`. Generate TileLink RTL before including
that case:

```sh
bash scripts/build_tilelink_rtl.sh
python3 scripts/collect_yosys_perf.py --case fifo --variant both
```

The [manifest](../scripts/yosys_perf_manifest.json) selects each case's PACT core
modules and RTL top. Driver processes are excluded by default. Core modules are
synthesized individually, with embedded FIFO and arbiter instances included
where selected by the manifest.

Results are under `synthesis_reports/yosys_perf_results/<run>/`. Generic-cell
counts are a structural size measure; they are not physical area, timing, or
power measurements.

For Liberty mapping and OpenSTA reports, use a generated result directory and
an explicit standard-cell library:

```sh
python3 scripts/collect_real_synth_perf.py --case fifo --variant both \
  --generated-dir synthesis_reports/yosys_perf_results/<run>/generated \
  --pdk-lib /path/to/standard-cells.lib
```

This flow requires Podman and its configured OpenSTA image. Results are under
`synthesis_reports/real_synth_perf_results/<run>/`. Record the Liberty file,
image version, clock period, and tool revisions with those measurements.

The AXI process models use one-entry FIFOs, while RTL wrapper parameters are
defined in `yosys_perf/perf_sv_wrappers.sv`. Check queue depth and payload widths
before interpreting size ratios. TileLink compares a reduced PACT communication
model against the full generated crossbar; their interfaces are not bit-for-bit
identical.

## State space

```sh
python3 scripts/collect_state_space.py --case fifo --timeout-seconds 180
```

This collector uses the full process test and the RTL formal harness. Its
`2**seq_cells` value is a structural estimate that excludes memory bits and
does not count reachable states. Results are under
`formal/comm_safety/results/state_space/<run>/`.

## Source size

```sh
python3 scripts/collect_code_size.py
```

This collector reports process-source lines, selected interface sizes, and
formal-harness assertion counts. It does not run a simulation or proof.
Use `--help` on each collector for case selection and output options.
