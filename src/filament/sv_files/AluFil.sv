/* verilator lint_off UNOPTFLAT */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHCONCAT */
module AluFil (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni
);
  logic[0:0] _alu_le_input_l_valid;
  logic[31:0] _alu_le_input_l_0;
  logic[31:0] _alu_le_input_r_0;
  logic[0:0] _alu_le_input_op_0;
  logic[31:0] _alu_le_output_0;

  filaALU _spawn_01(
    .clk(clk_i),
    .reset(~rst_ni),
    .go(_alu_le_input_l_valid),
    .inA(_alu_le_input_l_0),
    .inB(_alu_le_input_r_0),
    .isAdd(~(_alu_le_input_op_0)),
    .out(_alu_le_output_0)
  ); 
  logic[31:0] cycle_count_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = cycle_count_q;
  localparam logic[31:0] thread_0_wire$1 = 32'd1;
  assign thread_0_wire$2 = thread_0_wire$0 + thread_0_wire$1;
  for (genvar i = 0; i < 2; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_1_1_q, _thread_0_event_counter_1_1_n;
  assign EVENTS0[1].event_current = _thread_0_event_counter_1_1_q;
  assign _thread_0_event_counter_1_1_n = EVENTS0[0].event_current;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[1].event_current;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      cycle_count_q <= '0;
      _thread_0_event_counter_1_1_q <= '0;
    end else begin
      if (EVENTS0[0].event_current) begin
        cycle_count_q[0 +: 32] <= thread_0_wire$2;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_1_1_q <= _thread_0_event_counter_1_1_n;
    end
  end
  localparam logic[31:0] thread_1_wire$0 = 32'd5;
  localparam logic[31:0] thread_1_wire$1 = 32'd5;
  localparam logic[31:0] thread_1_wire$2 = 32'd10;
  localparam logic[31:0] thread_1_wire$3 = 32'd5;
  localparam logic[31:0] thread_1_wire$4 = 32'd15;
  localparam logic[31:0] thread_1_wire$5 = 32'd5;
  localparam logic[31:0] thread_1_wire$6 = 32'd20;
  localparam logic[31:0] thread_1_wire$7 = 32'd5;
  localparam logic[31:0] thread_1_wire$8 = 32'd25;
  localparam logic[31:0] thread_1_wire$9 = 32'd5;
  for (genvar i = 0; i < 6; i ++) begin : EVENTS1
    logic event_current;
    end
  logic _init_1;
  logic[2:0] _thread_1_event_counter_5_q, _thread_1_event_counter_5_n;
  logic _thread_1_event_counter_4_1_q, _thread_1_event_counter_4_1_n;
  logic _thread_1_event_counter_3_1_q, _thread_1_event_counter_3_1_n;
  logic _thread_1_event_counter_2_1_q, _thread_1_event_counter_2_1_n;
  logic _thread_1_event_counter_1_1_q, _thread_1_event_counter_1_1_n;
  assign EVENTS1[5].event_current = _thread_1_event_counter_5_q == 3'd5;
    assign _thread_1_event_counter_5_n = EVENTS1[4].event_current ? 3'd1 : EVENTS1[5].event_current ? '0 : _thread_1_event_counter_5_q ? (_thread_1_event_counter_5_q + 3'd1) : _thread_1_event_counter_5_q;
  assign EVENTS1[4].event_current = _thread_1_event_counter_4_1_q;
  assign _thread_1_event_counter_4_1_n = EVENTS1[3].event_current;
  assign EVENTS1[3].event_current = _thread_1_event_counter_3_1_q;
  assign _thread_1_event_counter_3_1_n = EVENTS1[2].event_current;
  assign EVENTS1[2].event_current = _thread_1_event_counter_2_1_q;
  assign _thread_1_event_counter_2_1_n = EVENTS1[1].event_current;
  assign EVENTS1[1].event_current = _thread_1_event_counter_1_1_q;
  assign _thread_1_event_counter_1_1_n = EVENTS1[0].event_current;
  assign EVENTS1[0].event_current = _init_1 || EVENTS1[5].event_current;
  assign _alu_le_input_l_valid = EVENTS1[0].event_current || EVENTS1[1].event_current || EVENTS1[2].event_current || EVENTS1[3].event_current || EVENTS1[4].event_current;
  logic[2:0] _alu_le_input_r_valid_selector_q, _alu_le_input_r_valid_selector_n;
  assign _alu_le_input_r_0 = (_alu_le_input_r_valid_selector_n == 3'd0) ? thread_1_wire$1 : (_alu_le_input_r_valid_selector_n == 3'd1) ? thread_1_wire$3 : (_alu_le_input_r_valid_selector_n == 3'd2) ? thread_1_wire$5 : (_alu_le_input_r_valid_selector_n == 3'd3) ? thread_1_wire$7 : (_alu_le_input_r_valid_selector_n == 3'd4) ? thread_1_wire$9 : '0;
  logic[2:0] _alu_le_input_l_valid_selector_q, _alu_le_input_l_valid_selector_n;
  assign _alu_le_input_l_0 = (_alu_le_input_l_valid_selector_n == 3'd0) ? thread_1_wire$0 : (_alu_le_input_l_valid_selector_n == 3'd1) ? thread_1_wire$2 : (_alu_le_input_l_valid_selector_n == 3'd2) ? thread_1_wire$4 : (_alu_le_input_l_valid_selector_n == 3'd3) ? thread_1_wire$6 : (_alu_le_input_l_valid_selector_n == 3'd4) ? thread_1_wire$8 : '0;
  always_comb begin: _thread_1_selector
    _alu_le_input_r_valid_selector_n = _alu_le_input_r_valid_selector_q;
    if (EVENTS1[0].event_current) _alu_le_input_r_valid_selector_n = 3'd0;
    if (EVENTS1[1].event_current) _alu_le_input_r_valid_selector_n = 3'd1;
    if (EVENTS1[2].event_current) _alu_le_input_r_valid_selector_n = 3'd2;
    if (EVENTS1[3].event_current) _alu_le_input_r_valid_selector_n = 3'd3;
    if (EVENTS1[4].event_current) _alu_le_input_r_valid_selector_n = 3'd4;
    _alu_le_input_l_valid_selector_n = _alu_le_input_l_valid_selector_q;
    if (EVENTS1[0].event_current) _alu_le_input_l_valid_selector_n = 3'd0;
    if (EVENTS1[1].event_current) _alu_le_input_l_valid_selector_n = 3'd1;
    if (EVENTS1[2].event_current) _alu_le_input_l_valid_selector_n = 3'd2;
    if (EVENTS1[3].event_current) _alu_le_input_l_valid_selector_n = 3'd3;
    if (EVENTS1[4].event_current) _alu_le_input_l_valid_selector_n = 3'd4;
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_1_selector_trans
    if (~rst_ni) begin
      _alu_le_input_r_valid_selector_q <= '0;
      _alu_le_input_l_valid_selector_q <= '0;
    end else begin
      _alu_le_input_r_valid_selector_q <= _alu_le_input_r_valid_selector_n;
      _alu_le_input_l_valid_selector_q <= _alu_le_input_l_valid_selector_n;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_1_st_transition
    if (~rst_ni) begin
      _init_1 <= 1'b1;
      _thread_1_event_counter_5_q <= '0;
      _thread_1_event_counter_4_1_q <= '0;
      _thread_1_event_counter_3_1_q <= '0;
      _thread_1_event_counter_2_1_q <= '0;
      _thread_1_event_counter_1_1_q <= '0;
    end else begin
      if (EVENTS1[4].event_current) begin
      end
      if (EVENTS1[3].event_current) begin
      end
      if (EVENTS1[2].event_current) begin
      end
      if (EVENTS1[1].event_current) begin
      end
      if (EVENTS1[0].event_current) begin
      end
      _init_1 <= 1'b0;
      _thread_1_event_counter_5_q <= _thread_1_event_counter_5_n;
      _thread_1_event_counter_4_1_q <= _thread_1_event_counter_4_1_n;
      _thread_1_event_counter_3_1_q <= _thread_1_event_counter_3_1_n;
      _thread_1_event_counter_2_1_q <= _thread_1_event_counter_2_1_n;
      _thread_1_event_counter_1_1_q <= _thread_1_event_counter_1_1_n;
    end
  end
  localparam logic[0:0] thread_2_wire$0 = 1'd0;
  localparam logic[0:0] thread_2_wire$1 = 1'd1;
  localparam logic[0:0] thread_2_wire$2 = 1'd0;
  localparam logic[0:0] thread_2_wire$3 = 1'd1;
  localparam logic[0:0] thread_2_wire$4 = 1'd0;
  for (genvar i = 0; i < 7; i ++) begin : EVENTS2
    logic event_current;
    end
  logic _init_2;
  logic[2:0] _thread_2_event_counter_6_q, _thread_2_event_counter_6_n;
  logic _thread_2_event_counter_5_1_q, _thread_2_event_counter_5_1_n;
  logic _thread_2_event_counter_4_1_q, _thread_2_event_counter_4_1_n;
  logic _thread_2_event_counter_3_1_q, _thread_2_event_counter_3_1_n;
  logic _thread_2_event_counter_2_1_q, _thread_2_event_counter_2_1_n;
  logic[1:0] _thread_2_event_counter_1_q, _thread_2_event_counter_1_n;
  assign EVENTS2[6].event_current = _thread_2_event_counter_6_q == 3'd5;
    assign _thread_2_event_counter_6_n = EVENTS2[5].event_current ? 3'd1 : EVENTS2[6].event_current ? '0 : _thread_2_event_counter_6_q ? (_thread_2_event_counter_6_q + 3'd1) : _thread_2_event_counter_6_q;
  assign EVENTS2[5].event_current = _thread_2_event_counter_5_1_q;
  assign _thread_2_event_counter_5_1_n = EVENTS2[4].event_current;
  assign EVENTS2[4].event_current = _thread_2_event_counter_4_1_q;
  assign _thread_2_event_counter_4_1_n = EVENTS2[3].event_current;
  assign EVENTS2[3].event_current = _thread_2_event_counter_3_1_q;
  assign _thread_2_event_counter_3_1_n = EVENTS2[2].event_current;
  assign EVENTS2[2].event_current = _thread_2_event_counter_2_1_q;
  assign _thread_2_event_counter_2_1_n = EVENTS2[1].event_current;
  assign EVENTS2[1].event_current = _thread_2_event_counter_1_q == 2'd2;
    assign _thread_2_event_counter_1_n = EVENTS2[0].event_current ? 2'd1 : EVENTS2[1].event_current ? '0 : _thread_2_event_counter_1_q ? (_thread_2_event_counter_1_q + 2'd1) : _thread_2_event_counter_1_q;
  assign EVENTS2[0].event_current = _init_2 || EVENTS2[6].event_current;
  logic[2:0] _alu_le_input_op_valid_selector_q, _alu_le_input_op_valid_selector_n;
  assign _alu_le_input_op_0 = (_alu_le_input_op_valid_selector_n == 3'd0) ? thread_2_wire$0 : (_alu_le_input_op_valid_selector_n == 3'd1) ? thread_2_wire$1 : (_alu_le_input_op_valid_selector_n == 3'd2) ? thread_2_wire$2 : (_alu_le_input_op_valid_selector_n == 3'd3) ? thread_2_wire$3 : (_alu_le_input_op_valid_selector_n == 3'd4) ? thread_2_wire$4 : '0;
  always_comb begin: _thread_2_selector
    _alu_le_input_op_valid_selector_n = _alu_le_input_op_valid_selector_q;
    if (EVENTS2[1].event_current) _alu_le_input_op_valid_selector_n = 3'd0;
    if (EVENTS2[2].event_current) _alu_le_input_op_valid_selector_n = 3'd1;
    if (EVENTS2[3].event_current) _alu_le_input_op_valid_selector_n = 3'd2;
    if (EVENTS2[4].event_current) _alu_le_input_op_valid_selector_n = 3'd3;
    if (EVENTS2[5].event_current) _alu_le_input_op_valid_selector_n = 3'd4;
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_2_selector_trans
    if (~rst_ni) begin
      _alu_le_input_op_valid_selector_q <= '0;
    end else begin
      _alu_le_input_op_valid_selector_q <= _alu_le_input_op_valid_selector_n;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_2_st_transition
    if (~rst_ni) begin
      _init_2 <= 1'b1;
      _thread_2_event_counter_6_q <= '0;
      _thread_2_event_counter_5_1_q <= '0;
      _thread_2_event_counter_4_1_q <= '0;
      _thread_2_event_counter_3_1_q <= '0;
      _thread_2_event_counter_2_1_q <= '0;
      _thread_2_event_counter_1_q <= '0;
    end else begin
      if (EVENTS2[5].event_current) begin
      end
      if (EVENTS2[4].event_current) begin
      end
      if (EVENTS2[3].event_current) begin
      end
      if (EVENTS2[2].event_current) begin
      end
      if (EVENTS2[1].event_current) begin
      end
      _init_2 <= 1'b0;
      _thread_2_event_counter_6_q <= _thread_2_event_counter_6_n;
      _thread_2_event_counter_5_1_q <= _thread_2_event_counter_5_1_n;
      _thread_2_event_counter_4_1_q <= _thread_2_event_counter_4_1_n;
      _thread_2_event_counter_3_1_q <= _thread_2_event_counter_3_1_n;
      _thread_2_event_counter_2_1_q <= _thread_2_event_counter_2_1_n;
      _thread_2_event_counter_1_q <= _thread_2_event_counter_1_n;
    end
  end
  logic[31:0] thread_3_wire$9;
  logic[31:0] thread_3_wire$8;
  logic[31:0] thread_3_wire$7;
  logic[31:0] thread_3_wire$6;
  logic[31:0] thread_3_wire$5;
  logic[31:0] thread_3_wire$4;
  logic[31:0] thread_3_wire$3;
  logic[31:0] thread_3_wire$2;
  logic[31:0] thread_3_wire$1;
  logic[31:0] thread_3_wire$0;
  assign thread_3_wire$0 = _alu_le_output_0;
  assign thread_3_wire$1 = cycle_count_q;
  assign thread_3_wire$2 = _alu_le_output_0;
  assign thread_3_wire$3 = cycle_count_q;
  assign thread_3_wire$4 = _alu_le_output_0;
  assign thread_3_wire$5 = cycle_count_q;
  assign thread_3_wire$6 = _alu_le_output_0;
  assign thread_3_wire$7 = cycle_count_q;
  assign thread_3_wire$8 = _alu_le_output_0;
  assign thread_3_wire$9 = cycle_count_q;
  for (genvar i = 0; i < 6; i ++) begin : EVENTS3
    logic event_current;
    end
  logic _init_3;
  logic _thread_3_event_counter_5_1_q, _thread_3_event_counter_5_1_n;
  logic _thread_3_event_counter_4_1_q, _thread_3_event_counter_4_1_n;
  logic _thread_3_event_counter_3_1_q, _thread_3_event_counter_3_1_n;
  logic _thread_3_event_counter_2_1_q, _thread_3_event_counter_2_1_n;
  logic[1:0] _thread_3_event_counter_1_q, _thread_3_event_counter_1_n;
  assign EVENTS3[5].event_current = _thread_3_event_counter_5_1_q;
  assign _thread_3_event_counter_5_1_n = EVENTS3[4].event_current;
  assign EVENTS3[4].event_current = _thread_3_event_counter_4_1_q;
  assign _thread_3_event_counter_4_1_n = EVENTS3[3].event_current;
  assign EVENTS3[3].event_current = _thread_3_event_counter_3_1_q;
  assign _thread_3_event_counter_3_1_n = EVENTS3[2].event_current;
  assign EVENTS3[2].event_current = _thread_3_event_counter_2_1_q;
  assign _thread_3_event_counter_2_1_n = EVENTS3[1].event_current;
  assign EVENTS3[1].event_current = _thread_3_event_counter_1_q == 2'd2;
    assign _thread_3_event_counter_1_n = EVENTS3[0].event_current ? 2'd1 : EVENTS3[1].event_current ? '0 : _thread_3_event_counter_1_q ? (_thread_3_event_counter_1_q + 2'd1) : _thread_3_event_counter_1_q;
  assign EVENTS3[0].event_current = _init_3 || EVENTS3[5].event_current;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_3_st_transition
    if (~rst_ni) begin
      _init_3 <= 1'b1;
      _thread_3_event_counter_5_1_q <= '0;
      _thread_3_event_counter_4_1_q <= '0;
      _thread_3_event_counter_3_1_q <= '0;
      _thread_3_event_counter_2_1_q <= '0;
      _thread_3_event_counter_1_q <= '0;
    end else begin
      if (EVENTS3[5].event_current) begin
        $finish;
        $display("[Cycle %d] ALU Result for add (25+5): %d\n", thread_3_wire$9, thread_3_wire$8);
      end
      if (EVENTS3[4].event_current) begin
        $display("[Cycle %d] ALU Result for sub (20-5): %d\n", thread_3_wire$7, thread_3_wire$6);
      end
      if (EVENTS3[3].event_current) begin
        $display("[Cycle %d] ALU Result for add (15+5): %d\n", thread_3_wire$5, thread_3_wire$4);
      end
      if (EVENTS3[2].event_current) begin
        $display("[Cycle %d] ALU Result for sub (10-5): %d\n", thread_3_wire$3, thread_3_wire$2);
      end
      if (EVENTS3[1].event_current) begin
        $display("[Cycle %d] ALU Result for add (5+5): %d\n", thread_3_wire$1, thread_3_wire$0);
      end
      _init_3 <= 1'b0;
      _thread_3_event_counter_5_1_q <= _thread_3_event_counter_5_1_n;
      _thread_3_event_counter_4_1_q <= _thread_3_event_counter_4_1_n;
      _thread_3_event_counter_3_1_q <= _thread_3_event_counter_3_1_n;
      _thread_3_event_counter_2_1_q <= _thread_3_event_counter_2_1_n;
      _thread_3_event_counter_1_q <= _thread_3_event_counter_1_n;
    end
  end
endmodule
module Const #(
  parameter WIDTH = 32,
  parameter VALUE = 0
) (
  output wire logic [WIDTH-1:0] out
);
  assign out = VALUE;
endmodule

//// =========== Computation ============

module Add #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] left,
  input wire logic [IN_WIDTH-1:0] right,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = left + right;
endmodule

module Sub #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] left,
  input wire logic [IN_WIDTH-1:0] right,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = left - right;
endmodule

module MultComb #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] left,
  input wire logic [IN_WIDTH-1:0] right,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = left * right;
endmodule

//// =========== Binary Logical Operations ============

module And #(
  parameter WIDTH = 32
) (
  input wire logic [WIDTH-1:0] left,
  input wire logic [WIDTH-1:0] right,
  output wire logic [WIDTH-1:0] out
);
  assign out = left & right;
endmodule

module Or #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic [WIDTH-1:0] out
);
  assign out = left | right;
endmodule

module Xor #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic [WIDTH-1:0] out
);
  assign out = left ^ right;
endmodule

module Not #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] in,
  output wire logic [WIDTH-1:0] out
);
  assign out = ~in;
endmodule

//// =========== Comparions ============

module Gt #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left > right;
endmodule

module Eq #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left == right;
endmodule

module Neq #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left != right;
endmodule

module Lt #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left < right;
endmodule

module Gte #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left >= right;
endmodule

module Lte #(
  parameter WIDTH = 32
) (
  input wire logic  [WIDTH-1:0] left,
  input wire logic  [WIDTH-1:0] right,
  output wire logic out
);
  assign out = left <= right;
endmodule

//// =========== Extension ============

module SignExtend #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] in,
  output wire logic [OUT_WIDTH-1:0] out
);
  parameter EXTEND = OUT_WIDTH - IN_WIDTH;
  assign out = {{EXTEND{in[IN_WIDTH-1]}}, in};
endmodule

module ZeroExtend #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] in,
  output wire logic [OUT_WIDTH-1:0] out
);
  parameter EXTEND = OUT_WIDTH - IN_WIDTH;
  assign out = {{EXTEND{1'b0}}, in};
endmodule

module Extend #(
  parameter IN_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] in,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = {OUT_WIDTH{in}};
endmodule

module Concat #(
  parameter LEFT = 32,
  parameter RIGHT = 32,
  parameter OUT = 64
) (
  input wire logic [LEFT-1:0] left,
  input wire logic [RIGHT-1:0] right,
  output wire logic [OUT-1:0] out
);
  assign out = {left, right};
endmodule

//// =========== Select bits ============
module Select #(
  parameter WIDTH = 32,
  parameter POS = 0
) (
  input wire logic [WIDTH-1:0] in,
  output wire logic out
);
  assign out = in[POS];
