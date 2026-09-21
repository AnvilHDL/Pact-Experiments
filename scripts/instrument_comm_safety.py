#!/usr/bin/env python3
"""Maintain FORMAL_COMM_SAFETY instrumentation in tracked RTL testbenches.

Run with --check to inspect without writing, or pass filenames to update
selected testbenches. Existing instrumentation is retained.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
TB_DIR = ROOT / "src" / "testbenches"
MARKER = "Communication-safety self-report"

# ----------------------------------------------------------------- templates
ATTEMPT = """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_attempt : first cycle of a {kind} attempt (the FSM has just entered
//               {trystate}); every attempt is meant to complete exactly one
//               {kind} handshake with the DUT.
//   f_busy    : this participant is in flight (it has started a {kind} and
//               has not yet reached its progress point).
logic f_try_q;
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) f_try_q <= 1'b0;
    else         f_try_q <= (state == {trystate});
end
wire f_attempt = (state == {trystate}) && !f_try_q;
wire f_busy    = {busy};
`endif
"""

HDR = """
`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
"""

ACE_EDITS = [
    ("mem_controller", HDR + """  wire f_ar_rcv = (state_q == IDLE) && req_i.ar_valid;      // ar_ready is 1 in IDLE
  // AR has priority in IDLE: an AW presented in the same cycle is handshaken
  // (aw_ready is 1) but not processed, so it is excluded from this view.
  wire f_aw_rcv = (state_q == IDLE) && req_i.aw_valid && !req_i.ar_valid;
  wire f_r_snd  = (state_q == READ_RESP) && req_i.r_ready;   // r_valid is 1 in READ_RESP
  wire f_w_rcv  = (state_q == WRITE_DATA) && req_i.w_valid;  // w_ready is 1 in WRITE_DATA
  wire f_b_snd  = (state_q == WRITE_RESP) && req_i.b_ready;  // b_valid is 1 in WRITE_RESP
  wire f_busy   = (state_q != IDLE);
`endif
"""),
    ("arbiter", HDR + """  wire                 f_busy  = (state_q != ARB_IDLE);
  wire                 f_read  = (state_q == ARB_READ);
  wire                 f_write = (state_q == ARB_WRITE);
  wire [IdxBits-1:0]   f_sel   = selected_q;
`endif
"""),
    ("ace_slave", HDR + """  // Request FSM (client side of the cache-request channel).
  wire f_ar_snd   = (req_state_q == REQ_SEND_AR) && resp_i.ar_ready;   // ar_valid is 1 in SEND_AR
  wire f_r_rcv    = (req_state_q == REQ_WAIT_R) && resp_i.r_valid && req_o.r_ready;
  wire f_aw_snd   = (req_state_q == REQ_SEND_AW) && resp_i.aw_ready;   // aw_valid is 1 in SEND_AW
  wire f_w_snd    = (req_state_q == REQ_SEND_W) && resp_i.w_ready;     // w_valid is 1 in SEND_W
  wire f_b_rcv    = (req_state_q == REQ_WAIT_B) && resp_i.b_valid && req_o.b_ready;
  wire f_req_busy = (req_state_q != REQ_IDLE);
  // Snoop FSM. The FSM samples ac_valid in SNP_IDLE but only raises ac_ready in
  // SNP_WAIT_AC, so the handshake it relies on is the one in SNP_WAIT_AC.
  wire f_ac_rcv   = (snp_state_q == SNP_WAIT_AC);
  wire f_cr_snd   = (snp_state_q == SNP_SEND_CR) && snoop_req_i.cr_ready;  // cr_valid is 1 in SEND_CR
  wire f_cd_snd   = (snp_state_q == SNP_SEND_CD) && snoop_req_i.cd_ready;  // cd_valid is 1 in SEND_CD
  wire f_snp_busy = (snp_state_q != SNP_IDLE);
