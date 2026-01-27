// AXI4-Lite Write Demultiplexer (AW + W + B channels only)
`include "common_cells/registers.svh"

module axi_lite_write_demux #(
  parameter type          aw_chan_t      = logic,
  parameter type          w_chan_t       = logic,
  parameter type          b_chan_t       = logic,
  parameter type          axi_req_t      = logic,
  parameter type          axi_resp_t     = logic,
  parameter int unsigned  NoMstPorts     = 32'd4,
  parameter int unsigned  MaxTrans       = 32'd8,
  parameter bit           FallThrough    = 1'b0,
  parameter bit           SpillAw        = 1'b0,
  parameter bit           SpillW         = 1'b0,
  parameter bit           SpillB         = 1'b0,
  parameter type          select_t       = logic [$clog2(NoMstPorts)-1:0]
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t                   slv_req_i,
  input  select_t                    slv_aw_select_i,
  output axi_resp_t                  slv_resp_o,
  output axi_req_t  [NoMstPorts-1:0] mst_reqs_o,
  input  axi_resp_t [NoMstPorts-1:0] mst_resps_i
);

  typedef struct packed {
    aw_chan_t aw;
    select_t  select;
  } aw_chan_select_t;

  aw_chan_select_t       slv_aw_chan;
  logic                  slv_aw_valid,    slv_aw_ready;
  logic [NoMstPorts-1:0] mst_aw_valids,   mst_aw_readies;
  logic                  lock_aw_valid_d, lock_aw_valid_q, load_aw_lock;
  logic                  w_fifo_push,     w_fifo_pop;
  logic                  w_fifo_full,     w_fifo_empty;
  w_chan_t               slv_w_chan;
  select_t               w_select;
  logic                  slv_w_valid,     slv_w_ready;
  logic [NoMstPorts-1:0] mst_w_valids,    mst_w_readies;
  logic                  b_fifo_pop;
  logic                  b_fifo_full,     b_fifo_empty;
  b_chan_t               slv_b_chan;
  select_t               b_select;
  logic                  slv_b_valid,     slv_b_ready;
  logic [NoMstPorts-1:0] mst_b_valids,    mst_b_readies;

  // AW Channel
  aw_chan_select_t slv_aw_chan_in;
  assign slv_aw_chan_in = {slv_req_i.aw, slv_aw_select_i};

  spill_register #(
    .T      ( aw_chan_select_t ),
    .Bypass ( ~SpillAw         )
  ) i_aw_spill_reg (
    .clk_i   ( clk_i           ),
    .rst_ni  ( rst_ni          ),
    .valid_i ( slv_req_i.aw_valid ),
    .ready_o ( slv_resp_o.aw_ready ),
    .data_i  ( slv_aw_chan_in  ),
    .valid_o ( slv_aw_valid    ),
    .ready_i ( slv_aw_ready    ),
    .data_o  ( slv_aw_chan     )
  );

  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_aw
    assign mst_reqs_o[i].aw       = slv_aw_chan.aw;
    assign mst_reqs_o[i].aw_valid = mst_aw_valids[i];
    assign mst_aw_readies[i]      = mst_resps_i[i].aw_ready;
  end

  always_comb begin
    lock_aw_valid_d = lock_aw_valid_q;
    load_aw_lock    = 1'b0;
    slv_aw_ready    = 1'b0;
    mst_aw_valids   = '0;
    w_fifo_push     = 1'b0;

    if (lock_aw_valid_q) begin
      mst_aw_valids[slv_aw_chan.select] = 1'b1;
      if (mst_aw_readies[slv_aw_chan.select]) begin
        slv_aw_ready    = 1'b1;
        lock_aw_valid_d = 1'b0;
        load_aw_lock    = 1'b1;
      end
    end else begin
      if (!w_fifo_full && slv_aw_valid) begin
        mst_aw_valids[slv_aw_chan.select] = 1'b1;
        w_fifo_push = 1'b1;
        if (mst_aw_readies[slv_aw_chan.select]) begin
          slv_aw_ready = 1'b1;
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
    .data_i    ( slv_aw_chan.select ),
    .push_i    ( w_fifo_push  ),
    .data_o    ( w_select     ),
    .pop_i     ( w_fifo_pop   )
  );

  // W Channel
  spill_register #(
    .T      ( w_chan_t ),
    .Bypass ( ~SpillW  )
  ) i_w_spill_reg (
    .clk_i   ( clk_i          ),
    .rst_ni  ( rst_ni         ),
    .valid_i ( slv_req_i.w_valid ),
    .ready_o ( slv_resp_o.w_ready ),
    .data_i  ( slv_req_i.w    ),
    .valid_o ( slv_w_valid    ),
    .ready_i ( slv_w_ready    ),
    .data_o  ( slv_w_chan     )
  );

  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_w
    assign mst_reqs_o[i].w       = slv_w_chan;
    assign mst_reqs_o[i].w_valid = mst_w_valids[i];
    assign mst_w_readies[i]      = mst_resps_i[i].w_ready;
  end

  always_comb begin
    slv_w_ready   = 1'b0;
    mst_w_valids  = '0;
    w_fifo_pop    = 1'b0;
    if (!w_fifo_empty && !b_fifo_full && slv_w_valid) begin
      mst_w_valids[w_select] = 1'b1;
      if (mst_w_readies[w_select]) begin
        slv_w_ready = 1'b1;
        w_fifo_pop  = 1'b1;
      end
    end
  end

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

  // B Channel
  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_b
    assign mst_reqs_o[i].b_ready = mst_b_readies[i];
    assign mst_b_valids[i]       = mst_resps_i[i].b_valid;
  end

  always_comb begin
    slv_b_chan      = mst_resps_i[b_select].b;
    slv_b_valid     = 1'b0;
    mst_b_readies   = '0;
    b_fifo_pop      = 1'b0;
    if (!b_fifo_empty) begin
      slv_b_valid = mst_b_valids[b_select];
      if (slv_b_valid && slv_b_ready) begin
        mst_b_readies[b_select] = 1'b1;
        b_fifo_pop = 1'b1;
      end
    end
  end

  spill_register #(
    .T      ( b_chan_t ),
    .Bypass ( ~SpillB  )
  ) i_b_spill_reg (
    .clk_i   ( clk_i          ),
    .rst_ni  ( rst_ni         ),
    .valid_i ( slv_b_valid    ),
    .ready_o ( slv_b_ready    ),
    .data_i  ( slv_b_chan     ),
    .valid_o ( slv_resp_o.b_valid ),
    .ready_i ( slv_req_i.b_ready ),
    .data_o  ( slv_resp_o.b   )
  );

  // Tie off unused read channels
  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_mst_read_tieoff
    assign mst_reqs_o[i].ar_valid = 1'b0;
    assign mst_reqs_o[i].ar = '0;
    assign mst_reqs_o[i].r_ready = 1'b0;
  end
  assign slv_resp_o.ar_ready = 1'b0;
  assign slv_resp_o.r_valid = 1'b0;
  assign slv_resp_o.r = '0;

endmodule