endmodule

module Slice #(
  parameter IN_WIDTH = 32,
  parameter MSB = 31,
  parameter LSB = 0,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0] in,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = in[MSB:LSB];
endmodule

/// =========== Reduction Operations ============
module ReduceAnd #(
  parameter WIDTH = 32
) (
  input wire logic [WIDTH-1:0] in,
  output wire logic out
);
  assign out = &in;
endmodule

module ReduceOr #(
  parameter WIDTH = 32
) (
  input wire logic [WIDTH-1:0] in,
  output wire logic out
);
  assign out = |in;
endmodule

/// ========== Shift Operations ============
module ShiftLeft #(
  parameter WIDTH = 32,
  parameter SHIFT_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [WIDTH-1:0] in,
  input wire logic [SHIFT_WIDTH-1:0] shift,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = in << shift;
endmodule

module ShiftRight #(
  parameter WIDTH = 32,
  parameter SHIFT_WIDTH = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [WIDTH-1:0] in,
  input wire logic [SHIFT_WIDTH-1:0] shift,
  output wire logic [OUT_WIDTH-1:0] out
);
  assign out = in >> shift;
endmodule

module ArithShiftRight #(
  parameter WIDTH = 32
) (
  input wire logic signed [WIDTH-1:0] in,
  input wire logic [WIDTH-1:0] shift,
  output wire logic [WIDTH-1:0] out
); 
  assign out = in >>> shift;
