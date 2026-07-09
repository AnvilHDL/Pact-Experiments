# `axi_xbar` — full cycle-by-cycle protocol (port-wire view)

`Cfg.NoSlvPorts` AXI4+ATOP subordinate-facing ports in
(`slv_ports_req_i[i]`/`slv_ports_resp_o[i]`), `Cfg.NoMstPorts` AXI4+ATOP
manager-facing ports out (`mst_ports_req_o[j]`/`mst_ports_resp_i[j]`), plus
an address-map side-channel (`addr_map_i`, `en_default_mst_port_i`,
`default_mst_port_i`) that is sampled combinationally wherever routing
decisions are made but does not itself carry any handshake. This top-level
file is pure topology — it does not itself implement any handshake logic —
built from two kinds of already-described building blocks wired in a
fully-connected grid: an `axi_xbar_unmuxed` fan-out core (not itself present
in this retained copy; described here only by what its port-level contract
must be, inferred from how this file uses it) that demultiplexes each of
the `NoSlvPorts` inputs out to up to `NoMstPorts` destinations, followed by
one `axi_mux` instance per manager port that arbitrates the `NoSlvPorts`
candidate streams converging on it back down to one — and `axi_mux`'s own
wire-level behavior (arbitration, the AW/W ownership handoff, id-based B/R
demux) is already fully documented in `../axi_mux/PROTOCOL.md` and is not
repeated here.

## Topology on the wires

- **Internal signals `mst_reqs[j][i]`/`mst_resps[j][i]`** (`NoMstPorts` by
  `NoSlvPorts` grid) are the only thing connecting the two stages: slave
  port `i`'s traffic destined for master port `j` appears on
  `mst_reqs[j][i]`, and `axi_mux` instance `j` treats this as its own
  slave-port-`i` input. Every one of the `NoSlvPorts × NoMstPorts` grid
  cells exists as a wire regardless of the `Connectivity` parameter — an
  unconnected cell (per `Connectivity[i][j]=0`) is simply tied to a
  request that is permanently deasserted on that grid position by the
  fan-out core, not physically absent.
- **Routing decision**: for each slave port `i`, on each accepted AW/AR
  beat, the fan-out core (not itself detailed here) consults `addr_map_i`
  (and, if unmapped, `en_default_mst_port_i[i]`/`default_mst_port_i[i]`) to
  decide which single master-port grid column `j` that beat's `valid` is
  steered to — this determination must, by construction of everything
  downstream, be made once per beat and held for that beat's whole
  handshake, since only one column `j` ever sees `mst_reqs[j][i].aw_valid`
  (or `.ar_valid`) asserted for a given originating beat.

## Composed per-manager-port view

For a fixed manager port `j`, `mst_reqs[j][*]` / `mst_resps[j][*]` across
all `NoSlvPorts` slave-port indices are exactly the `NoSlvPorts` slave-side
inputs to `axi_mux` instance `j` — so from master port `j`'s own AW/AR
arbitration, W-ownership handoff, and B/R id-demux, the wire behavior is
identical to what `../axi_mux/PROTOCOL.md` already describes, substituting
"slave port `i`'s traffic that happened to be routed to master port `j`"
for "slave port `i`" throughout. Each of the `NoMstPorts` `axi_mux`
instances runs this independently and in parallel — there is no
arbitration or resource sharing *between* different manager ports' `axi_mux`
instances on these wires.

## Row 6 — the liveness / circular-wait hazard, and why it needs the open game rather than a fixed pairwise check

**What this crossbar's own wires commit to, port by port**: every slave
port `i`'s AW (or AR) beat, once its destination `j` is decided, will
eventually see its `aw_ready` (or `ar_ready`) asserted *provided* master
port `j`'s own `axi_mux` instance eventually arbitrates slave-index `i` a
winning turn and provided `mst_ports_resp_i[j]` (the real subordinate
behind port `j`) eventually accepts it — i.e. every single grid cell's
progress, taken in isolation, is exactly the same "eventually serviced"
guarantee `axi_mux`'s own arbitration already provides pairwise. Nothing on
this crossbar's own wires — no shared token, no global scheduler, no
cross-port-j signal at all — coordinates the `NoMstPorts` independent
`axi_mux` instances with each other; each one only ever looks at its own
`NoSlvPorts`-wide slice of the grid.

**Where the liveness hazard comes from**: because AXI4 requires same-ID
responses to return to their originating slave port strictly in the order
their requests were accepted onto the shared master-port stream (the same
in-order rule `axi_mux`'s B/R channels implement per port `j`), a slave
port `i` that has an *earlier* AW/AR beat accepted at manager port `j`, but
whose response is still pending, will hold up `axi_mux` instance `j`'s
delivery of any *later* response for slave port `i` at that same master
port — not because of any signal shared across master ports, but because
each `axi_mux` instance only presents one in-order stream back to each
slave port and that discipline is per-instance-local, already documented in
`../axi_mux/PROTOCOL.md`'s row-12 section. If slave port `i`'s progress at
master port `j1` (e.g. draining a response) is itself gated on slave port
`i` first completing a *different*, still-pending transaction at master
port `j2` — and symmetrically some other slave port `i'` at `j2` is waiting
on progress at `j1` — the two `axi_mux` instances' independent, locally
correct in-order guarantees can close a cycle across the whole crossbar
that no single instance's own wires can see or break: `axi_mux` instance
`j1` is only watching its own grid row, `axi_mux` instance `j2` is only
watching its own, and neither's local "eventually serviced" promise
accounts for the other's.

**Why this cannot be decided pairwise**: unlike rows 1/2/4/7/8 (where one
fixed pair of interfaces settles the question) or even rows 3/9/10 (open,
but resolvable by asking whether *some* environment on one boundary
reconciles with one fixed peer), this row's hazard is emergent from the
composition of `NoMstPorts` locally-correct arbiters plus the specific
acquisition pattern of whichever masters and slaves are attached to *all*
of the crossbar's ports simultaneously — no two-party local check, however
thorough, can see the cycle, because it only exists once every port's
independent behavior is fixed together. This is the paper's flagship
liveness example precisely because deciding it requires asking whether
*some* joint schedule across every boundary keeps every progress marker
live under every internal resolution of the `NoMstPorts` independent
arbiters — the full environment-quantifier game, not a fixed pairwise
comparison — and it is also exactly where state-space enumeration blows up
fastest, since the number of interacting local schedulers grows with
`NoSlvPorts × NoMstPorts`.
