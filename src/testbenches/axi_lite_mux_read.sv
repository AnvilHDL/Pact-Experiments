// AXI4-Lite Read Multiplexer (AR + R channels only)
`include "common_cells/registers.svh"

module axi_lite_read_mux #(
  parameter type          ar_chan_t  = logic,
  parameter type           r_chan_t  = logic,
  parameter type          axi_req_t  = logic,
  parameter type         axi_resp_t  = logic,
  parameter int unsigned NoSlvPorts  = 32'd2,
  parameter int unsigned MaxTrans    = 32'd8,
  parameter bit          FallThrough = 1'b0,
  parameter bit          SpillAr     = 1'b0,
  parameter bit          SpillR      = 1'b0
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

  ar_chan_t [NoSlvPorts-1:0] slv_ar_chans;
  logic     [NoSlvPorts-1:0] slv_ar_valids, slv_ar_readies;

  select_t  ar_select;
  ar_chan_t mst_ar_chan;
  logic     mst_ar_valid, mst_ar_ready;
  logic     ar_valid,     ar_ready;

  select_t  r_select;
  logic     r_fifo_full,  r_fifo_empty;
  logic     r_fifo_push,  r_fifo_pop;

  r_chan_t  mst_r_chan;
  logic     mst_r_valid,  mst_r_ready;

  // AR Channel
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_ar_arb_input
    assign slv_ar_chans[i]         = slv_reqs_i[i].ar;
    assign slv_ar_valids[i]        = slv_reqs_i[i].ar_valid;
    assign slv_resps_o[i].ar_ready = slv_ar_readies[i];
  end

  rr_arb_tree #(
    .NumIn    ( NoSlvPorts ),
    .DataType ( ar_chan_t  ),
    .AxiVldRdy( 1'b1       ),
    .LockIn   ( 1'b1       )
  ) i_ar_arbiter (
    .clk_i  ( clk_i          ),
    .rst_ni ( rst_ni         ),
    .flush_i( 1'b0           ),
    .rr_i   ( '0             ),
    .req_i  ( slv_ar_valids  ),
    .gnt_o  ( slv_ar_readies ),
    .data_i ( slv_ar_chans   ),
    .gnt_i  ( ar_ready       ),
    .req_o  ( ar_valid       ),
    .data_o ( mst_ar_chan    ),
    .idx_o  ( ar_select      )
  );

  assign mst_ar_valid = (!r_fifo_full) ? ar_valid     : 1'b0;
  assign ar_ready     = (!r_fifo_full) ? mst_ar_ready : 1'b0;
  assign r_fifo_push  = mst_ar_valid & mst_ar_ready;

  fifo_v3 #(
    .FALL_THROUGH ( FallThrough ),
    .DEPTH        ( MaxTrans    ),
    .dtype        ( select_t    )
  ) i_r_fifo (
    .clk_i     ( clk_i        ),
    .rst_ni    ( rst_ni       ),
    .flush_i   ( 1'b0         ),
    .testmode_i( test_i       ),
    .full_o    ( r_fifo_full  ),
    .empty_o   ( r_fifo_empty ),
    .usage_o   (              ),
    .data_i    ( ar_select    ),
    .push_i    ( r_fifo_push  ),
    .data_o    ( r_select     ),
    .pop_i     ( r_fifo_pop   )
  );

  spill_register #(
    .T       ( ar_chan_t ),
    .Bypass  ( ~SpillAr  )
  ) i_ar_spill_reg (
    .clk_i   ( clk_i               ),
    .rst_ni  ( rst_ni              ),
    .valid_i ( mst_ar_valid        ),
    .ready_o ( mst_ar_ready        ),
    .data_i  ( mst_ar_chan         ),
    .valid_o ( mst_req_o.ar_valid  ),
    .ready_i ( mst_resp_i.ar_ready ),
    .data_o  ( mst_req_o.ar        )
  );

  // R Channel
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slv_resps_r
    assign slv_resps_o[i].r       = mst_r_chan;
    assign slv_resps_o[i].r_valid = mst_r_valid & ~r_fifo_empty & (r_select == select_t'(i));
  end
  assign mst_r_ready    = ~r_fifo_empty & slv_reqs_i[r_select].r_ready;
  assign r_fifo_pop     = mst_r_valid & mst_r_ready;

  spill_register #(
    .T       ( r_chan_t ),
    .Bypass  ( ~SpillR  )
  ) i_r_spill_reg (
    .clk_i   ( clk_i              ),
    .rst_ni  ( rst_ni             ),
    .valid_i ( mst_resp_i.r_valid ),
    .ready_o ( mst_req_o.r_ready  ),
    .data_i  ( mst_resp_i.r       ),
    .valid_o ( mst_r_valid        ),
    .ready_i ( mst_r_ready        ),
    .data_o  ( mst_r_chan         )
  );

  // Tie off unused write channels
  assign mst_req_o.aw_valid = 1'b0;
  assign mst_req_o.aw = '0;
  assign mst_req_o.w_valid = 1'b0;
  assign mst_req_o.w = '0;
  assign mst_req_o.b_ready = 1'b0;
  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slv_write_tieoff
    assign slv_resps_o[i].aw_ready = 1'b0;
    assign slv_resps_o[i].w_ready = 1'b0;
    assign slv_resps_o[i].b_valid = 1'b0;
    assign slv_resps_o[i].b = '0;
  end

endmodule