endmodule

module Mux #(
  parameter WIDTH = 32
) (
  input wire logic sel,
  input wire logic [WIDTH-1:0] in0,
  input wire logic [WIDTH-1:0] in1,
  output logic [WIDTH-1:0] out
);
  assign out = sel ? in0 : in1;
endmodule
`default_nettype none

module Register #(
    parameter WIDTH = 32
) (
  input wire clk,
  input wire reset,
  input wire logic write_en,
  input wire logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);
  always_ff @(posedge clk) begin
    if (reset)
      out <= 0;
    else if (write_en)
      out <= in;
    else
      out <= out;
  end
endmodule

// Same as a register but does not have a write enable signal.
module Delay #(
    parameter WIDTH = 32
) (
  input wire clk,
  input wire reset,
  input wire logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);

  Register #(WIDTH) r (
    .clk(clk),
    .reset(reset),
    .write_en(1'b1),
    .in(in),
    .out(out)
  );
endmodule

// Register that passes its input value through.
module PassThroughRegister #(
  parameter WIDTH = 32
) (
  input wire clk,
  input wire reset,
  input wire logic write_en,
  input wire logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);
  // held register value
  logic [WIDTH-1:0] t_out;
  Register #(WIDTH) r (
    .clk(clk),
    .reset(reset),
    .write_en(write_en),
    .in(in),
    .out(t_out)
  );
  
  assign out = write_en ? in : t_out;
endmodule

// Similar to a register but provides access to its previous value only.
// Resetting behavior controlled using the SAFE parameter.
module Prev #(
    parameter WIDTH = 32,
    // If 0, reset to 'x, otherwise reset to 0
    parameter SAFE = 0
) (
  input wire clk,
  input wire reset,
  input wire logic write_en,
  input wire logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] prev
);
  always_ff @(posedge clk) begin
    if (reset)
      if (SAFE == 0)
        prev <= 'x;
      else
        prev <= '0;
    else if (write_en)
      prev <= in;
    else
      prev <= prev;
  end
endmodule

module ContPrev #(
    parameter WIDTH = 32,
    parameter SAFE = 0
) (
  input wire clk,
  input wire reset,
  input wire logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] prev
);

Prev #(WIDTH, SAFE) r (
  .clk(clk),
  .reset(reset),
  .write_en(1'b1),
  .in(in),
  .prev(prev)
);
endmodule


`default_nettype wire
module undef #(
    parameter WIDTH = 32
) (
   output logic [WIDTH-1:0] out
);
assign out = 'x;
endmodule

