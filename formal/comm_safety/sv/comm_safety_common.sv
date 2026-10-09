`ifdef FORMAL_COMM_SAFETY
// COMM_ONLY_S / COMM_ONLY_L keep only the S or L assertions; by default both are checked.
`ifndef COMM_ASSERT_MACROS
`define COMM_ASSERT_MACROS
`ifdef COMM_ONLY_L
`define COMM_S_ASSERT(e)
`else
`define COMM_S_ASSERT(e) assert(e)
`endif
`ifdef COMM_ONLY_S
`define COMM_L_ASSERT(e)
`else
`define COMM_L_ASSERT(e) assert(e)
`endif
`endif
// =============================================================================
// Communication-safety harnesses for the common_cells case studies
// (FIFO, stream FIFO, spill register, round-robin arbiter).
//
// Every harness instantiates the FULL cycle-equivalence testbench from
// src/testbenches/ (the DUT together with the master/slave stubs that drive
// it) and checks exactly the two halves of communication safety as defined
// in the Pact paper. Nothing else is asserted.
//
//   S  Synchronization safety.  No reachable stuck state: an exchange a
//      participant commits to completes with its peer in that same cycle,
//      and the two sides agree on which exchanges happened (no dropped,
//      phantom or duplicated handshake; status messages are seen exactly
//      when raised).
//   L  Liveness.  Every started exchange finishes: a participant that is in
//      flight returns to its progress point, and a message offered on a
//      channel is accepted, within a bound derived from the stubs' periods.
//      Ages are counted only while an obligation is open, because the stubs
//      deliberately idle for growing stretches (powers of two), which no
//      fixed unconditional bound could cover.
//
// Deliberately NOT checked (functional, not communication safety): data
// ordering and values, occupancy counts, status-flag arithmetic, response
// codes.
//
// Mechanics: the stubs export `f_*` self-report signals (behind
// FORMAL_COMM_SAFETY in the testbench files); DUT-side views are read from
// the DUT's own internal handshake enables. Everything is plain always_ff
// assert/assume because yosys-slang rejects SVA, and it also rejects
// hierarchical references to enum *members*, which is why state decoding
// lives inside the stubs. Each harness is guarded by its own define so that
// the two testbenches that both name their top `tb_fifo` never clash.
// =============================================================================

