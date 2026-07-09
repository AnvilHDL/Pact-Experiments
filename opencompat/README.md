# PACT — 12 real communicating components (open-setting)

Retained, **unmodified** upstream RTL for the 12 rows of the communication-safety
table, kept in the **open-system setting**: each component's boundary interface
is exposed and the environment is left unspecified, matching how a PACT open type
states the contract expected *from* the interfacing environment. No environment
is simulated; the deliverable is the real source + a per-row analysis
(`ANNOTATIONS.md`) of its implicit contract and the inconsistency PACT would
catch.

## Summary

| # | Component (retained) | Repo | Kind | Setting | Provenance |
|---|----------------------|------|------|---------|------------|
| 1 | `adbg_axi_biu.sv` | adv_dbg_if | order | closed-pairwise | **FILED** (pulpino #182) |
| 2 | `axi_test.sv` (`send_aw`/`send_w`) | pulp/axi | order | closed-pairwise | **FILED** (axi #21) |
| 3 | `axi_demux.sv` | pulp/axi | order | **open** | DOCUMENTED |
| 4 | `axis_fifo.v` | verilog-axis | timing | closed-pairwise | DOCUMENTED |
| 5 | `axi_test.sv` (per-ID monitor) | pulp/axi | order | **open** | CLASS |
| 6 | `axi_xbar.sv` | pulp/axi | order | **open** | DOCUMENTED (≈ paper Fig. 2) |
| 7 | `wbuart.v` | wbuart32 | missing | closed-pairwise | **FILED** (litex #572) |
| 8 | `wbuart.v` (narrow side) | wbuart32 | order | closed-pairwise | CLASS (litex #572) |
| 9 | `ccu_fsm.sv` (+ace/snoop intf) | pulp/ace | order | **open** | DOCUMENTED (Culsans) |
| 10 | `ccu_fsm.sv` | pulp/ace | order/race | **open** | CLASS |
| 11 | `axi_demux.sv`, `axi_mux.sv` | pulp/axi | order | **open** | CLASS (eXpect ICCAD'24) |
| 12 | `axi_mux.sv` | pulp/axi | order | **open** | DOCUMENTED (thesis) |

`order` dominates once ordering mismatches are included — both sides assert
everything, but in a sequence the peer does not admit. `missing` (a required
action never offered) and `timing` (right order, wrong cycle) are the other two.

## Provenance levels

- **FILED** — filed upstream issue with the offending code (rows 1, 2, 7; row 8 same issue).
- **DOCUMENTED** — real named component + a documented rule it can violate (rows 3, 4, 6, 9, 12).
- **CLASS** — representative of a documented class; no single pinned upstream bug — *verify before citing* (rows 5, 8, 10, 11).

## Source links (commit-pinned permalinks)

All links are pinned to the exact commit fetched, so they will not drift. Where a
row has a specific region of interest, the link deep-links to those lines.

| Retained file | Upstream permalink (with bug region) |
|---------------|--------------------------------------|
| `adbg_axi_biu.sv` | [adv_dbg_if @ c4d7aa1 · rtl/adbg_axi_biu.sv#L509-L545](https://github.com/pulp-platform/adv_dbg_if/blob/c4d7aa177ef96b0fdff8748f81bd15489446c95a/rtl/adbg_axi_biu.sv#L509-L545) |
| `axi_test.sv` | [axi @ e55ae2a · src/axi_test.sv#L80-L96](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_test.sv#L80-L96) |
| `axi_demux.sv` | [axi @ e55ae2a · src/axi_demux.sv#L56-L92](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_demux.sv#L56-L92) |
| `axi_mux.sv` | [axi @ e55ae2a · src/axi_mux.sv#L34-L162](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_mux.sv#L34-L162) |
| `axi_xbar.sv` | [axi @ e55ae2a · src/axi_xbar.sv](https://github.com/pulp-platform/axi/blob/e55ae2a7ee606ee3cfd4257f63982a971b704407/src/axi_xbar.sv) |
| `wbuart.v` | [wbuart32 @ f43a6b8 · rtl/wbuart.v#L61-L67](https://github.com/ZipCPU/wbuart32/blob/f43a6b83c3a70fb2ac0696a45c5545b233fb860b/rtl/wbuart.v#L61-L67) |
| `axis_fifo.v` | [verilog-axis @ 48ff7a7 · rtl/axis_fifo.v#L47-L116](https://github.com/alexforencich/verilog-axis/blob/48ff7a7e2ef782cf778d47910cf85835c64b1bce/rtl/axis_fifo.v#L47-L116) |
| `ccu_fsm.sv` | [ace @ f919f5c · src/ccu_fsm.sv#L22-L60](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/ccu_fsm.sv#L22-L60) |
| `ace_ccu_top.sv` | [ace @ f919f5c · src/ace_ccu_top.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/ace_ccu_top.sv) |
| `ace_intf.sv` | [ace @ f919f5c · src/ace_intf.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/ace_intf.sv) |
| `snoop_intf.sv` | [ace @ f919f5c · src/snoop_intf.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/snoop_intf.sv) |
| `ace_pkg.sv` | [ace @ f919f5c · src/ace_pkg.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/ace_pkg.sv) |
| `snoop_pkg.sv` | [ace @ f919f5c · src/snoop_pkg.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/snoop_pkg.sv) |
| `ace_trs_dec.sv` | [ace @ f919f5c · src/ace_trs_dec.sv](https://github.com/pulp-platform/ace/blob/f919f5cabf41961321bf37327ab4eb726dfdbd0c/src/ace_trs_dec.sv) |
| `culsans_top.sv` | [culsans @ a3d7416 · rtl/src/culsans_top.sv#L651-L690](https://github.com/pulp-platform/culsans/blob/a3d741600d03bba2f21b795eda4f6faf7124a152/rtl/src/culsans_top.sv#L651-L690) |
| `culsans_pkg.sv` | [culsans @ a3d7416 · rtl/include/culsans_pkg.sv](https://github.com/pulp-platform/culsans/blob/a3d741600d03bba2f21b795eda4f6faf7124a152/rtl/include/culsans_pkg.sv) |

### Repo landing pages

- pulp-platform/adv_dbg_if — https://github.com/pulp-platform/adv_dbg_if
- pulp-platform/axi — https://github.com/pulp-platform/axi
- ZipCPU/wbuart32 — https://github.com/ZipCPU/wbuart32
- alexforencich/verilog-axis — https://github.com/alexforencich/verilog-axis
- pulp-platform/ace — https://github.com/pulp-platform/ace
- pulp-platform/culsans — https://github.com/pulp-platform/culsans

### Filed-issue references (for `FILED` rows)

- Row 1 — pulpino #182: https://github.com/pulp-platform/pulpino/issues/182
- Row 2 — axi #21: https://github.com/pulp-platform/axi/issues/21
- Rows 7/8 — litex #572: https://github.com/enjoy-digital/litex/issues/572

## Layout

```
originals/                     retained upstream RTL, one directory per component (the deliverable)
  <component>/<component>.sv     unmodified upstream source
  <component>/type_<component>.anvil   PACT open-type protocol (only for the 4 components below)
ANNOTATIONS.md                 per-row open-setting analysis + exact lines + PACT mapping
```

`originals/` has one subdirectory per retained file (8 subdirectories for the 12
table rows — several rows share a file, see the Summary table above):
`adbg_axi_biu/`, `axi_test/`, `axi_demux/`, `axis_fifo/`, `axi_xbar/`, `wbuart/`,
`ccu_fsm/`, `axi_mux/`. Each holds the untouched upstream source as fetched (commit
pinned in the Source links table above).

### PACT `.anvil` types

Four of the eight components additionally carry a hand-authored `type_<component>.anvil`
protocol file, written in the same interface/chan/pool syntax as `src/compat/type_*.anvil`
elsewhere in this repo (see `pact.md` for the language). These were picked as the
largest/most structurally distinct examples — one clean `FILED` pairwise bug, one
multi-row file with two different bug shapes, and the two multi-party/open coherence
rows — rather than doing all twelve mechanically:

| Component | Rows typed | What the type encodes |
|-----------|-----------|------------------------|
| `adbg_axi_biu/type_adbg_axi_biu.anvil` | 1 | closed-pairwise: manager gates `w!` on having observed `aw?`, inconsistent with a legal subordinate that may wait for `w?` before granting `aw` |
| `axi_test/type_axi_test.anvil` | 2, 5 | driver's assumed `aw`-before-`w` acceptance order (row 2); per-ID outstanding-write monitor, no `aw!` reuse before matching `b?` (row 5) |
| `ccu_fsm/type_ccu_fsm.anvil` | 9, 10 | ID-less snoop channel needs FIFO response order (row 9); writeback-vs-snoop race on the same line (row 10) |
| `axi_mux/type_axi_mux.anvil` | 11, 12 | response reorder/drop across subordinates (row 11); same-ID in-order delivery as the source of a wait cycle (row 12) |

The other four (`axi_demux`, `axis_fifo`, `axi_xbar`, `wbuart`) are source-only for
now — each is documented in `ANNOTATIONS.md` but has no `.anvil` file yet.

### File count per example

Every `originals/<component>/` directory holds exactly the upstream source file(s) —
1 file in all 8 cases (no component here spans multiple upstream files the way row 9's
full dependency set (`ace_intf.sv`, `snoop_intf.sv`, `ace_pkg.sv`, `snoop_pkg.sv`) might
suggest; only `ccu_fsm.sv` itself is retained, per the Summary table). The 4 components
above additionally carry one `.anvil` type file, so those directories have 2 files;
the remaining 4 have 1.

## Caveats worth stating in the paper

- The `CLASS` rows (5, 8, 10, 11) retain a real component to expose the boundary,
  but the specific inconsistency is representative of a documented class, not a
  single filed bug. Rows 7/8 and their retained `wbuart.v` are a *correct* slave
  used to show the open Wishbone interface; the bug itself is litex #572 (migen).
- Rows 3, 5, 6, 9, 10, 11, 12 are the ones whose verdict genuinely depends on the
  environment — they justify PACT's open type machinery / Rabin game. Rows 1, 2,
  4, 7, 8 are decided pairwise and showcase modular local checking.
```
