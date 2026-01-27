// AXI4-Lite Write Demux Testbench
`include "axi/typedef.svh"
`include "common_cells/registers.svh"

module axi_write_demux_slave #(
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type b_chan_t = logic,
  parameter int unsigned NoMstPorts = 4
) (
  input logic clk_i,
  input logic rst_ni,
  output aw_chan_t aw_o,
  output logic aw_valid_o,
  input logic aw_ready_i,
  output logic [1:0] aw_select_o,
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
  logic [1:0] master_select;

  assign b_ready_o = 1'b1;
  assign aw_select_o = master_select;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
      state <= IDLE;
      aw_valid_o <= 0;
      w_valid_o <= 0;
      aw_o <= '0;
      w_o <= '0;
      data_count <= 0;
      master_select <= 0;
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
          aw_o.addr <= {master_select, 6'b0};
          if (aw_ready_i) begin
            aw_valid_o <= 0;
            state <= SEND_W;
          end
        end
        SEND_W: begin
          w_valid_o <= 1;
          w_o.data <= data_count;
          w_o.strb <= 1'b1;
          if (w_ready_i) begin
            w_valid_o <= 0;
            data_count <= data_count + 1;
            state <= WAIT_B;
          end
        end
        WAIT_B: begin
          if (b_valid_i) begin
            master_select <= (master_select + 1) % NoMstPorts;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

module axi_write_demux_master #(
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type b_chan_t = logic,
  parameter int unsigned MasterId = 0
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

  typedef enum logic [1:0] {IDLE, RECV_W, SEND_B} state_t;
  state_t state;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
      aw_ready_o <= 0;
      w_ready_o <= 0;
      b_valid_o <= 0;
      b_o <= '0;
    end else begin
      case (state)
        IDLE: begin
          aw_ready_o <= 1;
          w_ready_o <= 0;
          b_valid_o <= 0;
          if (aw_valid_i) begin
            state <= RECV_W;
          end
        end
        RECV_W: begin
          aw_ready_o <= 0;
          w_ready_o <= 1;
          if (w_valid_i) begin
            w_ready_o <= 0;
            state <= SEND_B;
          end
        end
        SEND_B: begin
          b_valid_o <= 1;
          b_o.resp <= 2'b00;
          if (b_ready_i) begin
            b_valid_o <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule

module tb_axi_write_demux(input logic clk_i, input logic rst_ni);

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
  select_t aw_select;
  axi_req_t [NoMstPorts-1:0] mst_reqs;
  axi_resp_t [NoMstPorts-1:0] mst_resps;

  axi_lite_write_demux #(
    .aw_chan_t(aw_chan_t),
    .w_chan_t(w_chan_t),
    .b_chan_t(b_chan_t),
    .axi_req_t(axi_req_t),
    .axi_resp_t(axi_resp_t),
    .NoMstPorts(NoMstPorts),
    .MaxTrans(8),
    .FallThrough(1'b0),
    .SpillAw(1'b0),
    .SpillW(1'b0),
    .SpillB(1'b0),
    .select_t(select_t)
  ) dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .test_i(1'b0),
    .slv_req_i(slv_req),
    .slv_aw_select_i(aw_select),
    .slv_resp_o(slv_resp),
    .mst_reqs_o(mst_reqs),
    .mst_resps_i(mst_resps)
  );

  axi_write_demux_slave #(
    .aw_chan_t(aw_chan_t),
    .w_chan_t(w_chan_t),
    .b_chan_t(b_chan_t),
    .NoMstPorts(NoMstPorts)
  ) slave (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .aw_o(slv_req.aw),
    .aw_valid_o(slv_req.aw_valid),
    .aw_ready_i(slv_resp.aw_ready),
    .aw_select_o(aw_select),
    .w_o(slv_req.w),
    .w_valid_o(slv_req.w_valid),
    .w_ready_i(slv_resp.w_ready),
    .b_i(slv_resp.b),
    .b_valid_i(slv_resp.b_valid),
    .b_ready_o(slv_req.b_ready)
  );
  assign slv_req.ar_valid = 1'b0;
  assign slv_req.ar = '0;
  assign slv_req.r_ready = 1'b0;

  for (genvar i = 0; i < NoMstPorts; i++) begin : gen_masters
    axi_write_demux_master #(
      .aw_chan_t(aw_chan_t),
      .w_chan_t(w_chan_t),
      .b_chan_t(b_chan_t),
      .MasterId(i)
    ) master (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .aw_i(mst_reqs[i].aw),
      .aw_valid_i(mst_reqs[i].aw_valid),
      .aw_ready_o(mst_resps[i].aw_ready),
      .w_i(mst_reqs[i].w),
      .w_valid_i(mst_reqs[i].w_valid),
      .w_ready_o(mst_resps[i].w_ready),
      .b_o(mst_resps[i].b),
      .b_valid_o(mst_resps[i].b_valid),
      .b_ready_i(mst_reqs[i].b_ready)
    );
    assign mst_resps[i].ar_ready = 1'b0;
    assign mst_resps[i].r_valid = 1'b0;
    assign mst_resps[i].r = '0;
  end

endmodule