module std_const #(
    parameter WIDTH = 32,
    parameter VALUE = 32
) (
   output logic [WIDTH-1:0] out
);
assign out = VALUE;
endmodule

module std_wire #(
    parameter WIDTH = 32
) (
   input logic [WIDTH-1:0] in,
   output logic [WIDTH-1:0] out
);
assign out = in;
endmodule

module std_add #(
    parameter WIDTH = 32
) (
   input logic [WIDTH-1:0] left,
   input logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
assign out = left + right;
endmodule

module std_reg #(
    parameter WIDTH = 32
) (
   input logic [WIDTH-1:0] in,
   input logic write_en,
   input logic clk,
   input logic reset,
   output logic [WIDTH-1:0] out,
   output logic done
);
always_ff @(posedge clk) begin
    if (reset) begin
       out <= 0;
       done <= 0;
    end else if (write_en) begin
      out <= in;
      done <= 1'd1;
    end else done <= 1'd0;
  end
endmodule

module comp3(
  input logic [31:0] p14,
  input logic [31:0] p15,
  output logic [31:0] p16,
  input logic ev0,
  input logic clk,
  input logic reset
);
// COMPONENT START: comp3
logic ev00__0;
logic ev00__1;
logic ev00__2;
logic ev00_clk;
logic ev00_reset;
logic ev00_go;
logic ev00_done;
logic [31:0] inst0_in;
logic [31:0] inst0_out;
logic inst0_clk;
logic inst0_reset;
logic inst0_write_en;
logic [31:0] inst1_in;
logic [31:0] inst1_out;
logic inst1_clk;
logic inst1_reset;
logic inst1_write_en;
logic [31:0] inst2_in;
logic [31:0] inst2_out;
logic inst2_clk;
logic inst2_reset;
logic inst2_write_en;
logic [31:0] inst3_in;
logic [31:0] inst3_out;
logic inst3_clk;
logic inst3_reset;
logic inst3_write_en;
logic [31:0] inst4_left;
logic [31:0] inst4_right;
logic [31:0] inst4_out;
fsm_3 ev00 (
    ._0(ev00__0),
    ._1(ev00__1),
    ._2(ev00__2),
    .clk(ev00_clk),
    .done(ev00_done),
    .go(ev00_go),
    .reset(ev00_reset)
);
Register # (
    .WIDTH(32)
) inst0 (
    .clk(inst0_clk),
    .in(inst0_in),
    .out(inst0_out),
    .reset(inst0_reset),
    .write_en(inst0_write_en)
);
Register # (
    .WIDTH(32)
) inst1 (
    .clk(inst1_clk),
    .in(inst1_in),
    .out(inst1_out),
    .reset(inst1_reset),
    .write_en(inst1_write_en)
);
Register # (
    .WIDTH(32)
) inst2 (
    .clk(inst2_clk),
    .in(inst2_in),
    .out(inst2_out),
    .reset(inst2_reset),
    .write_en(inst2_write_en)
);
Register # (
    .WIDTH(32)
) inst3 (
    .clk(inst3_clk),
    .in(inst3_in),
    .out(inst3_out),
    .reset(inst3_reset),
    .write_en(inst3_write_en)
);
Sub # (
    .IN_WIDTH(32),
    .OUT_WIDTH(32)
) inst4 (
    .left(inst4_left),
    .out(inst4_out),
    .right(inst4_right)
);
wire _guard0 = 1;
wire _guard1 = ev00__2;
wire _guard2 = ev00__1;
wire _guard3 = ev00__1;
wire _guard4 = ev00__0;
wire _guard5 = ev00__0;
wire _guard6 = ev00__0;
wire _guard7 = ev00__0;
wire _guard8 = ev00__1;
wire _guard9 = ev00__1;
wire _guard10 = ev00__2;
wire _guard11 = ev00__2;
assign p16 =
  _guard1 ? inst4_out :
  32'd0;
