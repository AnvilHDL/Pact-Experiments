// AXI4-Lite Read Mux Testbench
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module axi_read_slave #(
  parameter type ar_chan_t = logic,
  parameter type r_chan_t = logic,
  parameter int unsigned SlaveId = 0
) (
  input logic clk_i,
  input logic rst_ni,
  output ar_chan_t ar_o,
  output logic ar_valid_o,
  input logic ar_ready_i,
  input r_chan_t r_i,
  input logic r_valid_i,
  output logic r_ready_o
);

  typedef enum logic [1:0] {IDLE, SEND_AR, WAIT_R} state_t;
  state_t state;
  logic [31:0] cycle_count;

  assign r_ready_o = 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
      state <= IDLE;
      ar_valid_o <= 0;
      ar_o <= '0;
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
          ar_o.addr <= {SlaveId[7:0]};
          if (ar_valid_o && ar_ready_i) begin
`ifdef AXI_MUX_READ_TB_TRACE
            $display("[Cycle %0d] Slave %0d read req selected with addr %0d",
                     cycle_count, SlaveId, SlaveId[7:0]);
`endif
            ar_valid_o <= 0;
            state <= WAIT_R;
          end
        end
        WAIT_R: begin
          if (r_valid_i) begin
`ifdef AXI_MUX_READ_TB_TRACE
            $display("[Cycle %0d] Slave %0d read response received with data %0d",
                     cycle_count, SlaveId, r_i.data);
`endif
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

module axi_read_master #(
  parameter type ar_chan_t = logic,
  parameter type r_chan_t = logic
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
      data_count <= 0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      case (state)
        IDLE: begin
          ar_ready_o <= 1;
          r_valid_o <= 0;
          if (ar_ready_o && ar_valid_i) begin
`ifdef AXI_MUX_READ_TB_TRACE
            $display("[Cycle %0d] Master received ar req with addr %0d",
                     cycle_count, ar_i.addr);
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
`ifdef AXI_MUX_READ_TB_TRACE
            $display("[Cycle %0d] Master sent r res with data %0d",
                     cycle_count, data_count);
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
  wire f_ar_rcv = (state == IDLE) && ar_ready_o && ar_valid_i;
  wire f_r_snd  = (state == SEND_R) && r_valid_o && r_ready_i;
  wire f_busy   = (state != IDLE);
`endif


endmodule

module tb_axi_read_mux(input logic clk_i, input logic rst_ni);

  localparam int unsigned AxiAddrWidth = 8;
  localparam int unsigned AxiDataWidth = 8;
  localparam int unsigned AxiStrbWidth = AxiDataWidth / 8;
  localparam int unsigned NoSlvPorts = 4;

  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] data_t;
  typedef logic [AxiStrbWidth-1:0] strb_t;

  `AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
  `AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)
  `AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
  `AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)
  `AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

  axi_req_t [NoSlvPorts-1:0] slv_reqs;
  axi_resp_t [NoSlvPorts-1:0] slv_resps;
  axi_req_t mst_req;
  axi_resp_t mst_resp;

  axi_lite_read_mux #(
    .ar_chan_t(ar_chan_t),
    .r_chan_t(r_chan_t),
    .axi_req_t(axi_req_t),
    .axi_resp_t(axi_resp_t),
    .NoSlvPorts(NoSlvPorts),
    .MaxTrans(8),
    .FallThrough(1'b0),
    .SpillAr(1'b0),
    .SpillR(1'b0)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .test_i(1'b0),
    .slv_reqs_i(slv_reqs),
    .slv_resps_o(slv_resps),
    .mst_req_o(mst_req),
    .mst_resp_i(mst_resp)
  );

  for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_slaves
    axi_read_slave #(
      .ar_chan_t(ar_chan_t),
      .r_chan_t(r_chan_t),
      .SlaveId(i)
    ) slave (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .ar_o(slv_reqs[i].ar),
      .ar_valid_o(slv_reqs[i].ar_valid),
      .ar_ready_i(slv_resps[i].ar_ready),
      .r_i(slv_resps[i].r),
      .r_valid_i(slv_resps[i].r_valid),
      .r_ready_o(slv_reqs[i].r_ready)
    );
    assign slv_reqs[i].aw_valid = 1'b0;
    assign slv_reqs[i].aw = '0;
    assign slv_reqs[i].w_valid = 1'b0;
    assign slv_reqs[i].w = '0;
    assign slv_reqs[i].b_ready = 1'b0;
  end

  axi_read_master #(
    .ar_chan_t(ar_chan_t),
    .r_chan_t(r_chan_t)
  ) master (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .ar_i(mst_req.ar),
    .ar_valid_i(mst_req.ar_valid),
    .ar_ready_o(mst_resp.ar_ready),
    .r_o(mst_resp.r),
    .r_valid_o(mst_resp.r_valid),
    .r_ready_i(mst_req.r_ready)
  );
  assign mst_resp.aw_ready = 1'b0;
  assign mst_resp.w_ready = 1'b0;
  assign mst_resp.b_valid = 1'b0;
  assign mst_resp.b = '0;

endmodule
