// AXI4-Lite Read Demultiplexer (AR + R channels only)
`include "common_cells/registers.svh"

module axi_lite_read_demux #(
  parameter type          ar_chan_t      = logic,
  parameter type          r_chan_t       = logic,
  parameter type          axi_req_t      = logic,
  parameter type          axi_resp_t     = logic,
  parameter int unsigned  NoMstPorts     = 32'd4,
  parameter int unsigned  MaxTrans       = 32'd8,
  parameter bit           FallThrough    = 1'b0,
  parameter bit           SpillAr        = 1'b0,
  parameter bit           SpillR         = 1'b0,
  parameter type          select_t       = logic [$clog2(NoMstPorts)-1:0]
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t                   slv_req_i,
  input  select_t                    slv_ar_select_i,
  output axi_resp_t                  slv_resp_o,
  output axi_req_t  [NoMstPorts-1:0] mst_reqs_o,
  input  axi_resp_t [NoMstPorts-1:0] mst_resps_i
);

  typedef struct packed {
    ar_chan_t ar;
    select_t  select;
  } ar_chan_select_t;

  ar_chan_select_t       slv_ar_chan;
  logic                  slv_ar_valid,    slv_ar_ready;
  logic [NoMstPorts-1:0] mst_ar_valids,   mst_ar_readies;
  logic                  r_fifo_push,     r_fifo_pop;
  logic                  r_fifo_full,     r_fifo_empty;
  r_chan_t               slv_r_chan;
  select_t               r_select;
  logic                  slv_r_valid,     slv_r_ready;
  logic [NoMstPorts-1:0] mst_r_valids,    mst_r_readies;

  // AR Channel
  ar_chan_select_t slv_ar_chan_in;
  assign slv_ar_chan_in = {slv_req_i.ar, slv_ar_select_i};

  spill_register #(
    .T      ( ar_chan_select_t ),
    .Bypass ( ~SpillAr         )
  ) i_ar_spill_reg (
    .clk_i   ( clk_i           ),
    .rst_ni  ( rst_ni          ),
    .valid_i ( slv_req_i.ar_valid ),
    .ready_o ( slv_resp_o.ar_ready ),
    .data_i  ( slv_ar_chan_in  ),
    .valid_o ( slv_ar_valid    ),
    .ready_i ( slv_ar_ready    ),
    .data_o  ( slv_ar_chan     )
  );

  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_ar
    assign mst_reqs_o[i].ar       = slv_ar_chan.ar;
    assign mst_reqs_o[i].ar_valid = mst_ar_valids[i];
    assign mst_ar_readies[i]      = mst_resps_i[i].ar_ready;
  end

  always_comb begin
    slv_ar_ready  = 1'b0;
    mst_ar_valids = '0;
    r_fifo_push   = 1'b0;
    if (!r_fifo_full && slv_ar_valid) begin
      mst_ar_valids[slv_ar_chan.select] = 1'b1;
      if (mst_ar_readies[slv_ar_chan.select]) begin
        slv_ar_ready = 1'b1;
        r_fifo_push  = 1'b1;
      end
    end
  end

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
    .data_i    ( slv_ar_chan.select ),
    .push_i    ( r_fifo_push  ),
    .data_o    ( r_select     ),
    .pop_i     ( r_fifo_pop   )
  );

  // R Channel
  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_r
    assign mst_reqs_o[i].r_ready = mst_r_readies[i];
    assign mst_r_valids[i]       = mst_resps_i[i].r_valid;
  end

  always_comb begin
    slv_r_chan    = mst_resps_i[r_select].r;
    slv_r_valid   = 1'b0;
    mst_r_readies = '0;
    r_fifo_pop    = 1'b0;
    if (!r_fifo_empty) begin
      slv_r_valid = mst_r_valids[r_select];
      if (slv_r_valid && slv_r_ready) begin
        mst_r_readies[r_select] = 1'b1;
        r_fifo_pop = 1'b1;
      end
    end
  end

  spill_register #(
    .T      ( r_chan_t ),
    .Bypass ( ~SpillR  )
  ) i_r_spill_reg (
    .clk_i   ( clk_i          ),
    .rst_ni  ( rst_ni         ),
    .valid_i ( slv_r_valid    ),
    .ready_o ( slv_r_ready    ),
    .data_i  ( slv_r_chan     ),
    .valid_o ( slv_resp_o.r_valid ),
    .ready_i ( slv_req_i.r_ready ),
    .data_o  ( slv_resp_o.r   )
  );

  // Tie off unused write channels
  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_write_tieoff
    assign mst_reqs_o[i].aw_valid = 1'b0;
    assign mst_reqs_o[i].aw = '0;
    assign mst_reqs_o[i].w_valid = 1'b0;
    assign mst_reqs_o[i].w = '0;
    assign mst_reqs_o[i].b_ready = 1'b0;
  end
  assign slv_resp_o.aw_ready = 1'b0;
  assign slv_resp_o.w_ready = 1'b0;
  assign slv_resp_o.b_valid = 1'b0;
  assign slv_resp_o.b = '0;

endmodule