assign inst3_write_en = _guard2;
assign inst3_clk = clk;
assign inst3_reset = reset;
assign inst3_in = inst1_out;
assign inst1_write_en = _guard4;
assign inst1_clk = clk;
assign inst1_reset = reset;
assign inst1_in = p15;
assign inst0_write_en = _guard6;
assign inst0_clk = clk;
assign inst0_reset = reset;
assign inst0_in = p14;
assign ev00_clk = clk;
assign ev00_go = ev0;
assign ev00_reset = reset;
assign inst2_write_en = _guard8;
assign inst2_clk = clk;
assign inst2_reset = reset;
assign inst2_in = inst0_out;
assign inst4_left = inst2_out;
assign inst4_right = inst3_out;
// COMPONENT END: comp3
endmodule
module filaALU(
  input logic [31:0] inA,
  input logic [31:0] inB,
  input logic isAdd,
  output logic [31:0] out,
  input logic go,
  input logic clk,
  input logic reset
);
// COMPONENT START: main
logic go0__0;
logic go0__1;
logic go0__2;
logic go0_clk;
logic go0_reset;
logic go0_go;
logic go0_done;
logic [31:0] inst0_left;
logic [31:0] inst0_right;
logic [31:0] inst0_out;
logic [31:0] inst1_in;
logic [31:0] inst1_out;
logic inst1_clk;
logic inst1_reset;
logic inst1_write_en;
logic [31:0] inst2_p14;
logic [31:0] inst2_p15;
logic [31:0] inst2_p16;
logic inst2_ev0;
logic inst2_clk;
logic inst2_reset;
logic [31:0] inst3_in;
logic [31:0] inst3_out;
logic inst3_clk;
logic inst3_reset;
logic inst3_write_en;
logic inst4_sel;
logic [31:0] inst4_in0;
logic [31:0] inst4_in1;
logic [31:0] inst4_out;
fsm_3 go0 (
    ._0(go0__0),
    ._1(go0__1),
    ._2(go0__2),
    .clk(go0_clk),
    .done(go0_done),
    .go(go0_go),
    .reset(go0_reset)
);
Add # (
    .IN_WIDTH(32),
    .OUT_WIDTH(32)
) inst0 (
    .left(inst0_left),
    .out(inst0_out),
    .right(inst0_right)
);
Register # (
    .WIDTH(32)
) inst1 (
    .clk(inst1_clk),
    .in(inst1_in),
    .out(inst1_out),
    .reset(inst1_reset),
    .write_en(inst1_write_en)
);
comp3 inst2 (
    .clk(inst2_clk),
    .ev0(inst2_ev0),
    .p14(inst2_p14),
    .p15(inst2_p15),
    .p16(inst2_p16),
    .reset(inst2_reset)
);
Register # (
    .WIDTH(32)
) inst3 (
    .clk(inst3_clk),
    .in(inst3_in),
    .out(inst3_out),
    .reset(inst3_reset),
    .write_en(inst3_write_en)
);
Mux # (
    .WIDTH(32)
) inst4 (
    .in0(inst4_in0),
    .in1(inst4_in1),
    .out(inst4_out),
    .sel(inst4_sel)
);
wire _guard0 = 1;
wire _guard1 = go0__2;
wire _guard2 = go0__1;
wire _guard3 = go0__1;
wire _guard4 = go0__0;
wire _guard5 = go0__0;
wire _guard6 = go0__0;
wire _guard7 = go0__0;
wire _guard8 = go0__0;
wire _guard9 = go0__0;
wire _guard10 = go0__0;
wire _guard11 = go0__2;
wire _guard12 = go0__2;
wire _guard13 = go0__2;
assign out =
  _guard1 ? inst4_out :
  32'd0;