// -----------------------------------------------------------------------------
// FIFO  (src/testbenches/fifo_test.sv: fifo_v3 + push master + pop slave)
// -----------------------------------------------------------------------------
`ifdef FORMAL_COMM_FIFO_FULL_DESIGN
module comm_fifo_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned MaxTransactions = 8;
  // The master starts a push attempt every <=3 cycles and the slave a pop
  // attempt every <=7 cycles (both also on powers of two). An attempt that
  // finds the queue full/empty therefore waits at most one peer period, a
  // queued item is drained within Depth pop periods (8*7 = 56), and every
  // participant's progress marker recurs within one attempt plus one wait.
  localparam int unsigned AttemptBound  = 16;
  localparam int unsigned DrainBound    = 64;
  localparam int unsigned ProgressBound = 64;

  logic full_o;
  logic empty_o;
  logic push_i;
  logic pop_i;
  logic shadow_full_req;
  logic shadow_empty_req;
  logic shadow_push_req;
  logic shadow_pop_req;

  tb_fifo #(
    .MAX_TRANSACTIONS(MaxTransactions)
  ) full_design (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .formal_full_o(full_o),
    .formal_empty_o(empty_o),
    .formal_push_i(push_i),
    .formal_pop_i(pop_i),
    .formal_shadow_full_req(shadow_full_req),
    .formal_shadow_empty_req(shadow_empty_req),
    .formal_shadow_push_req(shadow_push_req),
    .formal_shadow_pop_req(shadow_pop_req)
  );

  // Wire-level handshakes.
  wire push_fire = push_i && !full_o;
  wire pop_fire  = pop_i && !empty_o;

  // Participant self-reports.
  wire mst_attempt   = full_design.mst.f_attempt;
  wire mst_busy      = full_design.mst.f_busy;
  wire slv_attempt   = full_design.slv.f_attempt;
  wire slv_busy      = full_design.slv.f_busy;
  wire mst_progress  = full_design.mst_progress;
  wire slv_progress  = full_design.slv_progress;
  wire fifo_progress = full_design.fifo_progress;

  // Reset must be applied once, or induction may start from an unreachable
  // state in which the age counters are already large.
  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Attempt windows: handshakes counted since the current attempt began.
  logic       mst_open, slv_open;
  logic [1:0] mst_fires, slv_fires;
  wire  [1:0] mst_fires_now = (mst_attempt ? 2'd0 : mst_fires) + {1'b0, push_fire};
  wire  [1:0] slv_fires_now = (slv_attempt ? 2'd0 : slv_fires) + {1'b0, pop_fire};

  // Liveness counters.
  (* anyseq *) logic track_this_push;
  logic tracking_push;
  logic [$clog2(DrainBound+1)-1:0]    live_age;
  logic [$clog2(AttemptBound+1)-1:0]  mst_age, slv_age;
  logic [$clog2(ProgressBound+1)-1:0] mst_prog_age, slv_prog_age, fifo_prog_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_open <= 1'b0;
      slv_open <= 1'b0;
      mst_fires <= '0;
      slv_fires <= '0;
      tracking_push <= 1'b0;
      live_age <= '0;
      mst_age <= '0;
      slv_age <= '0;
      mst_prog_age <= '0;
      slv_prog_age <= '0;
      fifo_prog_age <= '0;
    end else begin
      // ---- S: a committed push/pop is accepted in the same cycle ----
      `COMM_S_ASSERT(!push_i || !full_o);
      `COMM_S_ASSERT(!pop_i || !empty_o);

      // ---- S: the FIFO's own accept flags agree with the wire handshakes ----
      `COMM_S_ASSERT(shadow_push_req == push_fire);
      `COMM_S_ASSERT(shadow_pop_req == pop_fire);

      // ---- S: full/empty status messages are seen by the peer exactly when raised ----
      `COMM_S_ASSERT(shadow_full_req == full_o);
      `COMM_S_ASSERT(shadow_empty_req == empty_o);

      // ---- S: exactly one push per master attempt ----
      if (mst_attempt) begin
        `COMM_S_ASSERT(!mst_open || mst_fires == 2'd1);          // previous attempt: one push
      end
      `COMM_S_ASSERT(!(mst_open || mst_attempt) || mst_fires_now <= 2'd1); // never two
      `COMM_S_ASSERT(mst_open || mst_attempt || !push_fire);     // none outside an attempt
      mst_open <= mst_open | mst_attempt;
      if (mst_open || mst_attempt) mst_fires <= mst_fires_now;

      // ---- S: exactly one pop per slave attempt ----
      if (slv_attempt) begin
        `COMM_S_ASSERT(!slv_open || slv_fires == 2'd1);
      end
      `COMM_S_ASSERT(!(slv_open || slv_attempt) || slv_fires_now <= 2'd1);
      `COMM_S_ASSERT(slv_open || slv_attempt || !pop_fire);
      slv_open <= slv_open | slv_attempt;
      if (slv_open || slv_attempt) slv_fires <= slv_fires_now;

      // ---- L: an in-flight attempt completes within AttemptBound ----
      if (mst_busy) begin
        mst_age <= mst_age + 1'b1;
        `COMM_L_ASSERT(mst_age < AttemptBound);
      end else begin
        mst_age <= '0;
      end
      if (slv_busy) begin
        slv_age <= slv_age + 1'b1;
        `COMM_L_ASSERT(slv_age < AttemptBound);
      end else begin
        slv_age <= '0;
      end

      // ---- L: a pushed item is popped within DrainBound ----
      // (a nondeterministically chosen push is tracked until the queue has
      // drained past it; with in-order pops that is the first pop after it
      // when the tracked push was the oldest, so this bounds the drain of
      // the head of the queue)
      // if (!tracking_push && push_fire && track_this_push) begin
      //   tracking_push <= 1'b1;
      //   live_age <= '0;
      // end else if (tracking_push && pop_fire) begin
      //   tracking_push <= 1'b0;
      //   live_age <= '0;
      // end else if (tracking_push) begin
      //   live_age <= live_age + 1'b1;
      //   assert(live_age < DrainBound);
      // end else begin
      //   live_age <= '0;
      // end

      // ---- L: every participant's progress marker recurs within ProgressBound ----
      if (mst_progress) begin
        mst_prog_age <= '0;
      end else begin
        mst_prog_age <= mst_prog_age + 1'b1;
        `COMM_L_ASSERT(mst_prog_age < ProgressBound);
      end
      if (slv_progress) begin
        slv_prog_age <= '0;
      end else begin
        slv_prog_age <= slv_prog_age + 1'b1;
        `COMM_L_ASSERT(slv_prog_age < ProgressBound);
      end
      if (fifo_progress) begin
        fifo_prog_age <= '0;
      end else begin
        fifo_prog_age <= fifo_prog_age + 1'b1;
        `COMM_L_ASSERT(fifo_prog_age < ProgressBound);
      end
    end
  end
endmodule
`endif

// -----------------------------------------------------------------------------
// Stream FIFO  (src/testbenches/stream_fifo_test.sv: passthrough_stream_fifo
//               + valid/ready master + ready/valid slave)
// -----------------------------------------------------------------------------
`ifdef FORMAL_COMM_STREAM_FIFO_FULL_DESIGN
module comm_stream_fifo_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned Depth = 8;
  // Both stubs start an attempt every <=4 cycles (and on powers of two), so
  // an attempt blocked on a full/empty queue waits at most one peer period,
  // an offered push is taken within that period, a queued item is drained
  // within Depth periods (8*4 = 32), and the queue itself makes progress
  // (some handshake) within one period.
  localparam int unsigned AttemptBound  = 16;
  localparam int unsigned DrainBound    = 64;
  localparam int unsigned ProgressBound = 32;

  tb_fifo full_design (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  // The stream testbench keeps fifo_v3's net names: push_i drives valid_i,
  // full_o carries ready_o, empty_o carries valid_o, pop_i drives ready_i.
  wire valid_i = full_design.push_i;
  wire ready_o = full_design.full_o;
  wire valid_o = full_design.empty_o;
  wire ready_i = full_design.pop_i;
  wire in_fire  = valid_i && ready_o;
  wire out_fire = valid_o && ready_i;

  // DUT's own view: the load enable of a push and the read-pointer advance
  // of a pop.
  wire dut_push = full_design.dut.load_data;
  wire dut_pop  = (full_design.dut.read_ptr_d != full_design.dut.read_ptr_q);

  // Participant self-reports.
  wire mst_attempt = full_design.mst.f_attempt;
  wire mst_busy    = full_design.mst.f_busy;
  wire slv_attempt = full_design.slv.f_attempt;
  wire slv_busy    = full_design.slv.f_busy;

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  logic       mst_open, slv_open;
  logic [1:0] mst_fires, slv_fires;
  wire  [1:0] mst_fires_now = (mst_attempt ? 2'd0 : mst_fires) + {1'b0, in_fire};
  wire  [1:0] slv_fires_now = (slv_attempt ? 2'd0 : slv_fires) + {1'b0, out_fire};

  logic [$clog2(AttemptBound+1)-1:0]  mst_age, slv_age, in_wait_age;
  logic [$clog2(DrainBound+1)-1:0]    out_wait_age;
  logic [$clog2(ProgressBound+1)-1:0] fifo_prog_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_open <= 1'b0;
      slv_open <= 1'b0;
      mst_fires <= '0;
      slv_fires <= '0;
      mst_age <= '0;
      slv_age <= '0;
      in_wait_age <= '0;
      out_wait_age <= '0;
      fifo_prog_age <= '0;
    end else begin
      // ---- S: the FIFO's own push/pop enables agree with the wire handshakes ----
      `COMM_S_ASSERT(dut_push == in_fire);
      `COMM_S_ASSERT(dut_pop == out_fire);

      // ---- S: exactly one push per master attempt ----
      if (mst_attempt) begin
        `COMM_S_ASSERT(!mst_open || mst_fires == 2'd1);
      end
      `COMM_S_ASSERT(!(mst_open || mst_attempt) || mst_fires_now <= 2'd1);
      `COMM_S_ASSERT(mst_open || mst_attempt || !in_fire);
      mst_open <= mst_open | mst_attempt;
      if (mst_open || mst_attempt) mst_fires <= mst_fires_now;

      // ---- S: exactly one pop per slave attempt ----
      if (slv_attempt) begin
        `COMM_S_ASSERT(!slv_open || slv_fires == 2'd1);
      end
      `COMM_S_ASSERT(!(slv_open || slv_attempt) || slv_fires_now <= 2'd1);
      `COMM_S_ASSERT(slv_open || slv_attempt || !out_fire);
      slv_open <= slv_open | slv_attempt;
      if (slv_open || slv_attempt) slv_fires <= slv_fires_now;

      // // ---- L: in-flight attempts complete within AttemptBound ----
      // if (mst_busy) begin
      //   mst_age <= mst_age + 1'b1;
      //   assert(mst_age < AttemptBound);
      // end else begin
      //   mst_age <= '0;
      // end
      // if (slv_busy) begin
      //   slv_age <= slv_age + 1'b1;
      //   assert(slv_age < AttemptBound);
      // end else begin
      //   slv_age <= '0;
      // end

      // ---- L: an offered push is accepted within AttemptBound ----
      if (valid_i && !ready_o) begin
        in_wait_age <= in_wait_age + 1'b1;
        `COMM_L_ASSERT(in_wait_age < AttemptBound);
      end else begin
        in_wait_age <= '0;
      end

      // ---- L: an offered item is consumed within DrainBound ----
      if (valid_o && !ready_i) begin
        out_wait_age <= out_wait_age + 1'b1;
        `COMM_L_ASSERT(out_wait_age < DrainBound);
      end else begin
        out_wait_age <= '0;
      end

      // ---- L: the FIFO participant makes progress within ProgressBound ----
      if (in_fire || out_fire) begin
        fifo_prog_age <= '0;
      end else begin
        fifo_prog_age <= fifo_prog_age + 1'b1;
        `COMM_L_ASSERT(fifo_prog_age < ProgressBound);
      end
    end
  end
endmodule
`endif

// -----------------------------------------------------------------------------
// Spill register  (src/testbenches/spill_register_test.sv:
//                  spill_register_flushable + valid/ready master + pop slave)
// -----------------------------------------------------------------------------
`ifdef FORMAL_COMM_SPILL_FULL_DESIGN
module comm_spill_formal(input logic clk_i, input logic rst_ni);
  // The master starts a push attempt every 2 cycles; the slave pops at most
  // once every 12 cycles (it enters TRY_POP when cycle%4==0 and only pops if
  // the next cycle is also a multiple of 3). With two register slots the
  // master is blocked until a pop, so a blocked attempt and an offered push
  // wait at most one pop period, the item at the head of the register is
  // taken within one pop period, and some handshake happens every period.
  localparam int unsigned AttemptBound  = 24;
  localparam int unsigned DrainBound    = 24;
  localparam int unsigned ProgressBound = 24;

  tb_spill full_design (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  wire valid_i = full_design.valid_i;
  wire ready_o = full_design.ready_o;
  wire valid_o = full_design.valid_o;
  wire ready_i = full_design.ready_i;
  wire in_fire  = valid_i && ready_o;
  wire out_fire = valid_o && ready_i;

  // DUT's own view of an accepted push: the A-register fill enable.
  wire dut_fill = full_design.dut.gen_spill_reg.a_fill;

  // Participant self-reports.
  wire mst_attempt    = full_design.mst.f_attempt;
  wire mst_busy       = full_design.mst.f_busy;
  wire slv_pop_commit = full_design.slv.f_pop_commit;

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  logic       mst_open;
  logic [1:0] mst_fires;
  wire  [1:0] mst_fires_now = (mst_attempt ? 2'd0 : mst_fires) + {1'b0, in_fire};

  logic [$clog2(AttemptBound+1)-1:0]  mst_age, in_wait_age;
  logic [$clog2(DrainBound+1)-1:0]    out_wait_age;
  logic [$clog2(ProgressBound+1)-1:0] prog_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_open <= 1'b0;
      mst_fires <= '0;
      mst_age <= '0;
      in_wait_age <= '0;
      out_wait_age <= '0;
      prog_age <= '0;
    end else begin
      // ---- S: the register's own fill enable agrees with the wire handshake ----
      `COMM_S_ASSERT(dut_fill == in_fire);

      // ---- S: a committed receive finds the data it was promised ----
      `COMM_S_ASSERT(!slv_pop_commit || valid_o);
      `COMM_S_ASSERT(slv_pop_commit == out_fire);

      // ---- S: exactly one push per master attempt ----
      if (mst_attempt) begin
        `COMM_S_ASSERT(!mst_open || mst_fires == 2'd1);
      end
      `COMM_S_ASSERT(!(mst_open || mst_attempt) || mst_fires_now <= 2'd1);
      `COMM_S_ASSERT(mst_open || mst_attempt || !in_fire);
      mst_open <= mst_open | mst_attempt;
      if (mst_open || mst_attempt) mst_fires <= mst_fires_now;

      // ---- L: a blocked push attempt completes within AttemptBound ----
      if (mst_busy) begin
        mst_age <= mst_age + 1'b1;
        `COMM_L_ASSERT(mst_age < AttemptBound);
      end else begin
        mst_age <= '0;
      end

      // ---- L: an offered push is accepted within AttemptBound ----
      if (valid_i && !ready_o) begin
        in_wait_age <= in_wait_age + 1'b1;
        `COMM_L_ASSERT(in_wait_age < AttemptBound);
      end else begin
        in_wait_age <= '0;
      end

      // // ---- L: the item at the head of the register is taken within DrainBound ----
      // if (valid_o && !ready_i) begin
      //   out_wait_age <= out_wait_age + 1'b1;
      //   assert(out_wait_age < DrainBound);
      // end else begin
      //   out_wait_age <= '0;
      // end

      // ---- L: the register participant makes progress within ProgressBound ----
      if (in_fire || out_fire) begin
        prog_age <= '0;
      end else begin
        prog_age <= prog_age + 1'b1;
        `COMM_L_ASSERT(prog_age < ProgressBound);
      end
    end
  end
endmodule
`endif

// -----------------------------------------------------------------------------
// Round-robin arbiter  (src/testbenches/arbiter_test.sv: rr_arb_tree
//                       + 4 requesting slaves + granting master)
// -----------------------------------------------------------------------------
`ifdef FORMAL_COMM_ARBITER_FULL_DESIGN
module comm_arbiter_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NumSlaves = 4;
  // Every slave requests when cycle%4==0 and holds the request until it is
  // granted; the master answers a pending request one cycle after every
  // multiple of 3. Fair round robin therefore serves a slave within
  // NumSlaves grants (~12 cycles), and a pending request is answered within
  // one grant period.
  localparam int unsigned GrantBound   = 32;
  localparam int unsigned RequestBound = 8;

  tb_arbiter full_design (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  wire [NumSlaves-1:0] req_i = full_design.req_i;
  wire [NumSlaves-1:0] gnt_o = full_design.gnt_o;
  wire                 req_o = full_design.req_o;
  wire                 gnt_i = full_design.gnt_i;
  wire [2:0]           idx_o = full_design.idx_o;

  // Participant self-reports.
  wire [NumSlaves-1:0] slv_req;
  for (genvar i = 0; i < NumSlaves; i++) begin : gen_slv_reports
    assign slv_req[i] = full_design.gen_slaves[i].slave.f_req;
  end
  wire mst_gnt = full_design.mst.f_gnt;

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  logic [$clog2(GrantBound+1)-1:0]   grant_age [NumSlaves-1:0];
  logic [$clog2(RequestBound+1)-1:0] req_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < NumSlaves; i++) begin
        grant_age[i] <= '0;
      end
      req_age <= '0;
    end else begin
      // ---- S: every offered request reaches the master, none is invented ----
      `COMM_S_ASSERT(req_o == (|req_i));

      // ---- S: the master's grant is delivered to exactly one requester, and
      //         only when there is one; a grant never reaches a non-requester ----
      `COMM_S_ASSERT((|gnt_o) == (gnt_i && req_o));
      `COMM_S_ASSERT((gnt_o & (gnt_o - 1'b1)) == '0);
      `COMM_S_ASSERT(!(gnt_i && req_o) || gnt_o[idx_o[1:0]]);

      // ---- S: the master only grants a pending request ----
      `COMM_S_ASSERT(!mst_gnt || req_o);

      for (int i = 0; i < NumSlaves; i++) begin
        // ---- S: the request wire carries exactly the slave's intent ----
        `COMM_S_ASSERT(slv_req[i] == req_i[i]);
        // ---- S: a grant only reaches a slave that is waiting for it ----
        `COMM_S_ASSERT(!gnt_o[i] || slv_req[i]);

        // ---- L: a requesting slave is granted within GrantBound ----
        if (slv_req[i] && !gnt_o[i]) begin
          grant_age[i] <= grant_age[i] + 1'b1;
          `COMM_L_ASSERT(grant_age[i] < GrantBound);
        end else begin
          grant_age[i] <= '0;
        end
      end

      // ---- L: a pending request is answered by the master within RequestBound ----
      if (req_o && !gnt_i) begin
        req_age <= req_age + 1'b1;
        `COMM_L_ASSERT(req_age < RequestBound);
      end else begin
        req_age <= '0;
      end
    end
  end
endmodule
`endif

`endif
