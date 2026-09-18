`ifdef FORMAL_COMM_SAFETY
// =============================================================================
// Communication-safety harnesses for the testbench-driven case studies
// (AXI-Lite demux read/write, AXI-Lite mux read/write, ACE CCU, TileLink
// crossbar).
//
// Every harness instantiates the FULL cycle-equivalence testbench from
// src/testbenches/ (the DUT together with the stubs that drive it) and checks
// exactly the two halves of communication safety as defined in the Pact
// paper. Nothing else is asserted.
//
//   S  Synchronization safety.  No reachable stuck state: an exchange a
//      participant commits to completes with its peer in that same cycle,
//      and the two sides agree on which exchanges happened (no dropped,
//      phantom or duplicated handshake). For the routers this includes the
//      relay property: a message taken on one side is handed over on exactly
//      one port of the other side in the same cycle, matching the router's
//      own bookkeeping.
//   L  Liveness.  Every started exchange finishes: a participant that is in
//      flight returns to its progress point, a router's outstanding
//      transactions drain, and a message offered on a channel is accepted,
//      each within a bound derived from the stubs' timing. Ages are counted
//      only while an obligation is open, because the stubs deliberately idle
//      for growing stretches (powers of two), which no fixed unconditional
//      bound could cover.
//
// Deliberately NOT checked (functional, not communication safety): payload
// and address values, response codes, ID/route bookkeeping against the
// address, queue occupancy limits.
//
// Mechanics: the stubs export `f_*` self-report signals (behind
// FORMAL_COMM_SAFETY in the testbench files); DUT-side views are read from
// the DUT's own internal handshake enables via hierarchical references.
// Everything is plain always_ff assert/assume because yosys-slang rejects
// SVA, and it also rejects hierarchical references to enum *members*, which
// is why state decoding lives inside the stubs (and, for ccu_fsm, in mirrored
// localparams below).
// =============================================================================

// -----------------------------------------------------------------------------
// AXI-Lite read demux  (src/testbenches/axi_lite_demux_read_tb.sv:
//                       axi_lite_read_demux + 1 requesting slave + 4 masters)
// -----------------------------------------------------------------------------
module comm_axi_demux_read_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NoPorts = 4;
  // One read in flight at a time: the selected master takes the AR the cycle
  // after it is presented and returns R two cycles later, so every in-flight
  // participant and every offered message completes within a few cycles.
  // The slave only issues a new AR on power-of-two cycles, which is why the
  // bounds are on open obligations rather than on unconditional progress.
  localparam int unsigned Bound = 32;
  localparam int unsigned AW = $clog2(Bound+1);

  tb_axi_read_demux tb (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Wire-level handshakes and pending offers.
  wire slv_ar_fire = tb.slv_req.ar_valid && tb.slv_resp.ar_ready;
  wire slv_r_fire  = tb.slv_resp.r_valid && tb.slv_req.r_ready;
  wire slv_ar_wait = tb.slv_req.ar_valid && !tb.slv_resp.ar_ready;
  wire slv_r_wait  = tb.slv_resp.r_valid && !tb.slv_req.r_ready;
  wire [NoPorts-1:0] mst_ar_fire, mst_r_fire, mst_ar_wait, mst_r_wait;

  // Participant self-reports.
  wire slv_ar_snd = tb.slave.f_ar_snd;
  wire slv_r_rcv  = tb.slave.f_r_rcv;
  wire slv_busy   = tb.slave.f_busy;
  wire [NoPorts-1:0] mst_ar_rcv, mst_r_snd, mst_busy;
  for (genvar i = 0; i < NoPorts; i++) begin : gen_ports
    assign mst_ar_fire[i] = tb.mst_reqs[i].ar_valid && tb.mst_resps[i].ar_ready;
    assign mst_r_fire[i]  = tb.mst_resps[i].r_valid && tb.mst_reqs[i].r_ready;
    assign mst_ar_wait[i] = tb.mst_reqs[i].ar_valid && !tb.mst_resps[i].ar_ready;
    assign mst_r_wait[i]  = tb.mst_resps[i].r_valid && !tb.mst_reqs[i].r_ready;
    assign mst_ar_rcv[i]  = tb.gen_masters[i].master.f_ar_rcv;
    assign mst_r_snd[i]   = tb.gen_masters[i].master.f_r_snd;
    assign mst_busy[i]    = tb.gen_masters[i].master.f_busy;
  end

  // DUT's own view: a forwarded AR is recorded in the select FIFO and retired
  // when the matching R has been delivered.
  wire dut_ar_accept   = tb.dut.r_fifo_push;
  wire dut_r_deliver   = tb.dut.r_fifo_pop;
  wire dut_outstanding = !tb.dut.r_fifo_empty;

  logic [AW-1:0] slv_age, dut_age, slv_ar_age, slv_r_age;
  logic [AW-1:0] mst_age    [NoPorts-1:0];
  logic [AW-1:0] mst_ar_age [NoPorts-1:0];
  logic [AW-1:0] mst_r_age  [NoPorts-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      slv_age <= '0;
      dut_age <= '0;
      slv_ar_age <= '0;
      slv_r_age <= '0;
      for (int i = 0; i < NoPorts; i++) begin
        mst_age[i] <= '0;
        mst_ar_age[i] <= '0;
        mst_r_age[i] <= '0;
      end
    end else begin
      // ---- S: the slave stub and the wire agree on every exchange ----
      assert(slv_ar_snd == slv_ar_fire);
      assert(slv_r_rcv == slv_r_fire);

      // ---- S: the demux takes an AR exactly when it hands it to exactly one
      //         master, and its own bookkeeping records exactly that ----
      assert(dut_ar_accept == slv_ar_fire);
      assert((|mst_ar_fire) == slv_ar_fire);
      assert((mst_ar_fire & (mst_ar_fire - 1'b1)) == '0);

      // ---- S: the demux delivers an R exactly when it takes one from exactly
      //         one master, and retires the matching record ----
      assert(dut_r_deliver == slv_r_fire);
      assert((|mst_r_fire) == slv_r_fire);
      assert((mst_r_fire & (mst_r_fire - 1'b1)) == '0);

      for (int i = 0; i < NoPorts; i++) begin
        // ---- S: master stub i and the wire agree on every exchange (the stub
        //         commits on ar_valid alone, so a presented-but-unaccepted AR
        //         would be a dropped exchange) ----
        assert(mst_ar_rcv[i] == mst_ar_fire[i]);
        assert(mst_r_snd[i] == mst_r_fire[i]);

        // ---- L: an in-flight master returns to idle within Bound ----
        if (mst_busy[i]) begin
          mst_age[i] <= mst_age[i] + 1'b1;
          assert(mst_age[i] < Bound);
        end else begin
          mst_age[i] <= '0;
        end
        // ---- L: messages offered to / by master i are accepted within Bound ----
        if (mst_ar_wait[i]) begin
          mst_ar_age[i] <= mst_ar_age[i] + 1'b1;
          assert(mst_ar_age[i] < Bound);
        end else begin
          mst_ar_age[i] <= '0;
        end
        if (mst_r_wait[i]) begin
          mst_r_age[i] <= mst_r_age[i] + 1'b1;
          assert(mst_r_age[i] < Bound);
        end else begin
          mst_r_age[i] <= '0;
        end
      end

      // ---- L: an in-flight slave transaction completes within Bound ----
      if (slv_busy) begin
        slv_age <= slv_age + 1'b1;
        assert(slv_age < Bound);
      end else begin
        slv_age <= '0;
      end
      // ---- L: the demux drains its outstanding reads within Bound ----
      if (dut_outstanding) begin
        dut_age <= dut_age + 1'b1;
        assert(dut_age < Bound);
      end else begin
        dut_age <= '0;
      end
      // ---- L: messages offered on the slave port are accepted within Bound ----
      if (slv_ar_wait) begin
        slv_ar_age <= slv_ar_age + 1'b1;
        assert(slv_ar_age < Bound);
      end else begin
        slv_ar_age <= '0;
      end
      if (slv_r_wait) begin
        slv_r_age <= slv_r_age + 1'b1;
        assert(slv_r_age < Bound);
      end else begin
        slv_r_age <= '0;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// AXI-Lite write demux  (src/testbenches/axi_lite_demux_write_tb.sv:
//                        axi_lite_write_demux + 1 requesting slave + 4 masters)
// -----------------------------------------------------------------------------
module comm_axi_demux_write_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NoPorts = 4;
  // One write in flight at a time (AW, then W, then B, each answered by the
  // selected master within two cycles), so every open obligation closes
  // within a few cycles.
  localparam int unsigned Bound = 32;
  localparam int unsigned AW = $clog2(Bound+1);

  tb_axi_write_demux tb (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Wire-level handshakes and pending offers.
  wire slv_aw_fire = tb.slv_req.aw_valid && tb.slv_resp.aw_ready;
  wire slv_w_fire  = tb.slv_req.w_valid && tb.slv_resp.w_ready;
  wire slv_b_fire  = tb.slv_resp.b_valid && tb.slv_req.b_ready;
  wire slv_aw_wait = tb.slv_req.aw_valid && !tb.slv_resp.aw_ready;
  wire slv_w_wait  = tb.slv_req.w_valid && !tb.slv_resp.w_ready;
  wire slv_b_wait  = tb.slv_resp.b_valid && !tb.slv_req.b_ready;
  wire [NoPorts-1:0] mst_aw_fire, mst_w_fire, mst_b_fire;
  wire [NoPorts-1:0] mst_aw_wait, mst_w_wait, mst_b_wait;

  // Participant self-reports.
  wire slv_aw_snd = tb.slave.f_aw_snd;
  wire slv_w_snd  = tb.slave.f_w_snd;
  wire slv_b_rcv  = tb.slave.f_b_rcv;
  wire slv_busy   = tb.slave.f_busy;
  wire [NoPorts-1:0] mst_aw_rcv, mst_w_rcv, mst_b_snd, mst_busy;
  for (genvar i = 0; i < NoPorts; i++) begin : gen_ports
    assign mst_aw_fire[i] = tb.mst_reqs[i].aw_valid && tb.mst_resps[i].aw_ready;
    assign mst_w_fire[i]  = tb.mst_reqs[i].w_valid && tb.mst_resps[i].w_ready;
    assign mst_b_fire[i]  = tb.mst_resps[i].b_valid && tb.mst_reqs[i].b_ready;
    assign mst_aw_wait[i] = tb.mst_reqs[i].aw_valid && !tb.mst_resps[i].aw_ready;
    assign mst_w_wait[i]  = tb.mst_reqs[i].w_valid && !tb.mst_resps[i].w_ready;
    assign mst_b_wait[i]  = tb.mst_resps[i].b_valid && !tb.mst_reqs[i].b_ready;
    assign mst_aw_rcv[i]  = tb.gen_masters[i].master.f_aw_rcv;
    assign mst_w_rcv[i]   = tb.gen_masters[i].master.f_w_rcv;
    assign mst_b_snd[i]   = tb.gen_masters[i].master.f_b_snd;
    assign mst_busy[i]    = tb.gen_masters[i].master.f_busy;
  end

  // DUT's own view. The demux records the AW target when it first presents
  // the AW (and locks onto that master until the AW is taken), moves the
  // record from the W FIFO to the B FIFO when the W beat is handed over, and
  // retires it when the B response has been delivered.
  wire dut_w_deliver   = tb.dut.w_fifo_pop;
  wire dut_b_deliver   = tb.dut.b_fifo_pop;
  wire dut_outstanding = !tb.dut.w_fifo_empty || !tb.dut.b_fifo_empty || tb.dut.lock_aw_valid_q;

  logic [AW-1:0] slv_age, dut_age, slv_aw_age, slv_w_age, slv_b_age;
  logic [AW-1:0] mst_age    [NoPorts-1:0];
  logic [AW-1:0] mst_aw_age [NoPorts-1:0];
  logic [AW-1:0] mst_w_age  [NoPorts-1:0];
  logic [AW-1:0] mst_b_age  [NoPorts-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      slv_age <= '0;
      dut_age <= '0;
      slv_aw_age <= '0;
      slv_w_age <= '0;
      slv_b_age <= '0;
      for (int i = 0; i < NoPorts; i++) begin
        mst_age[i] <= '0;
        mst_aw_age[i] <= '0;
        mst_w_age[i] <= '0;
        mst_b_age[i] <= '0;
      end
    end else begin
      // ---- S: the slave stub and the wire agree on every exchange ----
      assert(slv_aw_snd == slv_aw_fire);
      assert(slv_w_snd == slv_w_fire);
      assert(slv_b_rcv == slv_b_fire);

      // ---- S: each message taken on the slave port is handed to exactly one
      //         master in the same cycle, and vice versa ----
      assert((|mst_aw_fire) == slv_aw_fire);
      assert((mst_aw_fire & (mst_aw_fire - 1'b1)) == '0);
      assert((|mst_w_fire) == slv_w_fire);
      assert((mst_w_fire & (mst_w_fire - 1'b1)) == '0);
      assert((|mst_b_fire) == slv_b_fire);
      assert((mst_b_fire & (mst_b_fire - 1'b1)) == '0);

      // ---- S: the demux's own bookkeeping moves exactly with the W and B exchanges ----
      assert(dut_w_deliver == slv_w_fire);
      assert(dut_b_deliver == slv_b_fire);

      for (int i = 0; i < NoPorts; i++) begin
        // ---- S: master stub i and the wire agree on every exchange (the stub
        //         commits on aw_valid alone) ----
        assert(mst_aw_rcv[i] == mst_aw_fire[i]);
        assert(mst_w_rcv[i] == mst_w_fire[i]);
        assert(mst_b_snd[i] == mst_b_fire[i]);

        // ---- L: an in-flight master returns to idle within Bound ----
        if (mst_busy[i]) begin
          mst_age[i] <= mst_age[i] + 1'b1;
          assert(mst_age[i] < Bound);
        end else begin
          mst_age[i] <= '0;
        end
        // ---- L: messages offered to / by master i are accepted within Bound ----
        if (mst_aw_wait[i]) begin
          mst_aw_age[i] <= mst_aw_age[i] + 1'b1;
          assert(mst_aw_age[i] < Bound);
        end else begin
          mst_aw_age[i] <= '0;
        end
        if (mst_w_wait[i]) begin
          mst_w_age[i] <= mst_w_age[i] + 1'b1;
          assert(mst_w_age[i] < Bound);
        end else begin
          mst_w_age[i] <= '0;
        end
        if (mst_b_wait[i]) begin
          mst_b_age[i] <= mst_b_age[i] + 1'b1;
          assert(mst_b_age[i] < Bound);
        end else begin
          mst_b_age[i] <= '0;
        end
      end

      // ---- L: an in-flight slave transaction completes within Bound ----
      if (slv_busy) begin
        slv_age <= slv_age + 1'b1;
        assert(slv_age < Bound);
      end else begin
        slv_age <= '0;
      end
      // ---- L: the demux drains its outstanding writes within Bound ----
      if (dut_outstanding) begin
        dut_age <= dut_age + 1'b1;
        assert(dut_age < Bound);
      end else begin
        dut_age <= '0;
      end
      // ---- L: messages offered on the slave port are accepted within Bound ----
      if (slv_aw_wait) begin
        slv_aw_age <= slv_aw_age + 1'b1;
        assert(slv_aw_age < Bound);
      end else begin
        slv_aw_age <= '0;
      end
      if (slv_w_wait) begin
        slv_w_age <= slv_w_age + 1'b1;
        assert(slv_w_age < Bound);
      end else begin
        slv_w_age <= '0;
      end
      if (slv_b_wait) begin
        slv_b_age <= slv_b_age + 1'b1;
        assert(slv_b_age < Bound);
      end else begin
        slv_b_age <= '0;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// AXI-Lite read mux  (src/testbenches/axi_lite_mux_read_tb.sv:
//                     axi_lite_read_mux + 4 requesting slaves + 1 master)
// -----------------------------------------------------------------------------
module comm_axi_mux_read_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NoPorts = 4;
  // All four slaves issue an AR on the same (power-of-two) cycle; the master
  // serves one read at a time in about three cycles, so the last slave in
  // the round-robin order is answered within roughly four reads.
  localparam int unsigned Bound = 48;
  localparam int unsigned AW = $clog2(Bound+1);

  tb_axi_read_mux tb (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Wire-level handshakes and pending offers.
  wire mst_ar_fire = tb.mst_req.ar_valid && tb.mst_resp.ar_ready;
  wire mst_r_fire  = tb.mst_resp.r_valid && tb.mst_req.r_ready;
  wire mst_ar_wait = tb.mst_req.ar_valid && !tb.mst_resp.ar_ready;
  wire mst_r_wait  = tb.mst_resp.r_valid && !tb.mst_req.r_ready;
  wire [NoPorts-1:0] slv_ar_fire, slv_r_fire, slv_ar_wait, slv_r_wait;

  // Participant self-reports.
  wire mst_ar_rcv = tb.master.f_ar_rcv;
  wire mst_r_snd  = tb.master.f_r_snd;
  wire mst_busy   = tb.master.f_busy;
  wire [NoPorts-1:0] slv_ar_snd, slv_r_rcv, slv_busy;
  for (genvar i = 0; i < NoPorts; i++) begin : gen_ports
    assign slv_ar_fire[i] = tb.slv_reqs[i].ar_valid && tb.slv_resps[i].ar_ready;
    assign slv_r_fire[i]  = tb.slv_resps[i].r_valid && tb.slv_reqs[i].r_ready;
    assign slv_ar_wait[i] = tb.slv_reqs[i].ar_valid && !tb.slv_resps[i].ar_ready;
    assign slv_r_wait[i]  = tb.slv_resps[i].r_valid && !tb.slv_reqs[i].r_ready;
    assign slv_ar_snd[i]  = tb.gen_slaves[i].slave.f_ar_snd;
    assign slv_r_rcv[i]   = tb.gen_slaves[i].slave.f_r_rcv;
    assign slv_busy[i]    = tb.gen_slaves[i].slave.f_busy;
  end

  // DUT's own view: the arbitrated AR is recorded in the select FIFO when
  // the master takes it, and retired when the matching R has been returned.
  wire dut_ar_accept   = tb.dut.r_fifo_push;
  wire dut_r_deliver   = tb.dut.r_fifo_pop;
  wire dut_outstanding = !tb.dut.r_fifo_empty;

  logic [AW-1:0] mst_age, dut_age, mst_ar_age, mst_r_age;
  logic [AW-1:0] slv_age    [NoPorts-1:0];
  logic [AW-1:0] slv_ar_age [NoPorts-1:0];
  logic [AW-1:0] slv_r_age  [NoPorts-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_age <= '0;
      dut_age <= '0;
      mst_ar_age <= '0;
      mst_r_age <= '0;
      for (int i = 0; i < NoPorts; i++) begin
        slv_age[i] <= '0;
        slv_ar_age[i] <= '0;
        slv_r_age[i] <= '0;
      end
    end else begin
      // ---- S: the master stub and the wire agree on every exchange ----
      assert(mst_ar_rcv == mst_ar_fire);
      assert(mst_r_snd == mst_r_fire);

      // ---- S: the mux hands an AR to the master exactly when it takes one
      //         from exactly one slave, and records exactly that ----
      assert(dut_ar_accept == mst_ar_fire);
      assert((|slv_ar_fire) == mst_ar_fire);
      assert((slv_ar_fire & (slv_ar_fire - 1'b1)) == '0);

      // ---- S: the mux takes an R from the master exactly when it delivers
      //         it to exactly one slave, and retires the matching record ----
      assert(dut_r_deliver == mst_r_fire);
      assert((|slv_r_fire) == mst_r_fire);
      assert((slv_r_fire & (slv_r_fire - 1'b1)) == '0);

      for (int i = 0; i < NoPorts; i++) begin
        // ---- S: slave stub i and the wire agree on every exchange ----
        assert(slv_ar_snd[i] == slv_ar_fire[i]);
        assert(slv_r_rcv[i] == slv_r_fire[i]);

        // ---- L: an in-flight slave transaction completes within Bound ----
        if (slv_busy[i]) begin
          slv_age[i] <= slv_age[i] + 1'b1;
          assert(slv_age[i] < Bound);
        end else begin
          slv_age[i] <= '0;
        end
        // ---- L: messages offered by / to slave i are accepted within Bound ----
        if (slv_ar_wait[i]) begin
          slv_ar_age[i] <= slv_ar_age[i] + 1'b1;
          assert(slv_ar_age[i] < Bound);
        end else begin
          slv_ar_age[i] <= '0;
        end
        if (slv_r_wait[i]) begin
          slv_r_age[i] <= slv_r_age[i] + 1'b1;
          assert(slv_r_age[i] < Bound);
        end else begin
          slv_r_age[i] <= '0;
        end
      end

      // ---- L: an in-flight master returns to idle within Bound ----
      if (mst_busy) begin
        mst_age <= mst_age + 1'b1;
        assert(mst_age < Bound);
      end else begin
        mst_age <= '0;
      end
      // ---- L: the mux drains its outstanding reads within Bound ----
      if (dut_outstanding) begin
        dut_age <= dut_age + 1'b1;
        assert(dut_age < Bound);
      end else begin
        dut_age <= '0;
      end
      // ---- L: messages offered on the master port are accepted within Bound ----
      if (mst_ar_wait) begin
        mst_ar_age <= mst_ar_age + 1'b1;
        assert(mst_ar_age < Bound);
      end else begin
        mst_ar_age <= '0;
      end
      if (mst_r_wait) begin
        mst_r_age <= mst_r_age + 1'b1;
        assert(mst_r_age < Bound);
      end else begin
        mst_r_age <= '0;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// AXI-Lite write mux  (src/testbenches/axi_lite_mux_write_tb.sv:
//                      axi_lite_write_mux + 4 requesting slaves + 1 master)
// -----------------------------------------------------------------------------
module comm_axi_mux_write_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NoPorts = 4;
  // All four slaves issue an AW on the same (power-of-two) cycle; the master
  // serves one write (AW, W, B) at a time in about five cycles, so the last
  // slave in the round-robin order is answered within roughly four writes.
  localparam int unsigned Bound = 64;
  localparam int unsigned AW = $clog2(Bound+1);

  tb_axi_write_mux tb (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Wire-level handshakes and pending offers.
  wire mst_aw_fire = tb.mst_req.aw_valid && tb.mst_resp.aw_ready;
  wire mst_w_fire  = tb.mst_req.w_valid && tb.mst_resp.w_ready;
  wire mst_b_fire  = tb.mst_resp.b_valid && tb.mst_req.b_ready;
  wire mst_aw_wait = tb.mst_req.aw_valid && !tb.mst_resp.aw_ready;
  wire mst_w_wait  = tb.mst_req.w_valid && !tb.mst_resp.w_ready;
  wire mst_b_wait  = tb.mst_resp.b_valid && !tb.mst_req.b_ready;
  wire [NoPorts-1:0] slv_aw_fire, slv_w_fire, slv_b_fire;
  wire [NoPorts-1:0] slv_aw_wait, slv_w_wait, slv_b_wait;

  // Participant self-reports.
  wire mst_aw_rcv = tb.master.f_aw_rcv;
  wire mst_w_rcv  = tb.master.f_w_rcv;
  wire mst_b_snd  = tb.master.f_b_snd;
  wire mst_busy   = tb.master.f_busy;
  wire [NoPorts-1:0] slv_aw_snd, slv_w_snd, slv_b_rcv, slv_busy;
  for (genvar i = 0; i < NoPorts; i++) begin : gen_ports
    assign slv_aw_fire[i] = tb.slv_reqs[i].aw_valid && tb.slv_resps[i].aw_ready;
    assign slv_w_fire[i]  = tb.slv_reqs[i].w_valid && tb.slv_resps[i].w_ready;
    assign slv_b_fire[i]  = tb.slv_resps[i].b_valid && tb.slv_reqs[i].b_ready;
    assign slv_aw_wait[i] = tb.slv_reqs[i].aw_valid && !tb.slv_resps[i].aw_ready;
    assign slv_w_wait[i]  = tb.slv_reqs[i].w_valid && !tb.slv_resps[i].w_ready;
    assign slv_b_wait[i]  = tb.slv_resps[i].b_valid && !tb.slv_reqs[i].b_ready;
    assign slv_aw_snd[i]  = tb.gen_slaves[i].slave.f_aw_snd;
    assign slv_w_snd[i]   = tb.gen_slaves[i].slave.f_w_snd;
    assign slv_b_rcv[i]   = tb.gen_slaves[i].slave.f_b_rcv;
    assign slv_busy[i]    = tb.gen_slaves[i].slave.f_busy;
  end

  // DUT's own view. The mux records the arbitrated AW source when it first
  // presents the AW to the master (locking onto it until taken), moves the
  // record from the W FIFO to the B FIFO when the W beat is handed over, and
  // retires it when the B response has been returned to the slave.
  wire dut_w_deliver   = tb.dut.w_fifo_pop;
  wire dut_b_deliver   = tb.dut.b_fifo_pop;
  wire dut_outstanding = !tb.dut.w_fifo_empty || !tb.dut.b_fifo_empty || tb.dut.lock_aw_valid_q;

  logic [AW-1:0] mst_age, dut_age, mst_aw_age, mst_w_age, mst_b_age;
  logic [AW-1:0] slv_age    [NoPorts-1:0];
  logic [AW-1:0] slv_aw_age [NoPorts-1:0];
  logic [AW-1:0] slv_w_age  [NoPorts-1:0];
  logic [AW-1:0] slv_b_age  [NoPorts-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mst_age <= '0;
      dut_age <= '0;
      mst_aw_age <= '0;
      mst_w_age <= '0;
      mst_b_age <= '0;
      for (int i = 0; i < NoPorts; i++) begin
        slv_age[i] <= '0;
        slv_aw_age[i] <= '0;
        slv_w_age[i] <= '0;
        slv_b_age[i] <= '0;
      end
    end else begin
      // ---- S: the master stub and the wire agree on every exchange ----
      assert(mst_aw_rcv == mst_aw_fire);
      assert(mst_w_rcv == mst_w_fire);
      assert(mst_b_snd == mst_b_fire);

      // ---- S: each message handed to the master is taken from exactly one
      //         slave in the same cycle, and vice versa ----
      assert((|slv_aw_fire) == mst_aw_fire);
      assert((slv_aw_fire & (slv_aw_fire - 1'b1)) == '0);
      assert((|slv_w_fire) == mst_w_fire);
      assert((slv_w_fire & (slv_w_fire - 1'b1)) == '0);
      assert((|slv_b_fire) == mst_b_fire);
      assert((slv_b_fire & (slv_b_fire - 1'b1)) == '0);

      // ---- S: the mux's own bookkeeping moves exactly with the W and B exchanges ----
      assert(dut_w_deliver == mst_w_fire);
      assert(dut_b_deliver == mst_b_fire);

      for (int i = 0; i < NoPorts; i++) begin
        // ---- S: slave stub i and the wire agree on every exchange ----
        assert(slv_aw_snd[i] == slv_aw_fire[i]);
        assert(slv_w_snd[i] == slv_w_fire[i]);
        assert(slv_b_rcv[i] == slv_b_fire[i]);

        // ---- L: an in-flight slave transaction completes within Bound ----
        if (slv_busy[i]) begin
          slv_age[i] <= slv_age[i] + 1'b1;
          assert(slv_age[i] < Bound);
        end else begin
          slv_age[i] <= '0;
        end
        // ---- L: messages offered by / to slave i are accepted within Bound ----
        if (slv_aw_wait[i]) begin
          slv_aw_age[i] <= slv_aw_age[i] + 1'b1;
          assert(slv_aw_age[i] < Bound);
        end else begin
          slv_aw_age[i] <= '0;
        end
        if (slv_w_wait[i]) begin
          slv_w_age[i] <= slv_w_age[i] + 1'b1;
          assert(slv_w_age[i] < Bound);
        end else begin
          slv_w_age[i] <= '0;
        end
        if (slv_b_wait[i]) begin
          slv_b_age[i] <= slv_b_age[i] + 1'b1;
          assert(slv_b_age[i] < Bound);
        end else begin
          slv_b_age[i] <= '0;
        end
      end

      // ---- L: an in-flight master returns to idle within Bound ----
      if (mst_busy) begin
        mst_age <= mst_age + 1'b1;
        assert(mst_age < Bound);
      end else begin
        mst_age <= '0;
      end
      // ---- L: the mux drains its outstanding writes within Bound ----
      if (dut_outstanding) begin
        dut_age <= dut_age + 1'b1;
        assert(dut_age < Bound);
      end else begin
        dut_age <= '0;
      end
      // ---- L: messages offered on the master port are accepted within Bound ----
      if (mst_aw_wait) begin
        mst_aw_age <= mst_aw_age + 1'b1;
        assert(mst_aw_age < Bound);
      end else begin
        mst_aw_age <= '0;
      end
      if (mst_w_wait) begin
        mst_w_age <= mst_w_age + 1'b1;
        assert(mst_w_age < Bound);
      end else begin
        mst_w_age <= '0;
      end
      if (mst_b_wait) begin
        mst_b_age <= mst_b_age + 1'b1;
        assert(mst_b_age < Bound);
      end else begin
        mst_b_age <= '0;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// ACE cache-coherency controller  (src/testbenches/ccu_fsm_tb.sv:
//     ccu_fsm + 4 cache clients (request FSM + snoop FSM each)
//     + testbench arbiter + memory controller)
// -----------------------------------------------------------------------------
module comm_ace_formal(input logic clk_i, input logic rst_ni);
  localparam int unsigned NoPorts = 4;

  // ccu_fsm state encoding (ace/src/ccu_fsm.sv: anonymous enum, values in
  // declaration order). yosys-slang cannot follow hierarchical references to
  // enum members, so the values are mirrored here.
  localparam logic [5:0] CCU_IDLE                      = 6'd0;
  localparam logic [5:0] CCU_DECODE_R                  = 6'd1;
  localparam logic [5:0] CCU_WAIT_INVALID_R            = 6'd3;
  localparam logic [5:0] CCU_READ_SNP_DATA             = 6'd8;
  localparam logic [5:0] CCU_READ_MEM                  = 6'd10;
  localparam logic [5:0] CCU_DECODE_W                  = 6'd11;
  localparam logic [5:0] CCU_WRITE_MEM                 = 6'd17;

  // All four clients issue on the same cycles and are serialised by the
  // testbench arbiter. One coherent transaction (snoop every client, optional
  // write-back, memory access) takes a few tens of cycles, so the last client
  // in line finishes within about four transactions. A single snoop exchange
  // or memory access is answered within a few cycles.
  localparam int unsigned TxnBound   = 160;
  localparam int unsigned SnoopBound = 32;
  localparam int unsigned MemBound   = 32;
  localparam int unsigned ChanBound  = 32;
  localparam int unsigned TW = $clog2(TxnBound+1);
  localparam int unsigned SW = $clog2(SnoopBound+1);
  localparam int unsigned MW = $clog2(MemBound+1);
  localparam int unsigned CW = $clog2(ChanBound+1);

  ccu_fsm_tb tb (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // ---- Wire-level handshakes ------------------------------------------------
  // client <-> arbiter (per client)
  wire [NoPorts-1:0] c_ar_fire, c_r_fire, c_aw_fire, c_w_fire, c_b_fire;
  wire [NoPorts-1:0] c_ar_wait, c_r_wait, c_aw_wait, c_w_wait, c_b_wait;
  // arbiter <-> CCU
  wire a_ar_fire = tb.ccu_req_from_arb.ar_valid && tb.ccu_resp_to_arb.ar_ready;
  wire a_r_fire  = tb.ccu_resp_to_arb.r_valid && tb.ccu_req_from_arb.r_ready;
  wire a_r_last  = a_r_fire && tb.ccu_resp_to_arb.r.last;
  wire a_aw_fire = tb.ccu_req_from_arb.aw_valid && tb.ccu_resp_to_arb.aw_ready;
  wire a_w_fire  = tb.ccu_req_from_arb.w_valid && tb.ccu_resp_to_arb.w_ready;
  wire a_b_fire  = tb.ccu_resp_to_arb.b_valid && tb.ccu_req_from_arb.b_ready;
  wire a_ar_wait = tb.ccu_req_from_arb.ar_valid && !tb.ccu_resp_to_arb.ar_ready;
  wire a_r_wait  = tb.ccu_resp_to_arb.r_valid && !tb.ccu_req_from_arb.r_ready;
  wire a_aw_wait = tb.ccu_req_from_arb.aw_valid && !tb.ccu_resp_to_arb.aw_ready;
  wire a_w_wait  = tb.ccu_req_from_arb.w_valid && !tb.ccu_resp_to_arb.w_ready;
  wire a_b_wait  = tb.ccu_resp_to_arb.b_valid && !tb.ccu_req_from_arb.b_ready;
  // CCU <-> memory
  wire m_ar_fire = tb.ccu_req_to_mem.ar_valid && tb.ccu_resp_from_mem.ar_ready;
  wire m_r_fire  = tb.ccu_resp_from_mem.r_valid && tb.ccu_req_to_mem.r_ready;
  wire m_aw_fire = tb.ccu_req_to_mem.aw_valid && tb.ccu_resp_from_mem.aw_ready;
  wire m_w_fire  = tb.ccu_req_to_mem.w_valid && tb.ccu_resp_from_mem.w_ready;
  wire m_b_fire  = tb.ccu_resp_from_mem.b_valid && tb.ccu_req_to_mem.b_ready;
  wire m_ar_wait = tb.ccu_req_to_mem.ar_valid && !tb.ccu_resp_from_mem.ar_ready;
  wire m_r_wait  = tb.ccu_resp_from_mem.r_valid && !tb.ccu_req_to_mem.r_ready;
  wire m_aw_wait = tb.ccu_req_to_mem.aw_valid && !tb.ccu_resp_from_mem.aw_ready;
  wire m_w_wait  = tb.ccu_req_to_mem.w_valid && !tb.ccu_resp_from_mem.w_ready;
  wire m_b_wait  = tb.ccu_resp_from_mem.b_valid && !tb.ccu_req_to_mem.b_ready;
  // CCU <-> client snoop port (per client)
  wire [NoPorts-1:0] s_ac_fire, s_cr_fire, s_cd_fire;
  wire [NoPorts-1:0] s_ac_wait, s_cr_wait, s_cd_wait;

  // ---- Participant self-reports ----------------------------------------------
  wire [NoPorts-1:0] c_ar_snd, c_r_rcv, c_aw_snd, c_w_snd, c_b_rcv, c_req_busy;
  wire [NoPorts-1:0] c_ac_rcv, c_cr_snd, c_cd_snd, c_snp_busy;
  for (genvar i = 0; i < NoPorts; i++) begin : gen_ports
    assign c_ar_fire[i] = tb.slave_req[i].ar_valid && tb.slave_resp[i].ar_ready;
    assign c_r_fire[i]  = tb.slave_resp[i].r_valid && tb.slave_req[i].r_ready;
    assign c_aw_fire[i] = tb.slave_req[i].aw_valid && tb.slave_resp[i].aw_ready;
    assign c_w_fire[i]  = tb.slave_req[i].w_valid && tb.slave_resp[i].w_ready;
    assign c_b_fire[i]  = tb.slave_resp[i].b_valid && tb.slave_req[i].b_ready;
    assign c_ar_wait[i] = tb.slave_req[i].ar_valid && !tb.slave_resp[i].ar_ready;
    assign c_r_wait[i]  = tb.slave_resp[i].r_valid && !tb.slave_req[i].r_ready;
    assign c_aw_wait[i] = tb.slave_req[i].aw_valid && !tb.slave_resp[i].aw_ready;
    assign c_w_wait[i]  = tb.slave_req[i].w_valid && !tb.slave_resp[i].w_ready;
    assign c_b_wait[i]  = tb.slave_resp[i].b_valid && !tb.slave_req[i].b_ready;
    assign s_ac_fire[i] = tb.snoop_req_to_slaves[i].ac_valid && tb.snoop_resp_from_slaves[i].ac_ready;
    assign s_cr_fire[i] = tb.snoop_resp_from_slaves[i].cr_valid && tb.snoop_req_to_slaves[i].cr_ready;
    assign s_cd_fire[i] = tb.snoop_resp_from_slaves[i].cd_valid && tb.snoop_req_to_slaves[i].cd_ready;
    assign s_ac_wait[i] = tb.snoop_req_to_slaves[i].ac_valid && !tb.snoop_resp_from_slaves[i].ac_ready;
    assign s_cr_wait[i] = tb.snoop_resp_from_slaves[i].cr_valid && !tb.snoop_req_to_slaves[i].cr_ready;
    assign s_cd_wait[i] = tb.snoop_resp_from_slaves[i].cd_valid && !tb.snoop_req_to_slaves[i].cd_ready;
    assign c_ar_snd[i]   = tb.gen_slaves[i].i_ace_slave.f_ar_snd;
    assign c_r_rcv[i]    = tb.gen_slaves[i].i_ace_slave.f_r_rcv;
    assign c_aw_snd[i]   = tb.gen_slaves[i].i_ace_slave.f_aw_snd;
    assign c_w_snd[i]    = tb.gen_slaves[i].i_ace_slave.f_w_snd;
    assign c_b_rcv[i]    = tb.gen_slaves[i].i_ace_slave.f_b_rcv;
    assign c_req_busy[i] = tb.gen_slaves[i].i_ace_slave.f_req_busy;
    assign c_ac_rcv[i]   = tb.gen_slaves[i].i_ace_slave.f_ac_rcv;
    assign c_cr_snd[i]   = tb.gen_slaves[i].i_ace_slave.f_cr_snd;
    assign c_cd_snd[i]   = tb.gen_slaves[i].i_ace_slave.f_cd_snd;
    assign c_snp_busy[i] = tb.gen_slaves[i].i_ace_slave.f_snp_busy;
  end
  wire       arb_busy  = tb.i_arbiter.f_busy;
  wire       arb_read  = tb.i_arbiter.f_read;
  wire       arb_write = tb.i_arbiter.f_write;
  wire [1:0] arb_sel   = tb.i_arbiter.f_sel;
  wire mem_ar_rcv = tb.i_mem_controller.f_ar_rcv;
  wire mem_aw_rcv = tb.i_mem_controller.f_aw_rcv;
  wire mem_r_snd  = tb.i_mem_controller.f_r_snd;
  wire mem_w_rcv  = tb.i_mem_controller.f_w_rcv;
  wire mem_b_snd  = tb.i_mem_controller.f_b_snd;
  wire mem_busy   = tb.i_mem_controller.f_busy;
  wire [5:0] ccu_state = tb.i_ccu_fsm.state_q;
  wire ccu_busy = (ccu_state != CCU_IDLE);

  // ---- CCU boundary transaction accounting -----------------------------------
  // The request the CCU accepted must be answered exactly once (one R beat
  // with last for a read, one B for a write) before the CCU returns to IDLE.
  logic       ccu_prev_busy;
  logic       txn_is_read;
  logic [1:0] resp_cnt;
  wire        resp_inc = txn_is_read ? a_r_last : a_b_fire;

  logic [TW-1:0] c_req_age [NoPorts-1:0];
  logic [SW-1:0] c_snp_age [NoPorts-1:0];
  logic [TW-1:0] c_ar_age  [NoPorts-1:0];
  logic [TW-1:0] c_aw_age  [NoPorts-1:0];
  logic [TW-1:0] c_w_age   [NoPorts-1:0];
  logic [CW-1:0] c_r_age   [NoPorts-1:0];
  logic [CW-1:0] c_b_age   [NoPorts-1:0];
  logic [SW-1:0] s_ac_age  [NoPorts-1:0];
  logic [SW-1:0] s_cr_age  [NoPorts-1:0];
  logic [SW-1:0] s_cd_age  [NoPorts-1:0];
  logic [TW-1:0] arb_age, ccu_age, a_w_age;
  logic [MW-1:0] mem_age;
  logic [CW-1:0] a_ar_age, a_aw_age, a_r_age, a_b_age;
  logic [CW-1:0] m_ar_age, m_aw_age, m_w_age, m_r_age, m_b_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ccu_prev_busy <= 1'b0;
      txn_is_read <= 1'b0;
      resp_cnt <= '0;
      for (int i = 0; i < NoPorts; i++) begin
        c_req_age[i] <= '0;
        c_snp_age[i] <= '0;
        c_ar_age[i] <= '0;
        c_aw_age[i] <= '0;
        c_w_age[i] <= '0;
        c_r_age[i] <= '0;
        c_b_age[i] <= '0;
        s_ac_age[i] <= '0;
        s_cr_age[i] <= '0;
        s_cd_age[i] <= '0;
      end
      arb_age <= '0;
      ccu_age <= '0;
      a_w_age <= '0;
      mem_age <= '0;
      a_ar_age <= '0;
      a_aw_age <= '0;
      a_r_age <= '0;
      a_b_age <= '0;
      m_ar_age <= '0;
      m_aw_age <= '0;
      m_w_age <= '0;
      m_r_age <= '0;
      m_b_age <= '0;
    end else begin
      // ---- S: the arbiter relays exactly the selected client's handshakes ----
      assert(a_ar_fire == (|c_ar_fire));
      assert(a_r_fire == (|c_r_fire));
      assert(a_aw_fire == (|c_aw_fire));
      assert(a_w_fire == (|c_w_fire));
      assert(a_b_fire == (|c_b_fire));

      // ---- S: the CCU accepts a request exactly in its decode state, i.e. the
      //         request it latched on entry is the one that is handshaken ----
      assert(a_ar_fire == (ccu_state == CCU_DECODE_R));
      assert(a_aw_fire == (ccu_state == CCU_DECODE_W));

      // ---- S: the CCU passes memory beats straight through in its relay
      //         states and answers the initiator only in its response states ----
      assert(!m_r_fire || ccu_state == CCU_READ_MEM);
      assert(ccu_state != CCU_READ_MEM || (m_r_fire == a_r_fire));
      assert(!a_w_fire || ccu_state == CCU_WRITE_MEM);
      assert(!a_b_fire || ccu_state == CCU_WRITE_MEM);
      assert(ccu_state != CCU_WRITE_MEM || (m_w_fire == a_w_fire));
      assert(ccu_state != CCU_WRITE_MEM || (m_b_fire == a_b_fire));
      assert(!a_r_fire || ccu_state == CCU_WAIT_INVALID_R ||
             ccu_state == CCU_READ_SNP_DATA || ccu_state == CCU_READ_MEM);

      // ---- S: every accepted request is answered exactly once before the
      //         CCU returns to IDLE ----
      if (a_ar_fire || a_aw_fire) begin
        txn_is_read <= a_ar_fire;
        resp_cnt <= '0;
      end else begin
        resp_cnt <= resp_cnt + {1'b0, resp_inc};
        assert(resp_cnt + {1'b0, resp_inc} <= 2'd1);
      end
      if (!ccu_busy && ccu_prev_busy) begin
        assert(resp_cnt == 2'd1);
      end
      ccu_prev_busy <= ccu_busy;

      // ---- S: the memory stub and the wire agree on every exchange (an AW
      //         presented together with an AR would be handshaken but dropped) ----
      assert(mem_ar_rcv == m_ar_fire);
      assert(mem_aw_rcv == m_aw_fire);
      assert(mem_r_snd == m_r_fire);
      assert(mem_w_rcv == m_w_fire);
      assert(mem_b_snd == m_b_fire);

      for (int i = 0; i < NoPorts; i++) begin
        // ---- S: client i's request FSM and the wire agree on every exchange ----
        assert(c_ar_snd[i] == c_ar_fire[i]);
        assert(c_r_rcv[i] == c_r_fire[i]);
        assert(c_aw_snd[i] == c_aw_fire[i]);
        assert(c_w_snd[i] == c_w_fire[i]);
        assert(c_b_rcv[i] == c_b_fire[i]);
        // ---- S: client i's snoop FSM and the wire agree on every exchange (the
        //         FSM samples ac_valid one cycle before it raises ac_ready) ----
        assert(c_ac_rcv[i] == s_ac_fire[i]);
        assert(c_cr_snd[i] == s_cr_fire[i]);
        assert(c_cd_snd[i] == s_cd_fire[i]);
        // ---- S: only the client the arbiter selected exchanges with the CCU ----
        assert(!(c_ar_fire[i] || c_r_fire[i]) || (arb_read && arb_sel == i[1:0]));
        assert(!(c_aw_fire[i] || c_w_fire[i] || c_b_fire[i]) || (arb_write && arb_sel == i[1:0]));

        // ---- L: an in-flight client request completes within TxnBound ----
        if (c_req_busy[i]) begin
          c_req_age[i] <= c_req_age[i] + 1'b1;
          assert(c_req_age[i] < TxnBound);
        end else begin
          c_req_age[i] <= '0;
        end
        // ---- L: an in-flight snoop exchange completes within SnoopBound ----
        if (c_snp_busy[i]) begin
          c_snp_age[i] <= c_snp_age[i] + 1'b1;
          assert(c_snp_age[i] < SnoopBound);
        end else begin
          c_snp_age[i] <= '0;
        end
        // ---- L: a client's offered request/data is taken within TxnBound
        //         (it may have to wait for the arbiter's round) and a response
        //         offered to it is taken within ChanBound ----
        if (c_ar_wait[i]) begin
          c_ar_age[i] <= c_ar_age[i] + 1'b1;
          assert(c_ar_age[i] < TxnBound);
        end else begin
          c_ar_age[i] <= '0;
        end
        if (c_aw_wait[i]) begin
          c_aw_age[i] <= c_aw_age[i] + 1'b1;
          assert(c_aw_age[i] < TxnBound);
        end else begin
          c_aw_age[i] <= '0;
        end
        if (c_w_wait[i]) begin
          c_w_age[i] <= c_w_age[i] + 1'b1;
          assert(c_w_age[i] < TxnBound);
        end else begin
          c_w_age[i] <= '0;
        end
        if (c_r_wait[i]) begin
          c_r_age[i] <= c_r_age[i] + 1'b1;
          assert(c_r_age[i] < ChanBound);
        end else begin
          c_r_age[i] <= '0;
        end
        if (c_b_wait[i]) begin
          c_b_age[i] <= c_b_age[i] + 1'b1;
          assert(c_b_age[i] < ChanBound);
        end else begin
          c_b_age[i] <= '0;
        end
        // ---- L: snoop messages offered on port i are taken within SnoopBound ----
        if (s_ac_wait[i]) begin
          s_ac_age[i] <= s_ac_age[i] + 1'b1;
          assert(s_ac_age[i] < SnoopBound);
        end else begin
          s_ac_age[i] <= '0;
        end
        if (s_cr_wait[i]) begin
          s_cr_age[i] <= s_cr_age[i] + 1'b1;
          assert(s_cr_age[i] < SnoopBound);
        end else begin
          s_cr_age[i] <= '0;
        end
        if (s_cd_wait[i]) begin
          s_cd_age[i] <= s_cd_age[i] + 1'b1;
          assert(s_cd_age[i] < SnoopBound);
        end else begin
          s_cd_age[i] <= '0;
        end
      end

      // ---- L: arbiter, CCU and memory return to idle within their bounds ----
      if (arb_busy) begin
        arb_age <= arb_age + 1'b1;
        assert(arb_age < TxnBound);
      end else begin
        arb_age <= '0;
      end
      if (ccu_busy) begin
        ccu_age <= ccu_age + 1'b1;
        assert(ccu_age < TxnBound);
      end else begin
        ccu_age <= '0;
      end
      if (mem_busy) begin
        mem_age <= mem_age + 1'b1;
        assert(mem_age < MemBound);
      end else begin
        mem_age <= '0;
      end
      // ---- L: messages offered between arbiter and CCU are taken within their
      //         bounds (W waits for the CCU to finish snooping) ----
      if (a_ar_wait) begin
        a_ar_age <= a_ar_age + 1'b1;
        assert(a_ar_age < ChanBound);
      end else begin
        a_ar_age <= '0;
      end
      if (a_aw_wait) begin
        a_aw_age <= a_aw_age + 1'b1;
        assert(a_aw_age < ChanBound);
      end else begin
        a_aw_age <= '0;
      end
      if (a_w_wait) begin
        a_w_age <= a_w_age + 1'b1;
        assert(a_w_age < TxnBound);
      end else begin
        a_w_age <= '0;
      end
      if (a_r_wait) begin
        a_r_age <= a_r_age + 1'b1;
        assert(a_r_age < ChanBound);
      end else begin
        a_r_age <= '0;
      end
      if (a_b_wait) begin
        a_b_age <= a_b_age + 1'b1;
        assert(a_b_age < ChanBound);
      end else begin
        a_b_age <= '0;
      end
      // ---- L: messages offered between CCU and memory are taken within ChanBound ----
      if (m_ar_wait) begin
        m_ar_age <= m_ar_age + 1'b1;
        assert(m_ar_age < ChanBound);
      end else begin
        m_ar_age <= '0;
      end
      if (m_aw_wait) begin
        m_aw_age <= m_aw_age + 1'b1;
        assert(m_aw_age < ChanBound);
      end else begin
        m_aw_age <= '0;
      end
      if (m_w_wait) begin
        m_w_age <= m_w_age + 1'b1;
        assert(m_w_age < ChanBound);
      end else begin
        m_w_age <= '0;
      end
      if (m_r_wait) begin
        m_r_age <= m_r_age + 1'b1;
        assert(m_r_age < ChanBound);
      end else begin
        m_r_age <= '0;
      end
      if (m_b_wait) begin
        m_b_age <= m_b_age + 1'b1;
        assert(m_b_age < ChanBound);
      end else begin
        m_b_age <= '0;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// TileLink crossbar  (src/testbenches/TLCrossBar_test.sv: TLCrossBar
//                     + 2 clients + 2 managers)
// -----------------------------------------------------------------------------
module comm_tilelink_formal(input logic clk_i, input logic rst_ni);
  // Clients issue a request every other cycle and a manager answers two
  // cycles after accepting one, so an accepted request is answered, and every
  // in-flight participant returns to idle, within a handful of cycles.
  localparam int unsigned Bound = 32;
  localparam int unsigned AW = $clog2(Bound+1);
  localparam int unsigned OW = 6;   // outstanding-request counters

  tb_tlcrossbar tb (
    .clk_i(clk_i),
    .rst_ni(rst_ni)
  );

  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) begin
      assume(!rst_ni);
    end else begin
      assume(rst_ni);
    end
  end

  // Wire-level handshakes and pending offers on the four crossbar ports.
  wire m0_a_fire = tb.m0_a_valid && tb.m0_a_ready;
  wire m1_a_fire = tb.m1_a_valid && tb.m1_a_ready;
  wire m0_d_fire = tb.m0_d_valid && tb.m0_d_ready;
  wire m1_d_fire = tb.m1_d_valid && tb.m1_d_ready;
  wire s0_a_fire = tb.s0_a_valid && tb.s0_a_ready;
  wire s1_a_fire = tb.s1_a_valid && tb.s1_a_ready;
  wire s0_d_fire = tb.s0_d_valid && tb.s0_d_ready;
  wire s1_d_fire = tb.s1_d_valid && tb.s1_d_ready;
  wire m0_a_wait = tb.m0_a_valid && !tb.m0_a_ready;
  wire m1_a_wait = tb.m1_a_valid && !tb.m1_a_ready;
  wire m0_d_wait = tb.m0_d_valid && !tb.m0_d_ready;
  wire m1_d_wait = tb.m1_d_valid && !tb.m1_d_ready;
  wire s0_a_wait = tb.s0_a_valid && !tb.s0_a_ready;
  wire s1_a_wait = tb.s1_a_valid && !tb.s1_a_ready;
  wire s0_d_wait = tb.s0_d_valid && !tb.s0_d_ready;
  wire s1_d_wait = tb.s1_d_valid && !tb.s1_d_ready;

  // Participant self-reports.
  wire m0_a_snd = tb.master0.f_a_snd;
  wire m1_a_snd = tb.master1.f_a_snd;
  wire m0_busy  = tb.master0.f_busy;
  wire m1_busy  = tb.master1.f_busy;
  wire s0_a_rcv = tb.slave0.f_a_rcv;
  wire s1_a_rcv = tb.slave1.f_a_rcv;
  wire s0_d_snd = tb.slave0.f_d_snd;
  wire s1_d_snd = tb.slave1.f_d_snd;
  wire s0_busy  = tb.slave0.f_busy;
  wire s1_busy  = tb.slave1.f_busy;

  // The crossbar is a combinational relay (fan-out plus arbiters that only
  // hold state across multi-beat messages, of which there are none here), so
  // the handshakes on its two sides happen in the same cycle.
  wire [1:0] a_in  = {1'b0, m0_a_fire} + {1'b0, m1_a_fire};
  wire [1:0] a_out = {1'b0, s0_a_fire} + {1'b0, s1_a_fire};
  wire [1:0] d_in  = {1'b0, s0_d_fire} + {1'b0, s1_d_fire};
  wire [1:0] d_out = {1'b0, m0_d_fire} + {1'b0, m1_d_fire};

  // Requests each client has sent and not yet been answered for. The clients
  // keep no such record themselves (they accept any D beat), so this is the
  // request/response pairing at the client boundary, independent of how the
  // crossbar remaps source ids.
  logic [OW-1:0] m0_out, m1_out;

  logic [AW-1:0] m0_age, m1_age, s0_age, s1_age, m0_out_age, m1_out_age;
  logic [AW-1:0] m0_a_age, m1_a_age, m0_d_age, m1_d_age;
  logic [AW-1:0] s0_a_age, s1_a_age, s0_d_age, s1_d_age;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      m0_out <= '0;
      m1_out <= '0;
      m0_age <= '0;
      m1_age <= '0;
      s0_age <= '0;
      s1_age <= '0;
      m0_out_age <= '0;
      m1_out_age <= '0;
      m0_a_age <= '0;
      m1_a_age <= '0;
      m0_d_age <= '0;
      m1_d_age <= '0;
      s0_a_age <= '0;
      s1_a_age <= '0;
      s0_d_age <= '0;
      s1_d_age <= '0;
    end else begin
      // ---- S: the client stubs and the wire agree on every A exchange ----
      assert(m0_a_snd == m0_a_fire);
      assert(m1_a_snd == m1_a_fire);

      // ---- S: a manager takes a request only when it can process it (its
      //         a_ready is constant 1, so an A handshake while it is still
      //         responding is accepted on the wire and then overwritten) ----
      assert(s0_a_rcv == s0_a_fire);
      assert(s1_a_rcv == s1_a_fire);

      // ---- S: the manager stubs and the wire agree on every D exchange ----
      assert(s0_d_snd == s0_d_fire);
      assert(s1_d_snd == s1_d_fire);

      // ---- S: the crossbar hands over every message it takes, in the same
      //         cycle, on exactly one port of the other side ----
      assert(a_in == a_out);
      assert(d_in == d_out);

      // ---- S: no response reaches a client that is not owed one ----
      assert(!m0_d_fire || m0_out != '0);
      assert(!m1_d_fire || m1_out != '0);
      m0_out <= m0_out + {{(OW-1){1'b0}}, m0_a_fire} - {{(OW-1){1'b0}}, m0_d_fire};
      m1_out <= m1_out + {{(OW-1){1'b0}}, m1_a_fire} - {{(OW-1){1'b0}}, m1_d_fire};

      // ---- L: every request a client sent is answered within Bound ----
      if (m0_out != '0) begin
        m0_out_age <= m0_out_age + 1'b1;
        assert(m0_out_age < Bound);
      end else begin
        m0_out_age <= '0;
      end
      if (m1_out != '0) begin
        m1_out_age <= m1_out_age + 1'b1;
        assert(m1_out_age < Bound);
      end else begin
        m1_out_age <= '0;
      end

      // ---- L: in-flight clients and managers return to idle within Bound ----
      if (m0_busy) begin
        m0_age <= m0_age + 1'b1;
        assert(m0_age < Bound);
      end else begin
        m0_age <= '0;
      end
      if (m1_busy) begin
        m1_age <= m1_age + 1'b1;
        assert(m1_age < Bound);
      end else begin
        m1_age <= '0;
      end
      if (s0_busy) begin
        s0_age <= s0_age + 1'b1;
        assert(s0_age < Bound);
      end else begin
        s0_age <= '0;
      end
      if (s1_busy) begin
        s1_age <= s1_age + 1'b1;
        assert(s1_age < Bound);
      end else begin
        s1_age <= '0;
      end

      // ---- L: a message offered on any crossbar port is taken within Bound ----
      if (m0_a_wait) begin
        m0_a_age <= m0_a_age + 1'b1;
        assert(m0_a_age < Bound);
      end else begin
        m0_a_age <= '0;
      end
      if (m1_a_wait) begin
        m1_a_age <= m1_a_age + 1'b1;
        assert(m1_a_age < Bound);
      end else begin
        m1_a_age <= '0;
      end
      if (m0_d_wait) begin
        m0_d_age <= m0_d_age + 1'b1;
        assert(m0_d_age < Bound);
      end else begin
        m0_d_age <= '0;
      end
      if (m1_d_wait) begin
        m1_d_age <= m1_d_age + 1'b1;
        assert(m1_d_age < Bound);
      end else begin
        m1_d_age <= '0;
      end
      if (s0_a_wait) begin
        s0_a_age <= s0_a_age + 1'b1;
        assert(s0_a_age < Bound);
      end else begin
        s0_a_age <= '0;
      end
      if (s1_a_wait) begin
        s1_a_age <= s1_a_age + 1'b1;
        assert(s1_a_age < Bound);
      end else begin
        s1_a_age <= '0;
      end
      if (s0_d_wait) begin
        s0_d_age <= s0_d_age + 1'b1;
        assert(s0_d_age < Bound);
      end else begin
        s0_d_age <= '0;
      end
      if (s1_d_wait) begin
        s1_d_age <= s1_d_age + 1'b1;
        assert(s1_d_age < Bound);
      end else begin
        s1_d_age <= '0;
      end
    end
  end
endmodule

`endif