assign go0_clk = clk;
assign go0_go = go;
assign go0_reset = reset;
assign inst3_write_en = _guard2;
assign inst3_clk = clk;
assign inst3_reset = reset;
assign inst3_in = inst1_out;
assign inst1_write_en = _guard4;
assign inst1_clk = clk;
assign inst1_reset = reset;
assign inst1_in = inst0_out;
assign inst0_left = inA;
assign inst0_right = inB;
assign inst2_ev0 = _guard8;
assign inst2_p15 = inB;
assign inst2_clk = clk;
assign inst2_reset = reset;
assign inst2_p14 = inA;
assign inst4_in1 = inst2_p16;
assign inst4_in0 = inst3_out;
assign inst4_sel = isAdd;
// COMPONENT END: main
endmodule
module fsm_3(
  output logic _0,
  output logic _1,
  output logic _2,
  input logic clk,
  input logic reset,
  input logic go,
  output logic done
);
// COMPONENT START: fsm_3
logic r_in;
logic r_write_en;
logic r_clk;
logic r_reset;
logic r_out;
logic r_done;
logic r0_in;
logic r0_write_en;
logic r0_clk;
logic r0_reset;
logic r0_out;
logic r0_done;
logic r1_in;
logic r1_write_en;
logic r1_clk;
logic r1_reset;
logic r1_out;
logic r1_done;
std_reg # (
    .WIDTH(1)
) r (
    .clk(r_clk),
    .done(r_done),
    .in(r_in),
    .out(r_out),
    .reset(r_reset),
    .write_en(r_write_en)
);
std_reg # (
    .WIDTH(1)
) r0 (
    .clk(r0_clk),
    .done(r0_done),
    .in(r0_in),
    .out(r0_out),
    .reset(r0_reset),
    .write_en(r0_write_en)
);
std_reg # (
    .WIDTH(1)
) r1 (
    .clk(r1_clk),
    .done(r1_done),
    .in(r1_in),
    .out(r1_out),
    .reset(r1_reset),
    .write_en(r1_write_en)
);
wire _guard0 = 1;
assign done = r1_out;
assign _2 = r0_out;
assign _1 = r_out;
assign _0 = go;
assign r_write_en = 1'd1;
assign r_clk = clk;
assign r_reset = reset;
assign r_in = go;
assign r0_write_en = 1'd1;
assign r0_clk = clk;
assign r0_reset = reset;
assign r0_in = r_out;
assign r1_write_en = 1'd1;
assign r1_clk = clk;
assign r1_reset = reset;
assign r1_in = r0_out;
// COMPONENT END: fsm_3
endmodule