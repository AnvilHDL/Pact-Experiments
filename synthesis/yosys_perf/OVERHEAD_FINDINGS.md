# Yosys Perf: Where the Anvil/SV Cell-Count Gap Comes From

This documents an investigation into why Anvil-generated cores synthesize to
more cells than their hand-written SV counterparts, using the flow in
`scripts/collect_yosys_perf.py` (see `pact.md` for how to run it). It covers
two distinct overhead sources found, three fixes shipped (one with zero
measured effect, root-caused why), one fix attempted and reverted, and a
recommendation for where to look next.

**Update**: the numbers below through "Recommendation" all use Yosys's
generic internal cells as a relative-size proxy with no real area/timing/
power meaning. A real sky130 + OpenSTA flow was subsequently set up (see
"Real synthesis + timing/power" near the end) - it confirms the proxy's
seq-cell/Source #3 story, but shows real area ratios are substantially
lower than the proxy suggested, and reveals a real POWER story the proxy
could not show at all (worse than area, especially for smaller designs).
Read that section for the current, most accurate picture; the sections
below remain as the paper trail for how the investigation got there.

## Current numbers (short phase, `--phase short --variant both`)

**Update**: `axi_demux_read/write` and `axi_mux_read/write` previously showed
as `TIMEOUT`/`PRECHECK_FAIL` below - that was a Yosys/`read_slang` tooling
artifact (whole-file semantic checking despite `--top`), not a real Anvil
codegen failure. It's fixed (per-module isolation before synthesis, in both
collection scripts) and all four cases now measure cleanly.

*(An AXI-only measurement that excluded the embedded FIFO/arbiter via a
manifest `sv_subtract` field was tried in this investigation and then
reverted at the user's request - the numbers below are the full composition,
FIFO/arbiter included on both the Anvil and SV side, matching how these
cases were always measured before that experiment.)*

| Case | Anvil total | SV total | Total ratio | Anvil seq | SV seq | Seq ratio | Comb ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| fifo | 284 | 107 | 2.65x | 37 | 26 | 1.42x | 3.05x |
| stream_fifo | 836 | 186 | 4.49x | 85 | 72 | 1.18x | 6.59x |
| spill_register | 150 | 34 | 4.41x | 35 | 18 | 1.94x | 7.19x |
| arbiter | 185 | 71 | 2.61x | 23 | 7 | 3.29x | 2.53x |
| axi_demux_read | 874 | 167 | 5.23x | 112 | 26 | 4.31x | 5.40x |
| axi_demux_write | 1540 | 275 | 5.60x | 204 | 53 | 3.85x | 6.02x |
| axi_mux_read | 937 | 208 | 4.50x | 115 | 33 | 3.48x | 4.70x |
| axi_mux_write | 2180 | 367 | 5.94x | 265 | 60 | 4.42x | 6.24x |

