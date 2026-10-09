`include "axi/typedef.svh"

package yosys_perf_axi_pkg;
  typedef logic [31:0] addr_t;
  typedef logic [31:0] data_t;
  typedef logic [3:0]  strb_t;
  typedef logic [1:0]  select_t;

  `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
  `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)
  `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)
  `AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)
endpackage

package yosys_perf_ace_pkg;
  localparam int unsigned AxiDataWidth    = 8;
  localparam int unsigned DcacheLineWidth = 16;
  localparam int unsigned NoMstPorts      = 3;
  localparam int unsigned SlvAxiIDWidth   = 1;
  localparam int unsigned AxiAddrWidth    = 8;
  localparam int unsigned AxiStrbWidth    = AxiDataWidth / 8;
  localparam int unsigned AxiUserWidth    = 1;
  localparam int unsigned MstIdxBits      = $clog2(NoMstPorts);
  localparam int unsigned FullIdWidth     = SlvAxiIDWidth + MstIdxBits;

  typedef logic [FullIdWidth-1:0]  id_t;
  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] data_t;
  typedef logic [AxiStrbWidth-1:0] strb_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  typedef struct packed {
    id_t        id;
    addr_t      addr;
    logic [7:0] len;
    logic [2:0] size;
    logic [1:0] burst;
    logic       lock;
    logic [3:0] cache;
    logic [2:0] prot;
    logic [3:0] qos;
    logic [3:0] region;
    logic [5:0] atop;
    user_t      user;
    logic [2:0] snoop;
    logic [1:0] bar;
    logic [1:0] domain;
    logic       awunique;
  } aw_chan_t;

  typedef struct packed {
    id_t        id;
    addr_t      addr;
    logic [7:0] len;
    logic [2:0] size;
    logic [1:0] burst;
    logic       lock;
    logic [3:0] cache;
    logic [2:0] prot;
    logic [3:0] qos;
    logic [3:0] region;
    user_t      user;
    logic [3:0] snoop;
    logic [1:0] bar;
    logic [1:0] domain;
  } ar_chan_t;

  typedef struct packed {
    data_t data;
    strb_t strb;
    logic  last;
    user_t user;
  } w_chan_t;

  typedef struct packed {
    id_t        id;
    logic [1:0] resp;
    user_t      user;
  } b_chan_t;

  typedef struct packed {
    id_t        id;
    data_t      data;
    logic [3:0] resp;
    logic       last;
    user_t      user;
  } r_chan_t;

  typedef struct packed {
    aw_chan_t aw;
    logic     aw_valid;
    w_chan_t  w;
    logic     w_valid;
    logic     b_ready;
    ar_chan_t ar;
    logic     ar_valid;
    logic     r_ready;
    logic     wack;
    logic     rack;
  } mst_req_t;

  typedef struct packed {
    logic     aw_ready;
    logic     ar_ready;
    logic     w_ready;
    logic     b_valid;
    b_chan_t  b;
    logic     r_valid;
    r_chan_t  r;
  } mst_resp_t;

  typedef struct packed {
    addr_t      addr;
    logic [3:0] snoop;
    logic [2:0] prot;
  } ac_chan_t;

  typedef struct packed {
    data_t data;
    logic  last;
  } cd_chan_t;

  typedef struct packed {
    logic dataTransfer;
    logic error;
    logic passDirty;
    logic isShared;
    logic wasUnique;
  } crresp_t;

  typedef struct packed {
    ac_chan_t ac;
    logic     ac_valid;
    logic     cr_ready;
    logic     cd_ready;
  } snoop_req_t;

  typedef struct packed {
    logic     ac_ready;
    crresp_t  cr_resp;
    logic     cr_valid;
    cd_chan_t cd;
    logic     cd_valid;
  } snoop_resp_t;
endpackage

module perf_fifo_sv (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        flush_i,
  input  logic        testmode_i,
  input  logic [31:0] data_i,
  input  logic        push_i,
  input  logic        pop_i,
  output logic        full_o,
  output logic        empty_o,
  output logic [2:0]  usage_o,
  output logic [31:0] data_o
);
  fifo_v3 #(
    .FALL_THROUGH ( 1'b0        ),
    .DATA_WIDTH   ( 32          ),
    .DEPTH        ( 8           ),
    .dtype        ( logic [31:0] )
  ) dut (
    .clk_i,
    .rst_ni,
    .flush_i,
    .testmode_i,
    .full_o,
    .empty_o,
    .usage_o,
    .data_i,
    .push_i,
    .data_o,
    .pop_i
  );
endmodule

module perf_stream_fifo_sv (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        flush_i,
  input  logic        testmode_i,
  input  logic [31:0] data_i,
  input  logic        valid_i,
  input  logic        ready_i,
  output logic        ready_o,
  output logic [31:0] data_o,
  output logic        valid_o
);
  passthrough_stream_fifo #(
    .Depth       ( 8            ),
    .PrintInfo   ( 1'b0         ),
    .SameCycleRW ( 1'b1         ),
    .type_t      ( logic [31:0] )
  ) dut (
    .clk_i,
    .rst_ni,
    .flush_i,
    .testmode_i,
    .data_i,
    .valid_i,
    .ready_o,
    .data_o,
    .valid_o,
    .ready_i
  );
endmodule

module perf_spill_register_sv (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic [31:0] data_i,
  input  logic        ready_i,
  output logic        ready_o,
  output logic        valid_o,
  output logic [31:0] data_o
);
  spill_register #(
    .T      ( logic [31:0] ),
    .Bypass ( 1'b0         )
  ) dut (
    .clk_i,
    .rst_ni,
    .valid_i,
    .ready_o,
    .data_i,
    .valid_o,
    .ready_i,
    .data_o
  );
endmodule

module perf_arbiter_sv (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              flush_i,
  input  logic [1:0]        rr_i,
  input  logic [3:0]        req_i,
  input  logic [3:0][31:0]  data_i,
  input  logic              gnt_i,
  output logic [3:0]        gnt_o,
  output logic              req_o,
  output logic [31:0]       data_o,
  output logic [1:0]        idx_o
);
  rr_arb_tree #(
    .NumIn    ( 4            ),
    .DataWidth( 32           ),
    .DataType ( logic [31:0] ),
    .ExtPrio  ( 1'b0         ),
    .AxiVldRdy( 1'b0         ),
    .LockIn   ( 1'b1         ),
    .FairArb  ( 1'b1         )
  ) dut (
    .clk_i,
    .rst_ni,
    .flush_i,
    .rr_i,
    .req_i,
    .gnt_o,
    .data_i,
    .req_o,
    .gnt_i,
    .data_o,
    .idx_o
  );
endmodule

module perf_axi_demux_read_sv
  import yosys_perf_axi_pkg::*;
(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t                   slv_req_i,
  input  select_t                    slv_ar_select_i,
  input  axi_resp_t [3:0]            mst_resps_i,
  output axi_resp_t                  slv_resp_o,
  output axi_req_t  [3:0]            mst_reqs_o
);
  axi_lite_read_demux #(
    .ar_chan_t   ( ar_chan_t  ),
    .r_chan_t    ( r_chan_t   ),
    .axi_req_t   ( axi_req_t  ),
    .axi_resp_t  ( axi_resp_t ),
    .NoMstPorts  ( 4          ),
    .MaxTrans    ( 8          ),
    .FallThrough ( 1'b0       ),
    .SpillAr     ( 1'b0       ),
    .SpillR      ( 1'b0       ),
    .select_t    ( select_t   )
  ) dut (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_req_i,
    .slv_ar_select_i,
    .slv_resp_o,
    .mst_reqs_o,
    .mst_resps_i
  );
endmodule

module perf_axi_demux_write_sv
  import yosys_perf_axi_pkg::*;
(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t                   slv_req_i,
  input  select_t                    slv_aw_select_i,
  input  axi_resp_t [3:0]            mst_resps_i,
  output axi_resp_t                  slv_resp_o,
  output axi_req_t  [3:0]            mst_reqs_o
);
  axi_lite_write_demux #(
    .aw_chan_t   ( aw_chan_t  ),
    .w_chan_t    ( w_chan_t   ),
    .b_chan_t    ( b_chan_t   ),
    .axi_req_t   ( axi_req_t  ),
    .axi_resp_t  ( axi_resp_t ),
    .NoMstPorts  ( 4          ),
    .MaxTrans    ( 8          ),
    .FallThrough ( 1'b0       ),
    .SpillAw     ( 1'b0       ),
    .SpillW      ( 1'b0       ),
    .SpillB      ( 1'b0       ),
    .select_t    ( select_t   )
  ) dut (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_req_i,
    .slv_aw_select_i,
    .slv_resp_o,
    .mst_reqs_o,
    .mst_resps_i
  );
endmodule

module perf_axi_mux_read_sv
  import yosys_perf_axi_pkg::*;
(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t  [3:0]            slv_reqs_i,
  input  axi_resp_t                  mst_resp_i,
  output axi_resp_t [3:0]            slv_resps_o,
  output axi_req_t                   mst_req_o
);
  axi_lite_read_mux #(
    .ar_chan_t   ( ar_chan_t  ),
    .r_chan_t    ( r_chan_t   ),
    .axi_req_t   ( axi_req_t  ),
    .axi_resp_t  ( axi_resp_t ),
    .NoSlvPorts  ( 4          ),
    .MaxTrans    ( 8          ),
    .FallThrough ( 1'b0       ),
    .SpillAr     ( 1'b0       ),
    .SpillR      ( 1'b0       )
  ) dut (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_reqs_i,
    .slv_resps_o,
    .mst_req_o,
    .mst_resp_i
  );
endmodule

module perf_axi_mux_write_sv
  import yosys_perf_axi_pkg::*;
(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_i,
  input  axi_req_t  [3:0]            slv_reqs_i,
  input  axi_resp_t                  mst_resp_i,
  output axi_resp_t [3:0]            slv_resps_o,
  output axi_req_t                   mst_req_o
);
  axi_lite_write_mux #(
    .aw_chan_t   ( aw_chan_t  ),
    .w_chan_t    ( w_chan_t   ),
    .b_chan_t    ( b_chan_t   ),
    .axi_req_t   ( axi_req_t  ),
    .axi_resp_t  ( axi_resp_t ),
    .NoSlvPorts  ( 4          ),
    .MaxTrans    ( 8          ),
    .FallThrough ( 1'b0       ),
    .SpillAw     ( 1'b0       ),
    .SpillW      ( 1'b0       ),
    .SpillB      ( 1'b0       )
  ) dut (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_reqs_i,
    .slv_resps_o,
    .mst_req_o,
    .mst_resp_i
  );
endmodule

module perf_ace_sv
  import yosys_perf_ace_pkg::*;
(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  mst_req_t                   ccu_req_i,
  input  mst_resp_t                  ccu_resp_i,
  input  snoop_resp_t [NoMstPorts-1:0] m2s_resp_i,
  output mst_resp_t                  ccu_resp_o,
  output mst_req_t                   ccu_req_o,
  output snoop_req_t  [NoMstPorts-1:0] s2m_req_o
);
  ccu_fsm #(
    .DcacheLineWidth ( DcacheLineWidth ),
    .AxiDataWidth    ( AxiDataWidth    ),
    .NoMstPorts      ( NoMstPorts      ),
    .SlvAxiIDWidth   ( SlvAxiIDWidth   ),
    .mst_req_t       ( mst_req_t       ),
    .mst_resp_t      ( mst_resp_t      ),
    .snoop_req_t     ( snoop_req_t     ),
    .snoop_resp_t    ( snoop_resp_t    )
  ) dut (
    .clk_i,
    .rst_ni,
    .ccu_req_i,
    .ccu_resp_o,
    .ccu_req_o,
    .ccu_resp_i,
    .s2m_req_o,
    .m2s_resp_i
  );
endmodule
