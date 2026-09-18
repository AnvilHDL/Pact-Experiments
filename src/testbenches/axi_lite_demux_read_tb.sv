// AXI4-Lite Read Demux Testbench
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module axi_read_demux_slave #(
  parameter type ar_chan_t = logic,
  parameter type r_chan_t = logic,
  parameter int unsigned NoMstPorts = 4
) (
  input logic clk_i,
  input logic rst_ni,
  output ar_chan_t ar_o,
  output logic ar_valid_o,
  input logic ar_ready_i,
  output logic [1:0] ar_select_o,
  input r_chan_t r_i,
  input logic r_valid_i,
  output logic r_ready_o
);

  typedef enum logic [1:0] {IDLE, SEND_AR, WAIT_R} state_t;
  state_t state;
  logic [31:0] cycle_count;
  logic [1:0] master_select;

  assign r_ready_o = 1'b1;
  assign ar_select_o = master_select;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
      state <= IDLE;
      ar_valid_o <= 0;
      ar_o <= '0;
      master_select <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      case (state)
        IDLE: begin
          ar_valid_o <= 0;
          if ((cycle_count != 0) && ((cycle_count & (cycle_count - 1)) == 0)) begin
            state <= SEND_AR;
          end
        end
        SEND_AR: begin
          ar_valid_o <= 1;
          ar_o.addr <= {master_select, 6'b0};
          if (ar_valid_o && ar_ready_i) begin
`ifdef AXI_DEMUX_READ_TB_TRACE
            $display("[Cycle %0d] Slave read ar addr %0d selected master %0d",
                     cycle_count, {master_select, 6'b0}, master_select);
`endif
            ar_valid_o <= 0;
            state <= WAIT_R;
          end
        end
        WAIT_R: begin
          if (r_valid_i) begin
`ifdef AXI_DEMUX_READ_TB_TRACE
            $display("[Cycle %0d] Slave received r data %0d",
                     cycle_count, r_i.data);
`endif
            master_select <= (master_select + 1) % NoMstPorts;
            state <= IDLE;
          end
        end
      endcase
    end
  end

`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
  wire f_ar_snd = (state == SEND_AR) && ar_valid_o && ar_ready_i;
  wire f_r_rcv  = (state == WAIT_R) && r_valid_i;   // r_ready_o is constant 1
  wire f_busy   = (state != IDLE);
`endif


endmodule

module axi_read_demux_master #(
  parameter type ar_chan_t = logic,
  parameter type r_chan_t = logic,
  parameter int unsigned MasterId = 0
) (
  input logic clk_i,
  input logic rst_ni,
  input ar_chan_t ar_i,
  input logic ar_valid_i,
  output logic ar_ready_o,
  output r_chan_t r_o,
  output logic r_valid_o,
  input logic r_ready_i
);

  typedef enum logic {IDLE, SEND_R} state_t;
  state_t state;
  logic [31:0] data_count;
  logic [31:0] cycle_count;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
      ar_ready_o <= 0;
      r_valid_o <= 0;
      r_o <= '0;
      data_count <= MasterId[31:0] * 32'd10;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      case (state)
        IDLE: begin
          ar_ready_o <= 1;
          r_valid_o <= 0;
          if (ar_valid_i) begin
`ifdef AXI_DEMUX_READ_TB_TRACE
            $display("[Cycle %0d] Master %0d received ar addr %0d",
                     cycle_count, MasterId, ar_i.addr);
`endif
            ar_ready_o <= 0;
            state <= SEND_R;
          end
        end
        SEND_R: begin
          r_valid_o <= 1;
          r_o.data <= data_count;
          r_o.resp <= 2'b00;
          if (r_valid_o && r_ready_i) begin
`ifdef AXI_DEMUX_READ_TB_TRACE
            $display("[Cycle %0d] Master %0d sent r data %0d",
                     cycle_count, MasterId, data_count);
`endif
            r_valid_o <= 0;
            data_count <= data_count + 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
  // The FSM commits on ar_valid_i alone (it does not look at ar_ready_o), so
  // an AR presented while ar_ready_o is low would be counted here but never
  // handshaken: the harness compares this against the wire-level handshake.
  wire f_ar_rcv = (state == IDLE) && ar_valid_i;
  wire f_r_snd  = (state == SEND_R) && r_valid_o && r_ready_i;
  wire f_busy   = (state != IDLE);
`endif


endmodule

module tb_axi_read_demux(input logic clk_i, input logic rst_ni);

  localparam int unsigned AxiAddrWidth = 8;
  localparam int unsigned AxiDataWidth = 8;
  localparam int unsigned AxiStrbWidth = AxiDataWidth / 8;
  localparam int unsigned NoMstPorts = 4;

  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] data_t;
  typedef logic [AxiStrbWidth-1:0] strb_t;
  typedef logic [1:0] select_t;

  `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
  `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)
  `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)
  `AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

  axi_req_t slv_req;
  axi_resp_t slv_resp;
  select_t ar_select;
  axi_req_t [NoMstPorts-1:0] mst_reqs;
  axi_resp_t [NoMstPorts-1:0] mst_resps;

  axi_lite_read_demux #(
    .ar_chan_t(ar_chan_t),
    .r_chan_t(r_chan_t),
    .axi_req_t(axi_req_t),
    .axi_resp_t(axi_resp_t),
    .NoMstPorts(NoMstPorts),
    .MaxTrans(8),
    .FallThrough(1'b0),
    .SpillAr(1'b0),
    .SpillR(1'b0),
    .select_t(select_t)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .test_i(1'b0),
    .slv_req_i(slv_req),
    .slv_ar_select_i(ar_select),
    .slv_resp_o(slv_resp),
    .mst_reqs_o(mst_reqs),
    .mst_resps_i(mst_resps)
  );

  axi_read_demux_slave #(
    .ar_chan_t(ar_chan_t),
    .r_chan_t(r_chan_t),
    .NoMstPorts(NoMstPorts)
  ) slave (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .ar_o(slv_req.ar),
    .ar_valid_o(slv_req.ar_valid),
    .ar_ready_i(slv_resp.ar_ready),
    .ar_select_o(ar_select),
    .r_i(slv_resp.r),
    .r_valid_i(slv_resp.r_valid),
    .r_ready_o(slv_req.r_ready)
  );
  assign slv_req.aw_valid = 1'b0;
  assign slv_req.aw = '0;
  assign slv_req.w_valid = 1'b0;
  assign slv_req.w = '0;
  assign slv_req.b_ready = 1'b0;

  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_masters
    axi_read_demux_master #(
      .ar_chan_t(ar_chan_t),
      .r_chan_t(r_chan_t),
      .MasterId(i)
    ) master (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ar_i(mst_reqs[i].ar),
      .ar_valid_i(mst_reqs[i].ar_valid),
      .ar_ready_o(mst_resps[i].ar_ready),
      .r_o(mst_resps[i].r),
      .r_valid_o(mst_resps[i].r_valid),
      .r_ready_i(mst_reqs[i].r_ready)
    );
    assign mst_resps[i].aw_ready = 1'b0;
    assign mst_resps[i].w_ready = 1'b0;
    assign mst_resps[i].b_valid = 1'b0;
    assign mst_resps[i].b = '0;
  end

endmodule