Big-phase cases (`ace`, `tilelink`) are already *smaller* than their SV
baselines (0.87x, 0.54x) - see `WIDTH_FINDINGS.md`. **But smaller cell counts
don't mean smaller power draw**: once tilelink's SV baseline was fixed to
actually synthesize in the real sky130 flow (see "Real synthesis + timing/
power" below), it turned out to have the worst real POWER ratio of any case
in this whole investigation (11.48x), despite having the best (sub-1x)
area/cell ratio.

**Read the seq/comb split carefully**: for `fifo`/`stream_fifo`/`spill_register`,
the seq ratio is much closer to parity than the comb ratio (e.g. stream_fifo
1.18x seq vs 6.59x comb) - most of the size gap for those three is
combinational (Source #2 below). `arbiter` and the AXI mux/demux cases are
the opposite: their seq ratios are now *worse* than or comparable to their
comb ratios, and that's flip-flop *type*, not flip-flop *count* - see the
sequential-cell section below.

## Sequential cells: flop type, not flop count, and why it's not free

Total flop *count* is close to parity everywhere in the table above except
`arbiter`/`axi_demux_read`. But the flop histograms show a different, real
difference the raw count hides - the SV baselines use almost entirely
**clock-enabled** flops, while Anvil's output is dominated by **plain**
flops:

| Case | Anvil `$_DFF_` (plain) | Anvil `$_DFFE_` (enabled) | SV `$_DFF_` (plain) | SV `$_DFFE_` (enabled) |
| --- | ---: | ---: | ---: | ---: |
| fifo | 26 | 11 | 0 | 26 |
| stream_fifo | 74 | 11 | 0 | 72 |
| spill_register | 11 | 24 | 0 | 18 |
| arbiter | 21 | 2 | 5 | 2 |

(`$_DFFE_*` IS counted as sequential in the main table's `Anvil seq`/`SV seq`
columns and in `collect_yosys_perf.py`'s own `count_sequential_cells` -
`"dff"` is a substring of `"dffe"`, so the plain/enabled split here is purely
a finer-grained view added on top of the same seq totals, not a different
metric: e.g. fifo's 26 plain + 11 enabled = 37, matching the main table's
`Anvil seq` value exactly, for every case above.)

A clock-enabled flop (`$_DFFE_*`) is a single standard cell - the "hold
unless told to update" behavior is built into the cell itself, gating the
clock or the D-input internally. A plain flop (`$_DFF_*`) has no such
built-in enable: to make it hold its value on a cycle where nothing should
change, something upstream has to feed it `enable ? new_value : old_value`
- i.e. an *extra combinational mux* whose job is purely to fake an enable
that the cell doesn't have natively. So "37 Anvil flops vs 26 SV flops" (fifo)
understates the real gap: it's closer to "11 real enabled flops + 26 plain
flops each needing their own external hold-mux" vs "26 flops that need
nothing extra." Those hold-muxes plausibly land inside the `$_MUX_`
combinational counts already discussed under Source #2 below, meaning the
plain-vs-enabled flop split isn't an independent overhead source - it's the
*same root cause* (many small, separately-conditioned register writes)
showing up as a second symptom, not a third one.

**Why the flop type differs**, concretely - the hand-written SV reference
writes every register through ONE `always_comb` block that computes a single
next-state value via sequential if/else-if, then clocks that one value
unconditionally (`common_cells/src/fifo_v3.sv:67-108`, `mem_n`/`status_cnt_n`
built once, `mem_q <= mem_n` at the end). Anvil's generated code instead has
**multiple, independently-triggered non-blocking assignments directly to the
same register**, each guarded by its own `if (EVENTS0[event_id])` in one
`always_ff`, e.g. `stream_fifo_0`'s single-bit `full_q` is written at two
separate, unrelated-looking sites:

```systemverilog
// event 17 actions
if (EVENTS0[17].event_current) begin
  full_q[0 +: 1] <= thread_0_wire_29;
end
...
// event 8 actions
if (EVENTS0[8].event_current) begin
  full_q[0 +: 1] <= thread_0_wire_60;
  ...
end
```

This is semantically correct (`EVENTS0[17]` and `EVENTS0[8]` are mutually
exclusive by construction - the event graph guarantees at most one event
fires per cycle), and Yosys's `opt`/`proc` passes CAN in principle prove that
and collapse it into one clean enable. But `EVENTS0[n]` are themselves deep,
multi-term combinational expressions (see the `assign EVENTS0[n].event_current
= (...)` chains under "Thread N event state" in the generated SV), not
simple named conditions - so this mutual-exclusivity proof is a much harder
ask of generic synthesis heuristics than it is for the SV reference's single
if/else-if chain, where exclusivity is syntactically obvious. When the proof
doesn't go through cleanly, synthesis falls back to a plain flop plus an
external merge-mux instead of recognizing one shared enable.

This is NOT the same issue as Source #3 below (which is about *whether two
DIFFERENT events' delay/syncstate registers could share one flop*). This is
about the *same* register being written from *multiple event-triggered
sites* instead of through one pre-merged next-state expression - a
"many-writers-one-register" shape, not a "one-register-per-writer" shape.

### Fixed (Source #1b) - and measured to have no effect, with a root-caused explanation why

This was implemented and verified: `lib/codegenStates.ml` now detects,
per thread, every register written from 2+ distinct events
(`collect_reg_assigns`/`multi_writer_reg_names`), and for exactly those
registers emits one `always_comb`-computed next-state signal (default to
holding `reg_q`, then one `if (event_current) reg_n[offset +: len] = value;`
per writer event, in the same order those writes already appear in
`codegen_actions` - so precedence matches today's Verilog
last-non-blocking-assign-wins semantics exactly even in the hypothetical
case of two guards somehow overlapping) plus one unconditional
`reg_q <= reg_n;`, mirroring `fifo_v3.sv`'s own `mem_n`/`mem_q` idiom.
Registers with only one writer are left completely untouched - nothing to
merge. Deliberately scoped to processes with `reset_by = None` (no reset
message partway through the same clocked block) since no current test case
uses `reset_by`, and folding a reset-message override into `reg_n` correctly
needs matching the exact precedence of today's separate reset branch -
narrower and safer to defer than to get subtly wrong.

**Verified safe**: hand-diffed generated SV for `fifo`/`stream_fifo`/
`spill_register`/`arbiter` against the pre-change baseline - every removed
non-blocking assign maps to exactly one added blocking assign with identical
wire names/conditions/order, nothing else in the files changed. Full
regression suite green: `run-tests.py` (25/34, same failures as every other
change in this document), and all cycle-equivalence scripts pass (including
`axi_demux_read`, whose diff is still the same pre-existing harness quirk
documented under Source #3, unaffected by this change).

**Verified to have zero effect on cell counts, flop-type split included** -
this is the important, honest result. Total cells, seq/comb split, and the
plain-vs-enabled flop counts are all identical before/after across every
short- and big-phase case (e.g. `stream_fifo`: still 74 plain / 11 enabled
flops, 440 `$_MUX_`, both before and after).

**Root cause of why it's flat**, found by comparing `yosys -p "... proc;
stat"` (right after Verilog process elaboration, before any optimization)
against the full `synth -flatten` recipe on the SAME (post-merge) generated
SV: Yosys's own `proc`/coarse-synthesis stage already infers a genuine
enable-carrying internal cell (`$aldff`/`$adffe`) from the ORIGINAL scattered
per-event non-blocking-assign RTL just as readily as from the new merged
`always_comb` form - both shapes coarse-synthesize to a similar mix of
`$adff`/`$adffe` at that stage. The actual plain-vs-enabled SPLIT is decided
later, during generic-cell techmap/`dfflegalize`/`abc` mapping, and that
stage's choice turned out to be largely independent of which RTL idiom it
was fed. So the hypothesis this fix was built on - "the scattered-if shape
makes the exclusivity proof too hard for Yosys, hence the plain flops" - was
wrong, or at least not the deciding factor: Yosys already had what it needed
from the old shape. The plain-vs-enabled choice more likely comes down to
`abc`'s internal cost model when mapping to GENERIC cells without a real
target library - there's no strong signal that an enabled flop is actually
cheaper than a plain flop + mux when neither has a real area number attached,
which is exactly the kind of question a genuine Liberty-based flow (real
per-cell area/timing, not proxy metrics) would resolve where this Yosys-only
proxy flow can't.

**Kept anyway.** Even though it didn't move the cell-count numbers, the fix
is independently correct and a strict improvement in code quality: it makes
the generated SV mirror the canonical, more conventional RTL idiom
(`fifo_v3.sv`'s own `mem_n`/`mem_q` shape) instead of diverging from it, and
it's possible a REAL target-library synthesis flow (see the note on
timing/power tooling above) would show a difference this Yosys-only,
generic-cell proxy flow doesn't capture - worth re-checking if/when that
tooling exists. It's flagged here as a second concrete, comparatively
low-risk change alongside Source #2 (same "representation, not
timing-exclusivity" risk profile as Source #2 - unlike Source #3, nothing
here required reasoning about loop/recursion boundaries, since it's about
how one register's writers within an already-correct event graph get merged
into RTL, not about whether two events are exclusive in the first place).

## Source #1 (fixed): dead `if (...) begin end` shells in codegen

`lib/codegenStates.ml`'s `codegen_actions` guarded whether to print an
event's state-transition block on `e.actions <> []`. Three action kinds
(`PutShared`, `ImmediateSend`, `ImmediateRecv`) are compile-time bookkeeping
markers that the action-printer prints nothing for - so an event whose only
actions were of these kinds still got an empty
`if (EVENTS0[n].event_current) begin end` shell in the generated SV. Fixed by
checking whether any action actually prints a line, not whether the list is
non-empty.

**Verified safe**: pure output-formatting change (doesn't touch the event
graph, merge/elimination passes, or session-type checking). `run-tests.py`
25/34 pass rate unchanged (byte-identical failure set via `git stash`
bisection); all cycle-equivalence scripts pass.

**Verified to have ~zero effect on cell counts**: confirmed identical
before/after across every case. Yosys's own `opt -purge` already collapses
these empty blocks before counting cells - the fix shrinks the generated
`.sv` file (e.g. fifo: 1803 -> 1683 lines) and makes it more readable, but
doesn't move the synthesis numbers above. Kept anyway since it's a real,
zero-risk cleanup; not a performance fix.

## Source #2 (root-caused, not yet fixed): flattened arrays force per-access mux trees

This is the one that actually explains the ratios above, especially the mux
counts in the cell histograms:

```text
stream_fifo anvil: 440 $_MUX_  (SV: 56)   -- 7.9x
spill_register anvil: 34 $_MUX_ (SV: 10)  -- 3.4x
axi_demux_read/fifo_0: 147 $_MUX_ (aggregate SV baseline: 167 cells TOTAL)
```

### Root cause

Anvil source declares FIFO/queue storage as a genuine array type:

```anvil
// src/compat/test_fifo.anvil, test_stream_fifo.anvil
reg data : T[8];
```

and Anvil's own AST has first-class array indexing for both reads
(`Index of expr_node * index`, `lib/lang.ml:502`) and writes (`Indexed of
lvalue * index`, `lib/lang.ml:534`). But `format_dtype`
(`lib/codegenFormat.ml:39-48`) has no case for `` `Array ``: every non-`Logic`,
non-`Opaque` register type is flattened to a single
`logic[total_flattened_size-1:0]` by computing its total bit size
(`TypedefMap.data_type_size`) and declaring one flat vector. An 8-deep,
8-bit-wide FIFO's `data` register becomes one `logic[63:0]`, not something
shaped like an indexed array.

Every indexed access then lowers to a *computed, variable-offset* bit-slice
against that flat vector, e.g. (from the generated `fifo_0`/`stream_fifo_0`
SV, `synthesis_reports/yosys_perf_results/generated/*/anvil.yosys.sv`):

```systemverilog
logic[63:0] data_q; // register data
...
data_q[thread_0_wire_22 +: 8] <= thread_0_wire_13;   // write at write_ptr*8
...
assign thread_0_wire_83 = thread_0_wire_73[thread_0_wire_82 +: 8]; // read at read_ptr*8
```

versus the hand-written SV reference (`common_cells/src/fifo_v3.sv:49,68-75`):

```systemverilog
dtype [FifoDepth-1:0] mem_n, mem_q;
...
data_o  = mem_q[read_pointer_q];
mem_n[write_pointer_q] = data_i;
```

The SV version is a genuine indexed array declaration with genuine indexed
array access - Yosys's `synth` recognizes this shape and produces a compact
decode. The Anvil version is semantically equivalent but shaped as "one wide
register plus a `+:` slice at a computed offset," which Yosys cannot
recognize as an indexed array; it instead synthesizes a full read-modify-write
mux tree (select which of the 8 possible 8-bit windows is being touched,
merge with the untouched rest) for every such access, and there's one for
each indexed read and each indexed write in the design. This is the direct
cause of the large `$_MUX_` counts above, and it scales with (depth x
accesses), which is why deeper/wider queues (`stream_fifo`, `spill_register`)
show worse ratios than the plain `arbiter` (no indexed array in its
datapath - its own overhead, a smaller 2.6x, comes from the delay/sync
register pattern in Source #3 below plus generic endpoint-synchronization
bookkeeping already noted in `WIDTH_FINDINGS.md`'s "Structural Findings").

### Not just composition - the AXI control logic has its OWN, larger ratio

`axi_demux_read`'s core-pattern set (`scripts/yosys_perf_manifest.json`)
includes `fifo_.*`, and its single `fifo_0` instance alone synthesizes to 456
cells - more than the *entire* SV baseline (167 cells). It would be easy to
conclude from that alone that the AXI mux/demux ratios are just a
multiplication of Source #2 by however many FIFO/arbiter instances the
composition instantiates. **That undersells it - measured directly, the
AXI-specific routing logic (excluding the embedded FIFO) has a WORSE ratio
than the aggregate.**

Isolating it by hand (not the default manifest measurement, which keeps
FIFO/arbiter included on both sides - see "Current numbers" above):
`axi_demux_read`'s Anvil side is `demux_ar_main` (157 cells) +
`demux_r_main` (261 cells) + `fifo_0` (456 cells) = 874 total. Subtracting
the FIFO, `demux_ar_main + demux_r_main` = **418 cells** is the AXI-only
control logic. On the SV side, `perf_axi_demux_read_sv` (167 cells) is a
*flattened* module - Yosys's `synth` recipe always inlines submodule
hierarchy for this design size regardless of the `-flatten` CLI flag, so
there's no direct per-submodule stat available - but it instantiates exactly
one `fifo_v3` at `DATA_WIDTH=2, DEPTH=8`, the SAME configuration as the
manifest's standalone `fifo` case (`perf_fifo_sv` = 107 cells), plus two
`spill_register` instances with `Bypass=1` (`SpillAr=1'b0`/`SpillR=1'b0` in
`synthesis/yosys_perf/perf_sv_wrappers.sv:295-296` - bypass mode, near-zero
cost). So `167 - 107` = **60 cells** is a fair estimate of the SV side's
AXI-only control logic (routing/select plus the two near-free bypassed spill
registers).

**AXI-only ratio: 418 / 60 = 6.97x** - worse than the full aggregate's 5.23x,
not better. The aggregate ratio was actually being pulled DOWN by the FIFO's
comparatively milder 2.65x ratio, not inflated by it.

Why: `demux_r_main`'s own cell histogram has 72 `$_MUX_` cells (`demux_ar_main`
has only 6), and its generated SV shows the exact same array-flattening
pattern as Source #2, just smaller-scale and on a wire instead of a register
- 8 separate variable-offset 1-bit slices into one flattened multi-bit signal
(`thread_0_wire_34[thread_0_wire_26 +: 1]` through `[thread_0_wire_33 +: 1]`,
generated `axi_demux_read/anvil.yosys.sv` lines 66-73/125-132), almost
certainly a per-master-index "is master N ready" bit-array lookup, flattened
and bit-sliced the same way FIFO/queue storage is. **So this isn't a third,
independent overhead source - it's Source #2 recurring wherever Anvil code
indexes into ANY array-shaped value (register or plain wire), not just FIFO
storage specifically.** Fixing Source #2 generally (not just for registers)
should improve `demux_r_main`'s ratio specifically, on top of whatever it
does for the embedded FIFO.

### Why this wasn't fixed in this pass

Making `format_dtype` emit an indexed SV array for `` `Array `` types is a
comparatively contained, local formatting change - but it's not the only
place that needs to agree: every indexed-read/indexed-write codegen site
that currently computes a bit-offset and slices (the `Indexed`/`Index`
lowering in `graphBuilder.ml`, plus whatever in `codegenStates.ml`/`codegen.ml`
consumes `subreg_range_interval` for reads and writes) would need to switch
to emitting a genuine `name[idx]`/`name[idx] <= ...` access instead of
`name[computed_offset +: width]`, consistently, everywhere a register or
wire of `` `Array `` type is read or written. That's real, mechanical
plumbing work across several files, not a one-line fix, and it's out of scope
for what this pass covered - it's flagged here as the next concrete target.

## Source #3 (attempted, reverted): per-transition delay registers aren't shared

Separate from Source #2: every `Seq(_, Cycles 1)` protocol delay step (and
similarly every blocking send/recv "syncstate" flop, and every offer/select
"selected"/"done" register pair) gets its own dedicated register, one per
event, even when two such registers are on provably mutually-exclusive
branch arms (`if`/`else`, `match` cases, `try send`/`try recv` success-vs-
failure) and could in principle share one flop. This is visible directly in
`spill_reg_0`'s generated SV: 6 separate 1-cycle delay flops
(`_thread_0_event_counter_{34,31,26,23,20,17}_1_q`) for a component with only
4 architectural states.

**This was attempted and reverted.** The approach: a new
`GraphAnalysis.events_branch_disjoint` check (walk each event's `.source`
chain to find its enclosing branch arm(s), share a register between two
events only if they're confined to different, mutually-exclusive arms of the
same branch) plus register-aliasing in `codegenStates.ml`. Three real
correctness bugs were found and fixed one at a time by hand-tracing generated
SV against the source `.anvil` file (group-membership wasn't checked
pairwise across an entire group, `Select`/`Branch` pass-through was wrong,
recursion/loop-iteration boundaries were being silently traversed as if they
were static nesting). After all three fixes, a **fourth**, more severe
regression surfaced on `test_fifo`'s cycle-equivalence test: the FIFO's `pop`
path stopped firing entirely (only `Pushed` events traced, zero `Popped`)
even though the change looked correct by the same hand-tracing method that
had caught the previous three bugs.

This was reverted rather than debugged further. The pattern across all four
bugs was the same: reasoning about "are these two events truly
mutually-exclusive" requires understanding exactly how the event-graph
builder represents loops/recursion (`` `Recurse ``, `is_general_recursive`,
how a `branch_info` record is or isn't shared across loop iterations) well
enough to rule out every case where two textually-similar branch arms are
actually *sequential, not parallel* - and each fix attempt surfaced a new
instance of that same class of gap rather than closing it. That's a real,
exploitable optimization (the FIFO alone has 6 delay registers where its
state graph suggests ~2-3 would suffice), but doing it safely needs either
(a) much deeper study of the recursion/loop-body construction code
(`graphBuilder.ml`'s handling of `rec`/`loop`, `GraphOpt`'s existing
merge-pass machinery which already reasons about some of this for a
different purpose) than was done here, or (b) validation beyond hand-tracing
generated SV against source - e.g. an automated differential check across
many `.anvil` inputs with loops, not just the specific cycle-equivalence
scripts that happened to catch this one.

The revert is clean and verified: `git diff --stat` on the anvil repo shows
only the Source #1 fix remains in `lib/codegenStates.ml` (+11/-2 lines);
`lib/graphAnalysis.ml`/`.mli` have no diff. Full regression suite green after
revert: `run-tests.py` (25/34, same pre-existing failures), and all
cycle-equivalence scripts (`run_common_cells_cycle_equiv.sh`,
`run_axi_demux_write_cycle_equiv.sh`, `run_axi_mux_read_cycle_equiv.sh`,
`run_axi_mux_write_cycle_equiv.sh`, `run_ace_cycle_equiv.sh`,
`run_tilelink_cycle_equiv.sh`) pass.

### Source #3 is the dominant seq-cell overhead, confirmed in the AXI control logic too

Repeating the "isolate the AXI-only logic, excluding the embedded FIFO"
measurement from "Not just composition" above, but for SEQUENTIAL cells
specifically: `demux_ar_main` (26 seq) + `demux_r_main` (28 seq) = 54 seq
cells, versus `perf_axi_demux_read_sv`'s 26 seq cells total - **all 26 of
which belong to its embedded `fifo_v3`** (`perf_fifo_sv` standalone also
reports 26 seq cells; the two numbers match exactly). So the SV routing/
select logic itself needs **zero registers of its own** - `rentry`/`rset` in
the Anvil version are the only genuinely-needed protocol state the SV
reference doesn't have as separate registers (3 bits combined; the SV side
folds equivalent tracking into combinational always_comb logic instead).

**Correction, verified by direct measurement**: `demux_ar_main`/`demux_r_main`
both declare `reg cyc : logic[8]` (an 8-bit-per-module debug/bookkeeping
cycle counter, incremented every cycle purely to number `dprint` trace
lines for the cycle-equivalence testbenches, present in nearly every
`.anvil` file in this repo). It would be natural to assume this inflates the
54-bit seq count above - it does NOT. Commenting out `cyc` and its `dprint`
reads entirely in `src/compat/test_demux_read.anvil` and re-measuring gives
the exact same 26/28 seq cells, unchanged. Confirmed via direct inspection
that `cyc_q` is genuinely absent from the sanitized SV Yosys synthesizes
even BEFORE this edit: Yosys's own dead-code elimination already recognizes
that `cyc`'s only reader (`$display`, non-synthesizable) contributes nothing
to synthesizable logic, and removes the now-fanout-free register during its
own `opt` passes - independent of, and prior to, any source-level edit. So
**all 54 seq bits were already genuine event-machinery, not debug-inflated**
- reading the register declarations directly
(`generated/axi_demux_read/anvil.sv`), every one of them is Source #3's
pattern: a dedicated per-event delay-counter or syncstate flop
(`_thread_0_event_counter_*_1_q`, `_thread_0_event_syncstate_*_q`), one for
essentially every blocking send/recv/delay step in the protocol, none shared
across mutually-exclusive branch arms - plus one 2-bit send-data-selector
register per module (the same "value from N possible sources" merge pattern
described in `codegenStates.ml`'s existing `send_data_selectors` mechanism).
Not Source #2 (array flattening is a comb/mux story), not a new mechanism -
the same register-per-transition duplication already found and root-caused
in `spill_reg_0`/`fifo_0`, recurring in the AXI demux's own handshake logic.

**Update**: the `cyc` edit was subsequently applied to every manifest core
process that declared it (`demux_ar_main`/`demux_r_main`,
`demux_aw_main`/`demux_w_main`, `mux_ar_main`, `mux_w_main`/`mux_aw_main`,
`ace_main` - `mux_r_main`/`demux_b_main`/`mux_b_main`/`tilelink_arb`/
`crossbar_A`/`crossbar_D` never declared it in the first place). Re-measuring
the full short+big phase confirmed the same result everywhere: seq-cell
counts are byte-identical to before the edit in every case. `ace`'s total
dropped slightly (1228 -> 1203 cells) from now-fully-eliminated residual comb
wiring, but its seq count stayed exactly 179 in both measurements - the
pattern holds without exception.

At the time this comparison was made, `axi_demux_write`/`axi_mux_write`
still showed as failing (`TIMEOUT`/`PRECHECK_FAIL`); that was believed to be
a pre-existing, unrelated session-type issue in the excluded driver process.
It later turned out to be a `read_slang`/Yosys tooling artifact instead (see
the "Update" note under "Current numbers" above) - once fixed, both cases
measure cleanly and show the same Source #3 pattern (204 and 265 seq cells
respectively, see the numbers table).

**Reverted.** Given the confirmed zero effect, the edit was reverted via
`git stash push -- <the 5 files>` (kept as a labeled, recoverable stash
entry rather than dropped) so the working tree carries no diff for this
investigation. `test_fifo.anvil`/`test_spill_reg.anvil`/`test_arbiter.anvil`
already had `cyc` commented out in their core processes from before this
investigation started (pre-existing, unrelated to this session) - those were
not touched by the stash and remain as they were.

**This makes Source #3 the dominant, and so far only, driver of sequential
overhead found in every case examined** (fifo, stream_fifo, spill_register,
arbiter, and now the AXI demux control logic specifically, independent of
the embedded FIFO). Source #2 (array flattening) is a real, separate,
already-partially-addressed-in-analysis overhead source, but it is
predominantly a COMBINATIONAL/mux story, not a sequential one - see the
seq-vs-comb ratio split in the numbers table at the top (seq ratios are
consistently closer to parity than comb ratios for the FIFO-shaped cases).
If sequential cells specifically are the priority, Source #3 is where the
real overhead is, not Source #2.

## Recommendation

**If sequential cells specifically are the priority: Source #3 is where the
overhead is, not Source #2.** Every case examined (fifo, stream_fifo,
spill_register, arbiter, and the AXI demux control logic in isolation) shows
the same shape: a dedicated delay-counter or syncstate flop per protocol
transition step, never shared even across provably mutually-exclusive branch
arms, versus zero or near-zero registers on the SV side for the equivalent
control logic (see "Source #3 is the dominant seq-cell overhead" above -
`axi_demux_read`'s own routing logic alone is 54 real seq bits (confirmed
NOT inflated by debug instrumentation - see the correction above), against
the SV reference's 0). Source #2 (array
flattening) is real but is predominantly a COMBINATIONAL/mux story - the
seq ratios for the FIFO-shaped cases are consistently much closer to parity
than the comb ratios (see the numbers table at the top). Fixing Source #2
would not meaningfully move the sequential-cell numbers.

The risk/effort tradeoff hasn't changed since the attempt-and-revert
documented above: Source #3 needs a sound answer to "are these two events
truly mutually exclusive, including across loop/recursion boundaries," which
is exactly where four found-and-fixed-in-sequence bugs came from before a
regression finally surfaced that wasn't safely fixable in this pass. Two
honest options, not a recommendation to pick one:

1. **Re-attempt Source #3 with more groundwork first** - specifically,
   understand how `GraphOpt`'s existing merge passes (`lib/graphOpt.ml`,
   `event_is_empty`/`merge_pass_*`) already reason about which events can be
   merged away, including across recursion - they solve an adjacent version
   of the same underlying question and may already contain (or need to grow)
   the loop-boundary logic a correct register-sharing check would need. This
   is real work, not a quick fix, given the track record above.
2. **Hold on Source #3** until that groundwork exists, and treat Source #2
   (see below) as the lower-risk, still-real improvement available now -
   understanding that it targets comb/mux cells, not the seq overhead that's
   the current priority.

Source #2 (flattened arrays) remains the lower-risk target if comb/mux
overhead becomes the priority again, and is now higher-confidence given
Source #1b's result:

- It's a **representation** choice (how does codegen emit an `` `Array ``
  register/access), not a **timing/exclusivity** property - there's no
  hidden "is this actually always true across loop iterations" question the
  way there is for Source #3. Correctness is comparatively easy to check:
  does the same `.anvil` file simulate identically (cycle-equivalence tests
  already exist for exactly this) before and after switching from
  `[offset +: width]` slicing to `[idx]` indexing.
- It's already estimated to be the dominant cost: `fifo_0` alone is 456
  cells in `axi_demux_read`/`axi_mux_read`, versus those cases' entire SV
  baselines (167/208 cells).
- It's bigger than the FIFO-only estimate above suggests: isolating
  `axi_demux_read`'s AXI-only control logic (`demux_ar_main` +
  `demux_r_main`, excluding the embedded `fifo_0`) gives a 6.97x ratio,
  worse than the 5.23x aggregate - see "Not just composition" above. That's
  because Source #2 isn't only a register-array problem: `demux_r_main`
  shows the identical `[offset +: width]` flattened-slice pattern on a plain
  WIRE (a per-master "is ready" bit-array lookup), not a register. Fixing
  Source #2 generally - for any array-shaped value, not just registers -
  should improve every case above, `demux_r_main`'s own ratio included, more
  than a FIFO-only fix would.
- Unlike Source #1b, this changes RTL that Yosys's array/memory inference
  actually pattern-matches on (`memory_collect` et al. look for real indexed
  array declarations/accesses) - so there's a plausible mechanism for it to
  actually move the numbers, rather than a source-shape change Yosys already
  normalizes away internally regardless (which is what happened with #1b).

**A caution from Source #1b for future perf work in this repo**: a fix can
be provably correct, cleanly verified against the full regression suite, and
still measure as a complete no-op on the metric that matters, because this
flow's Yosys-only, generic-cell, proxy-metric synthesis doesn't necessarily
reward the RTL shape you'd expect it to. Measure before writing up a
prediction as a finding - Source #1b's writeup originally stated the
scattered-if shape as the likely cause of the plain-vs-enabled flop split
before the fix was built and measured; that turned out to be wrong (or at
least not the deciding factor), and only surfaced by actually comparing
Yosys's own intermediate synthesis stages. This is also part of why real
timing/power tooling (a genuine target cell library, not generic gates) was
worth setting up before drawing more conclusions from cell-count proxies
alone - done below.

## Real synthesis + timing/power (sky130 + OpenSTA), replacing the proxy-metric caveat above

Everything above this point used Yosys's generic internal cells
(`$_DFF_*`, `$_MUX_*`, ...) as a relative-size proxy - useful for finding
*where* overhead comes from, but with no real area/timing/power meaning, and
(per the Source #1b caution above) not always a reliable predictor of what a
real cell-mapping decision will do. This section replaces that proxy with a
real flow: Yosys synthesis targeting an actual standard-cell Liberty file
(sky130), followed by real static timing analysis and Liberty-based power
via OpenSTA.

### Setup

- PDK: sky130 via [volare](https://github.com/efabless/volare) (the PDK
  version manager used by the OpenLane/OpenROAD ecosystem) -
  `pip install --user volare && volare enable --pdk sky130
  c6d73a35f524070e85faff4a6a9eef49553ebc2b`. Target library:
  `sky130_fd_sc_hd` (high-density digital cells), `tt_025C_1v80` corner
  (typical-typical, room temperature, nominal voltage - the conventional
  default).
- STA: [OpenSTA](https://github.com/parallaxsw/OpenSTA) via the official
  `openroad/opensta` container image, run with **podman** (not docker, per
  project preference) - `podman pull docker.io/openroad/opensta:latest`.
- Flow (implemented in `scripts/collect_real_synth_perf.py`, layered on top
  of `collect_yosys_perf.py`'s already-generated/sanitized SV rather than
  re-deriving codegen): `synth -flatten` (same as the proxy flow) followed
  by `dfflibmap -liberty <lib>` + `abc -liberty <lib>` to actually map onto
  real sky130 cells instead of generic ones, then a fixed 100 MHz
  (10 ns period) clock SDC fed to OpenSTA for `report_worst_slack`,
  `report_tns`, and `report_power`.
- This is a **synthesis-only** flow (no place-and-route), matching the
  scope agreed earlier - real cells and real Liberty timing/power numbers,
  but no real wire parasitics. Good enough to answer "does the proxy
  metric's story hold up against real cells," not publication-grade
  silicon numbers.
- One correctness fix made while building this: naively reusing the proxy
  script's `("dff", "adff", "sdff", "dlatch", "latch")` substring matcher to
  classify sky130 cells as sequential silently produced 0 for every case -
  sky130 flip-flops are named `sky130_fd_sc_hd__df*` (`dfrtp`, `dfstp`,
  `dfxtp`, ...), which contains none of those substrings. Fixed by parsing
  Yosys's own `dfflibmap` mapping report (`"mapped N $_DFF_* cells to
  <realname> cells"`) to get the authoritative real-cell-name set directly,
  instead of guessing at a target library's naming convention.

### Results (short phase)

| Case | Anvil area (um2) | SV area (um2) | Area ratio | Anvil power (uW) | SV power (uW) | Power ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| fifo | 1685.4 | 1272.5 | 1.32x | 466.0 | 259.0 | 1.80x |
| stream_fifo | 3752.3 | 3213.1 | 1.17x | 990.0 | 411.0 | 2.41x |
| spill_register | 1582.8 | 758.2 | 2.09x | 460.0 | 113.0 | 4.07x |
| arbiter | 1074.8 | 419.2 | 2.56x | 284.0 | 44.2 | 6.43x |
| axi_demux_read | 5001.0 | 1569.0 | 3.19x | 1042.0 | 462.0 | 2.26x |
| axi_demux_write | 8899.0 | 2699.0 | 3.30x | 2036.0 | 834.0 | 2.44x |
| axi_mux_read | 5311.0 | 1858.0 | 2.86x | 1282.0 | 557.0 | 2.30x |
| axi_mux_write | 12260.0 | 3339.0 | 3.67x | 2622.0 | 1050.0 | 2.50x |
| tilelink | 2099.5 | 2299.7 | 0.91x | 349.0 | 30.4 | **11.48x** |

`tilelink`'s SV baseline (raw generated `TLCrossBar`) previously failed to
synthesize in this real-cell flow (`read_slang` reported a genuine forward-
reference bug in firtool/Chisel's own SV emission - two `requestDOI_*_0`
wires referencing `slaveLinksRemapped_*_d_bits_source` about 230 lines
before that wire's own declaration in `tilelink/debug_output/TLCrossBar.sv`;
fixed by moving the two wire declarations after their dependency, a 2-line
edit to the generated artifact, unrelated to anything else in this
investigation). Once fixed, tilelink shows the widest power/area divergence
of any case measured: Anvil is smaller in both cells (0.68x) and area
(0.91x) than the raw crossbar, but draws **11.48x more real power** - by far
the worst power ratio found anywhere in this doc, worse even than
`arbiter`'s previously-worst 6.43x. This is consistent with the Source #3
story (per-transition event-machinery that's always active/switching)
compounding harder here: `tilelink_arb`/`crossbar_A`/`crossbar_D` are a
smaller area footprint than the raw crossbar, but proportionally their
switching activity is far higher, which the cell-count/area proxies could
not show at all.

(`fifo`/`stream_fifo`/`spill_register`/`arbiter` seq-cell counts, re-derived
from the real sky130 mapping, land within 1 of the earlier generic-cell
proxy's seq_cells column in every case - e.g. fifo: 37 real vs 37 proxy,
arbiter: 23 vs 23 - confirming the proxy's seq-cell story was sound even
though its cell-count-as-area-proxy assumption, below, was not.)

### What changes versus the proxy-metric story, and what doesn't

**Real area ratios are substantially LOWER than the generic-cell proxy's
total-cell ratios** - fifo: 1.32x real vs 2.65x proxy; stream_fifo: 1.17x
real vs 4.49x proxy; even `axi_demux_read`'s aggregate: 3.20x real vs 5.23x
proxy. This is the clearest evidence yet for the Source #1b caution above:
counting generic Yosys cells 1:1 as an area proxy is unsound, because real
standard cells of different types have very different physical sizes (a
sky130 `dfrtp` flip-flop is roughly 25 um2; many of the small combinational
gates Anvil's overhead consists of are a fraction of that) - the proxy
metric was systematically overstating how much worse Anvil's area actually
is, sometimes by 2x or more. **Source #2 (array flattening)'s underlying
mechanism - real extra combinational cells from flattened-slice muxing - is
still real and still visible in the real-cell area numbers, just not nearly
as dramatically as raw generic-cell counts suggested.**

**Real POWER ratios are consistently WORSE than area ratios, and get worse
as designs get simpler** - arbiter is the starkest case: only 2.56x more
area, but 6.43x more power. This is a genuinely new finding the proxy metric
could not show at all (it had zero power information - `WIDTH_FINDINGS.md`
and every summary table above explicitly flagged "true power is unavailable
in this Yosys-only flow"). The likely mechanism: Source #3's per-transition
event-machinery flops and their driving logic are active (switching) far
more of the time, proportionally, in a small design like `arbiter` than the
genuinely idle-most-cycles bulk of a wider datapath like `stream_fifo` - so
the SAME absolute amount of "extra always-on bookkeeping" costs a much
higher fraction of total power in a small design than a large one. This is
exactly the kind of result only a real Liberty-based flow can show, and it
sharpens rather than contradicts the seq-cell-overhead priority set earlier:
Source #3 isn't just adding area, it's adding power disproportionately in
the smaller, simpler designs.

**The AXI mux/demux cases (full composition, FIFO/arbiter included on both
sides) land in a tighter, more moderate band than the smaller standalone
cases**: area ratios 2.86x-3.67x, power ratios 2.26x-2.50x - both noticeably
milder than `arbiter`'s standalone 2.56x area / 6.43x power. This is
consistent with the composition diluting the smaller components' sharper
ratios: the FIFO/arbiter instances (relatively mild ratios on their own,
2.3x-2.6x area) make up a large share of total cells in the AXI aggregate,
pulling the blended ratio toward their own more moderate numbers and away
from whatever the AXI routing logic's own ratio would be in isolation (see
"Not just composition" above for that isolated-routing-logic view, using the
generic-cell proxy).

**Timing (worst setup slack) shows no consistent pattern favoring either
side** - Anvil is sometimes worse (`fifo`: 7.26 ns vs SV's 7.70 ns;
`spill_register`: 6.71 vs 7.81; `arbiter`: 5.96 vs 6.99) at this fixed
100 MHz constraint, all comfortably met either way. Not investigated
further in this pass since none of the designs are anywhere near failing
timing at this clock - the area/power story is where the real signal is.
