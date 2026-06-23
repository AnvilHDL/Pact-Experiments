// AXI4-Lite Write Mux Testbench
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module axi_write_slave #(
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type b_chan_t = logic,
  parameter int unsigned SlaveId = 0
) (
  input logic clk_i,
  input logic rst_ni,
  output aw_chan_t aw_o,
  output logic aw_valid_o,
  input logic aw_ready_i,
  output w_chan_t w_o,
  output logic w_valid_o,
  input logic w_ready_i,
  input b_chan_t b_i,
  input logic b_valid_i,
  output logic b_ready_o
);

  typedef enum logic [1:0] {IDLE, SEND_AW, SEND_W, WAIT_B} state_t;
  state_t state;
  logic [31:0] cycle_count;
  logic [7:0] data_count;

  assign b_ready_o = 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
      state <= IDLE;
      aw_valid_o <= 0;
      w_valid_o <= 0;
      aw_o <= '0;
      w_o <= '0;
      data_count <= SlaveId[7:0];
    end else begin
      cycle_count <= cycle_count + 1;
      case (state)
        IDLE: begin
          aw_valid_o <= 0;
          w_valid_o <= 0;
          if ((cycle_count != 0) && ((cycle_count & (cycle_count - 1)) == 0)) begin
            state <= SEND_AW;
          end
        end
        SEND_AW: begin
          aw_valid_o <= 1;
          aw_o.addr <= {SlaveId[7:0]};
          if (aw_valid_o && aw_ready_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Slave %0d write aw addr %0d selected",
                     cycle_count, SlaveId, SlaveId[7:0]);
`endif
            aw_valid_o <= 0;
            state <= SEND_W;
          end
        end
        SEND_W: begin
          w_valid_o <= 1;
          w_o.data <= data_count;
          w_o.strb <= 1'b1;
          if (w_valid_o && w_ready_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Slave %0d write data %0d granted",
                     cycle_count, SlaveId, data_count);
`endif
            w_valid_o <= 0;
            data_count <= data_count + 1;
            state <= WAIT_B;
          end
        end
        WAIT_B: begin
          if (b_valid_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Slave %0d write response received",
                     cycle_count, SlaveId);
`endif
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

module axi_write_master #(
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type b_chan_t = logic
) (
  input logic clk_i,
  input logic rst_ni,
  input aw_chan_t aw_i,
  input logic aw_valid_i,
  output logic aw_ready_o,
  input w_chan_t w_i,
  input logic w_valid_i,
  output logic w_ready_o,
  output b_chan_t b_o,
  output logic b_valid_o,
  input logic b_ready_i
);

  typedef enum logic [1:0] {IDLE, RECV_AW, RECV_W, SEND_B} state_t;
  state_t state;
  logic [31:0] cycle_count;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
      aw_ready_o <= 0;
      w_ready_o <= 0;
      b_valid_o <= 0;
      b_o <= '0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      case (state)
        IDLE: begin
          aw_ready_o <= 1;
          w_ready_o <= 0;
          b_valid_o <= 0;
          if (aw_ready_o && aw_valid_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Master received aw req with addr %0d",
                     cycle_count, aw_i.addr);
`endif
            aw_ready_o <= 0;
            state <= RECV_W;
          end
        end
        RECV_W: begin
          aw_ready_o <= 0;
          w_ready_o <= 1;
          if (w_ready_o && w_valid_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Master received w req with data %0d",
                     cycle_count, w_i.data);
`endif
            w_ready_o <= 0;
            state <= SEND_B;
          end
        end
        SEND_B: begin
          b_valid_o <= 1;
          b_o.resp <= 2'b00;
          if (b_valid_o && b_ready_i) begin
`ifdef AXI_MUX_WRITE_TB_TRACE
            $display("[Cycle %0d] Master sent b response",
                     cycle_count);
`endif
            b_valid_o <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

module tb_axi_write_mux(input logic clk_i, input logic rst_ni);

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

  axi_lite_write_mux #(
    .aw_chan_t(aw_chan_t),
    .w_chan_t(w_chan_t),
    .b_chan_t(b_chan_t),
    .axi_req_t(axi_req_t),
    .axi_resp_t(axi_resp_t),
    .NoSlvPorts(NoSlvPorts),
    .MaxTrans(8),
    .FallThrough(1'b0),
    .SpillAw(1'b0),
    .SpillW(1'b0),
    .SpillB(1'b0)
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
    axi_write_slave #(
      .aw_chan_t(aw_chan_t),
      .w_chan_t(w_chan_t),
      .b_chan_t(b_chan_t),
      .SlaveId(i)
    ) slave (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .aw_o(slv_reqs[i].aw),
      .aw_valid_o(slv_reqs[i].aw_valid),
      .aw_ready_i(slv_resps[i].aw_ready),
      .w_o(slv_reqs[i].w),
      .w_valid_o(slv_reqs[i].w_valid),
      .w_ready_i(slv_resps[i].w_ready),
      .b_i(slv_resps[i].b),
      .b_valid_i(slv_resps[i].b_valid),
      .b_ready_o(slv_reqs[i].b_ready)
    );
    assign slv_reqs[i].ar_valid = 1'b0;
    assign slv_reqs[i].ar = '0;
    assign slv_reqs[i].r_ready = 1'b0;
  end

  axi_write_master #(
    .aw_chan_t(aw_chan_t),
    .w_chan_t(w_chan_t),
    .b_chan_t(b_chan_t)
  ) master (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .aw_i(mst_req.aw),
    .aw_valid_i(mst_req.aw_valid),
    .aw_ready_o(mst_resp.aw_ready),
    .w_i(mst_req.w),
    .w_valid_i(mst_req.w_valid),
    .w_ready_o(mst_resp.w_ready),
    .b_o(mst_resp.b),
    .b_valid_o(mst_resp.b_valid),
    .b_ready_i(mst_req.b_ready)
  );
  assign mst_resp.ar_ready = 1'b0;
  assign mst_resp.r_valid = 1'b0;
  assign mst_resp.r = '0;

endmodule