`endif
"""),
]

KNOWN = {
    "fifo_test.sv": [
        ("master", ATTEMPT.format(kind="push", trystate="TRY_PUSH", busy="(state != IDLE)")),
        ("slave",  ATTEMPT.format(kind="pop",  trystate="TRY_POP",  busy="(state != IDLE)")),
    ],
    "stream_fifo_test.sv": [
        ("master", ATTEMPT.format(kind="push", trystate="TRY_PUSH", busy="(state != IDLE)")),
        ("slave",  ATTEMPT.format(kind="pop",  trystate="TRY_POP",  busy="(state != IDLE)")),
    ],
    "spill_register_test.sv": [
        ("master_spill", ATTEMPT.format(kind="push", trystate="TRY_PUSH", busy="(state == TRY_PUSH)")),
        ("slave_spill", """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_pop_commit : this participant has committed to receive `data` in this
//                  cycle. ready_i is a one-cycle pulse that is raised only
//                  after the FSM decided to pop, so a committed receive that
//                  finds valid_o low is a dropped exchange.
//   f_busy       : the participant is deciding (TRY_POP); it never blocks on
//                  the DUT, so it has no in-flight obligation of its own.
wire f_pop_commit = ready_i;
wire f_busy       = (state == TRY_POP);
`endif
"""),
    ],
    "arbiter_test.sv": [
        ("slave_arb", """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_req  : this participant is requesting and expects exactly one grant.
//   f_busy : in flight (waiting for that grant).
wire f_req  = (state == REQUESTING);
wire f_busy = (state == REQUESTING);
`endif
"""),
        ("master_arb", """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_common.sv.
//   f_gnt : this participant is issuing a grant in this cycle; a grant that
//           meets no pending request is a phantom exchange.
wire f_gnt = gnt_i;
`endif
"""),
    ],
    "axi_lite_demux_read_tb.sv": [
        ("axi_read_demux_slave", HDR + """  wire f_ar_snd = (state == SEND_AR) && ar_valid_o && ar_ready_i;
  wire f_r_rcv  = (state == WAIT_R) && r_valid_i;   // r_ready_o is constant 1
  wire f_busy   = (state != IDLE);
`endif
"""),
        ("axi_read_demux_master", HDR + """  // The FSM commits on ar_valid_i alone (it does not look at ar_ready_o), so
  // an AR presented while ar_ready_o is low would be counted here but never
  // handshaken: the harness compares this against the wire-level handshake.
  wire f_ar_rcv = (state == IDLE) && ar_valid_i;
  wire f_r_snd  = (state == SEND_R) && r_valid_o && r_ready_i;
  wire f_busy   = (state != IDLE);
`endif
"""),
    ],
    "axi_lite_demux_write_tb.sv": [
        ("axi_write_demux_slave", HDR + """  wire f_aw_snd = (state == SEND_AW) && aw_valid_o && aw_ready_i;
  wire f_w_snd  = (state == SEND_W) && w_valid_o && w_ready_i;
  wire f_b_rcv  = (state == WAIT_B) && b_valid_i;   // b_ready_o is constant 1
  wire f_busy   = (state != IDLE);
`endif
"""),
        ("axi_write_demux_master", HDR + """  // The FSM commits on aw_valid_i alone (it does not look at aw_ready_o).
  wire f_aw_rcv = (state == IDLE) && aw_valid_i;
  wire f_w_rcv  = (state == RECV_W) && w_ready_o && w_valid_i;
  wire f_b_snd  = (state == SEND_B) && b_valid_o && b_ready_i;
  wire f_busy   = (state != IDLE);
`endif
"""),
    ],
    "axi_lite_mux_read_tb.sv": [
        ("axi_read_slave", HDR + """  wire f_ar_snd = (state == SEND_AR) && ar_valid_o && ar_ready_i;
  wire f_r_rcv  = (state == WAIT_R) && r_valid_i;   // r_ready_o is constant 1
  wire f_busy   = (state != IDLE);
