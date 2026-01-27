// AXI4-Lite Write Multiplexer (AW + W + B channels only)
`include "common_cells/registers.svh"

module axi_lite_write_mux #(
  parameter type          aw_chan_t  = logic,
  parameter type           w_chan_t  = logic,
  parameter type           b_chan_t  = logic,
  parameter type          axi_req_t  = logic,
  parameter type         axi_resp_t  = logic,
  parameter int unsigned NoSlvPorts  = 32'd2,
  parameter int unsigned MaxTrans    = 32'd8,
  parameter bit          FallThrough = 1'b0,
  parameter bit          SpillAw     = 1'b0,
  parameter bit          SpillW      = 1'b0,
  parameter bit          SpillB      = 1'b0
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t  [NoSlvPorts-1:0] slv_reqs_i,
  output axi_resp_t [NoSlvPorts-1:0] slv_resps_o,
  output axi_req_t                   mst_req_o,
  input  axi_resp_t                  mst_resp_i
);

  localparam int unsigned CLog2NoSlvPorts = $clog2(NoSlvPorts);
  typedef logic [CLog2NoSlvPorts-1:0] select_t;

  aw_chan_t [NoSlvPorts-1:0] slv_aw_chans;
  logic     [NoSlvPorts-1:0] slv_aw_valids, slv_aw_readies;

  select_t  aw_select;
  aw_chan_t mst_aw_chan;
  logic     mst_aw_valid, mst_aw_ready;
  logic     aw_valid,     aw_ready;

  logic     lock_aw_valid_d, lock_aw_valid_q;
  logic     load_aw_lock;

  logic     w_fifo_full,  w_fifo_empty;
  logic     w_fifo_push,  w_fifo_pop;

  select_t  w_select;
  w_chan_t  mst_w_chan;
  logic     mst_w_valid,  mst_w_ready;

  select_t  b_select;
  logic     b_fifo_full,  b_fifo_empty;
  logic     b_fifo_pop;

  b_chan_t  mst_b_chan;
  logic     mst_b_valid,  mst_b_ready;

  // AW Channel
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_aw_arb_input
    assign slv_aw_chans[i]         = slv_reqs_i[i].aw;
    assign slv_aw_valids[i]        = slv_reqs_i[i].aw_valid;
    assign slv_resps_o[i].aw_ready = slv_aw_readies[i];
  end

  rr_arb_tree #(
    .NumIn    ( NoSlvPorts ),
    .DataType ( aw_chan_t  ),
    .AxiVldRdy( 1'b1       ),
    .LockIn   ( 1'b1       )
  ) i_aw_arbiter (
    .clk_i  ( clk_i          ),
    .rst_ni ( rst_ni         ),
    .flush_i( 1'b0           ),
    .rr_i   ( '0             ),
    .req_i  ( slv_aw_valids  ),
    .gnt_o  ( slv_aw_readies ),
    .data_i ( slv_aw_chans   ),
    .gnt_i  ( aw_ready       ),
    .req_o  ( aw_valid       ),
    .data_o ( mst_aw_chan    ),
    .idx_o  ( aw_select      )
  );

  always_comb begin
    lock_aw_valid_d = lock_aw_valid_q;
    load_aw_lock    = 1'b0;
    w_fifo_push     = 1'b0;
    mst_aw_valid    = 1'b0;
    aw_ready        = 1'b0;

    if (lock_aw_valid_q) begin
      mst_aw_valid = 1'b1;
      if (mst_aw_ready) begin
        aw_ready        = 1'b1;
        lock_aw_valid_d = 1'b0;
        load_aw_lock    = 1'b1;
      end
    end else begin
      if (!w_fifo_full && aw_valid) begin
        mst_aw_valid = 1'b1;
        w_fifo_push = 1'b1;
        if (mst_aw_ready) begin
          aw_ready = 1'b1;
        end else begin
          lock_aw_valid_d = 1'b1;
          load_aw_lock    = 1'b1;
        end
      end
    end
  end

  `FFLARN(lock_aw_valid_q, lock_aw_valid_d, load_aw_lock, '0, clk_i, rst_ni)

  fifo_v3 #(
    .FALL_THROUGH ( FallThrough ),
    .DEPTH        ( MaxTrans    ),
    .dtype        ( select_t    )
  ) i_w_fifo (
    .clk_i     ( clk_i        ),
    .rst_ni    ( rst_ni       ),
    .flush_i   ( 1'b0         ),
    .testmode_i( test_i       ),
    .full_o    ( w_fifo_full  ),
    .empty_o   ( w_fifo_empty ),
    .usage_o   (              ),
    .data_i    ( aw_select    ),
    .push_i    ( w_fifo_push  ),
    .data_o    ( w_select     ),
    .pop_i     ( w_fifo_pop   )
  );

  spill_register #(
    .T       ( aw_chan_t  ),
    .Bypass  ( ~SpillAw   )
  ) i_aw_spill_reg (
    .clk_i   ( clk_i               ),
    .rst_ni  ( rst_ni              ),
    .valid_i ( mst_aw_valid        ),
    .ready_o ( mst_aw_ready        ),
    .data_i  ( mst_aw_chan         ),
    .valid_o ( mst_req_o.aw_valid  ),
    .ready_i ( mst_resp_i.aw_ready ),
    .data_o  ( mst_req_o.aw        )
  );

  // W Channel
  assign mst_w_chan      = slv_reqs_i[w_select].w;
  assign mst_w_valid     = (!w_fifo_empty && !b_fifo_full) ? slv_reqs_i[w_select].w_valid  : 1'b0;
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slv_w_ready
    assign slv_resps_o[i].w_ready =  mst_w_ready & ~w_fifo_empty &
                                    ~b_fifo_full & (w_select == select_t'(i));
  end
  assign w_fifo_pop      = mst_w_valid & mst_w_ready;

  fifo_v3 #(
    .FALL_THROUGH ( FallThrough ),
    .DEPTH        ( MaxTrans    ),
    .dtype        ( select_t    )
  ) i_b_fifo (
    .clk_i     ( clk_i        ),
    .rst_ni    ( rst_ni       ),
    .flush_i   ( 1'b0         ),
    .testmode_i( test_i       ),
    .full_o    ( b_fifo_full  ),
    .empty_o   ( b_fifo_empty ),
    .usage_o   (              ),
    .data_i    ( w_select     ),
    .push_i    ( w_fifo_pop   ),
    .data_o    ( b_select     ),
    .pop_i     ( b_fifo_pop   )
  );

  spill_register #(
    .T       ( w_chan_t ),
    .Bypass  ( ~SpillW  )
  ) i_w_spill_reg (
    .clk_i   ( clk_i              ),
    .rst_ni  ( rst_ni             ),
    .valid_i ( mst_w_valid        ),
    .ready_o ( mst_w_ready        ),
    .data_i  ( mst_w_chan         ),
    .valid_o ( mst_req_o.w_valid  ),
    .ready_i ( mst_resp_i.w_ready ),
    .data_o  ( mst_req_o.w        )
  );

  // B Channel
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slv_resps_b
    assign slv_resps_o[i].b       = mst_b_chan;
    assign slv_resps_o[i].b_valid = mst_b_valid & ~b_fifo_empty & (b_select == select_t'(i));
  end
  assign mst_b_ready    = ~b_fifo_empty & slv_reqs_i[b_select].b_ready;
  assign b_fifo_pop     = mst_b_valid & mst_b_ready;

  spill_register #(
    .T       ( b_chan_t ),
    .Bypass  ( ~SpillB  )
  ) i_b_spill_reg (
    .clk_i   ( clk_i              ),
    .rst_ni  ( rst_ni             ),
    .valid_i ( mst_resp_i.b_valid ),
    .ready_o ( mst_req_o.b_ready  ),
    .data_i  ( mst_resp_i.b       ),
    .valid_o ( mst_b_valid        ),
    .ready_i ( mst_b_ready        ),
    .data_o  ( mst_b_chan         )
  );

  // Tie off unused read channels
  assign mst_req_o.ar_valid = 1'b0;
  assign mst_req_o.ar = '0;
  assign mst_req_o.r_ready = 1'b0;
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slv_read_tieoff
    assign slv_resps_o[i].ar_ready = 1'b0;
    assign slv_resps_o[i].r_valid = 1'b0;
    assign slv_resps_o[i].r = '0;
  end

endmodule