`endif
"""),
        ("axi_read_master", HDR + """  wire f_ar_rcv = (state == IDLE) && ar_ready_o && ar_valid_i;
  wire f_r_snd  = (state == SEND_R) && r_valid_o && r_ready_i;
  wire f_busy   = (state != IDLE);
`endif
"""),
    ],
    "axi_lite_mux_write_tb.sv": [
        ("axi_write_slave", HDR + """  wire f_aw_snd = (state == SEND_AW) && aw_valid_o && aw_ready_i;
  wire f_w_snd  = (state == SEND_W) && w_valid_o && w_ready_i;
  wire f_b_rcv  = (state == WAIT_B) && b_valid_i;   // b_ready_o is constant 1
  wire f_busy   = (state != IDLE);
`endif
"""),
        ("axi_write_master", HDR + """  wire f_aw_rcv = (state == IDLE) && aw_ready_o && aw_valid_i;
  wire f_w_rcv  = (state == RECV_W) && w_ready_o && w_valid_i;
  wire f_b_snd  = (state == SEND_B) && b_valid_o && b_ready_i;
  wire f_busy   = (state != IDLE);
`endif
"""),
    ],
    "ccu_fsm_tb.sv": ACE_EDITS,
    "ccu_fsm_tb2.sv": ACE_EDITS,
    "TLCrossBar_test.sv": [
        ("tl_master", """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv.
//   f_a_snd : this client counts its A request as sent in this cycle.
//   f_busy  : in flight (holding a_valid until the crossbar accepts it).
// The client accepts any D beat (d_ready is constant 1) and keeps no record
// of outstanding requests; the harness counts A sent vs D received instead.
wire f_a_snd = (state == WAITING) && a_valid && a_ready;
wire f_busy  = (state == WAITING);
`endif
"""),
        ("tl_slave", """
`ifdef FORMAL_COMM_SAFETY
// Communication-safety self-report, read hierarchically by the formal
// harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv.
//   f_a_rcv : this manager can only take a request into its bookkeeping when
//             IDLE, which is also when it raises a_ready; the harness checks
//             that no A handshake happens on the wire outside that state.
//   f_d_snd : the response is delivered in this cycle.
//   f_busy  : in flight (a response is owed).
wire f_a_rcv = (state == IDLE) && a_valid;
wire f_d_snd = (state == RESPONDING) && d_valid && d_ready;
wire f_busy  = (state == RESPONDING);
`endif
"""),
    ],
}


def module_span(text, module):
    m = re.search(r'^\s*module\s+' + re.escape(module) + r'\b', text, re.M)
    if not m:
        raise LookupError(f"module {module} not found")
    e = re.compile(r'^\s*endmodule\b', re.M).search(text, m.end())
    if not e:
        raise LookupError(f"endmodule for {module} not found")
    return m.start(), e.start()


def instrument_text(text, edits):
    """Return (new_text, [modules changed])."""
    done = []
    for module, block in edits:
        s, e = module_span(text, module)
        if MARKER in text[s:e]:
            continue
        text = text[:e] + block + "\n" + text[e:]
        done.append(module)
    return text, done


def main(argv):
    check = "--check" in argv
    if_known = "--if-known" in argv
    paths = [pathlib.Path(a) for a in argv if not a.startswith("--")]
    if not paths:
        paths = [TB_DIR / name for name in KNOWN]
    rc = 0
    for p in paths:
        edits = KNOWN.get(p.name)
        if edits is None:
            if if_known:
                continue
            print(f"{p}: not a known instrumentable testbench", file=sys.stderr)
            rc = 1
            continue
        if not p.exists():
            print(f"{p}: missing", file=sys.stderr)
            rc = 1
            continue
        try:
            new, done = instrument_text(p.read_text(), edits)
        except LookupError as err:
            print(f"{p}: {err}", file=sys.stderr)
            rc = 1
            continue
        if not done:
            print(f"{p.relative_to(ROOT) if p.is_relative_to(ROOT) else p}: already instrumented")
            continue
        if check:
            print(f"{p}: would instrument {', '.join(done)}")
            rc = 1
        else:
            p.write_text(new)
            print(f"{p.relative_to(ROOT) if p.is_relative_to(ROOT) else p}: instrumented {', '.join(done)}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
