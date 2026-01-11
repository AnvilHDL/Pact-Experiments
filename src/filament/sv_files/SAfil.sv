/* verilator lint_off UNOPTFLAT */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHCONCAT */
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
logic ev00__3;
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
logic [31:0] inst2_left;
logic [31:0] inst2_right;
logic [31:0] inst2_out;
logic [31:0] inst3_in;
logic [31:0] inst3_out;
logic inst3_clk;
logic inst3_reset;
logic inst3_write_en;
logic [31:0] inst4_in;
logic [31:0] inst4_out;
logic inst4_clk;
logic inst4_reset;
logic inst4_write_en;
fsm_4 ev00 (
    ._0(ev00__0),
    ._1(ev00__1),
    ._2(ev00__2),
    ._3(ev00__3),
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
Add # (
    .IN_WIDTH(32),
    .OUT_WIDTH(32)
) inst2 (
    .left(inst2_left),
    .out(inst2_out),
    .right(inst2_right)
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
Register # (
    .WIDTH(32)
) inst4 (
    .clk(inst4_clk),
    .in(inst4_in),
    .out(inst4_out),
    .reset(inst4_reset),
    .write_en(inst4_write_en)
);
wire _guard0 = 1;
wire _guard1 = ev00__3;
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
assign inst3_in = inst2_out;
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
assign inst2_left = inst0_out;
assign inst2_right = inst1_out;
assign inst4_write_en = _guard10;
assign inst4_clk = clk;
assign inst4_reset = reset;
assign inst4_in = inst3_out;
// COMPONENT END: comp3
endmodule
module comp4(
  input logic [31:0] p11,
  input logic [31:0] p12,
  output logic [31:0] p13,
  input logic ev0,
  input logic clk,
  input logic reset
);
// COMPONENT START: comp4
logic ev00__0;
logic ev00__1;
logic ev00__2;
logic ev00__3;
logic ev00_clk;
logic ev00_reset;
logic ev00_go;
logic ev00_done;
logic [31:0] inst0_in;
logic [31:0] inst0_prev;
logic inst0_clk;
logic inst0_reset;
logic inst0_write_en;
logic [31:0] inst1_p14;
logic [31:0] inst1_p15;
logic [31:0] inst1_p16;
logic inst1_ev0;
logic inst1_clk;
logic inst1_reset;
logic [31:0] inst2_left;
logic [31:0] inst2_right;
logic [31:0] inst2_out;
fsm_4 ev00 (
    ._0(ev00__0),
    ._1(ev00__1),
    ._2(ev00__2),
    ._3(ev00__3),
    .clk(ev00_clk),
    .done(ev00_done),
    .go(ev00_go),
    .reset(ev00_reset)
);
Prev # (
    .SAFE(1),
    .WIDTH(32)
) inst0 (
    .clk(inst0_clk),
    .in(inst0_in),
    .prev(inst0_prev),
    .reset(inst0_reset),
    .write_en(inst0_write_en)
);
comp3 inst1 (
    .clk(inst1_clk),
    .ev0(inst1_ev0),
    .p14(inst1_p14),
    .p15(inst1_p15),
    .p16(inst1_p16),
    .reset(inst1_reset)
);
Add # (
    .IN_WIDTH(32),
    .OUT_WIDTH(32)
) inst2 (
    .left(inst2_left),
    .out(inst2_out),
    .right(inst2_right)
);
wire _guard0 = 1;
wire _guard1 = ev00__3;
wire _guard2 = ev00__0;
wire _guard3 = ev00__0;
wire _guard4 = ev00__0;
wire _guard5 = ev00__3;
wire _guard6 = ev00__3;
wire _guard7 = ev00__3;
wire _guard8 = ev00__3;
assign p13 =
  _guard1 ? inst2_out :
  32'd0;
assign inst1_ev0 = _guard2;
assign inst1_p15 = p12;
assign inst1_clk = clk;
assign inst1_reset = reset;
assign inst1_p14 = p11;
assign inst0_write_en = _guard5;
assign inst0_clk = clk;
assign inst0_reset = reset;
assign inst0_in = inst2_out;
assign ev00_clk = clk;
assign ev00_go = ev0;
assign ev00_reset = reset;
assign inst2_left = inst0_prev;
assign inst2_right = inst1_p16;
// COMPONENT END: comp4
endmodule
module main(
  input logic [31:0] l0,
  input logic [31:0] l1,
  input logic [31:0] t0,
  input logic [31:0] t1,
  output logic [31:0] out00,
  output logic [31:0] out01,
  output logic [31:0] out10,
  output logic [31:0] out11,
  input logic go,
  input logic reset,
  input logic clk
);
// COMPONENT START: main
logic go0__0;
logic go0__1;
logic go0__2;
logic go0__3;
logic go0_clk;
logic go0_reset;
logic go0_go;
logic go0_done;
logic [31:0] inst0_in;
logic [31:0] inst0_prev;
logic inst0_clk;
logic inst0_reset;
logic inst0_write_en;
logic [31:0] inst1_in;
logic [31:0] inst1_prev;
logic inst1_clk;
logic inst1_reset;
logic inst1_write_en;
logic [31:0] inst2_in;
logic [31:0] inst2_prev;
logic inst2_clk;
logic inst2_reset;
logic inst2_write_en;
logic [31:0] inst3_in;
logic [31:0] inst3_prev;
logic inst3_clk;
logic inst3_reset;
logic inst3_write_en;
logic [31:0] inst4_p11;
logic [31:0] inst4_p12;
logic [31:0] inst4_p13;
logic inst4_ev0;
logic inst4_clk;
logic inst4_reset;
logic [31:0] inst5_p11;
logic [31:0] inst5_p12;
logic [31:0] inst5_p13;
logic inst5_ev0;
logic inst5_clk;
logic inst5_reset;
logic [31:0] inst6_p11;
logic [31:0] inst6_p12;
logic [31:0] inst6_p13;
logic inst6_ev0;
logic inst6_clk;
logic inst6_reset;
logic [31:0] inst7_p11;
logic [31:0] inst7_p12;
logic [31:0] inst7_p13;
logic inst7_ev0;
logic inst7_clk;
logic inst7_reset;
fsm_4 go0 (
    ._0(go0__0),
    ._1(go0__1),
    ._2(go0__2),
    ._3(go0__3),
    .clk(go0_clk),
    .done(go0_done),
    .go(go0_go),
    .reset(go0_reset)
);
Prev # (
    .SAFE(1),
    .WIDTH(32)
) inst0 (
    .clk(inst0_clk),
    .in(inst0_in),
    .prev(inst0_prev),
    .reset(inst0_reset),
    .write_en(inst0_write_en)
);
Prev # (
    .SAFE(1),
    .WIDTH(32)
) inst1 (
    .clk(inst1_clk),
    .in(inst1_in),
    .prev(inst1_prev),
    .reset(inst1_reset),
    .write_en(inst1_write_en)
);
Prev # (
    .SAFE(1),
    .WIDTH(32)
) inst2 (
    .clk(inst2_clk),
    .in(inst2_in),
    .prev(inst2_prev),
    .reset(inst2_reset),
    .write_en(inst2_write_en)
);
Prev # (
    .SAFE(1),
    .WIDTH(32)
) inst3 (
    .clk(inst3_clk),
    .in(inst3_in),
    .prev(inst3_prev),
    .reset(inst3_reset),
    .write_en(inst3_write_en)
);
comp4 inst4 (
    .clk(inst4_clk),
    .ev0(inst4_ev0),
    .p11(inst4_p11),
    .p12(inst4_p12),
    .p13(inst4_p13),
    .reset(inst4_reset)
);
comp4 inst5 (
    .clk(inst5_clk),
    .ev0(inst5_ev0),
    .p11(inst5_p11),
    .p12(inst5_p12),
    .p13(inst5_p13),
    .reset(inst5_reset)
);
comp4 inst6 (
    .clk(inst6_clk),
    .ev0(inst6_ev0),
    .p11(inst6_p11),
    .p12(inst6_p12),
    .p13(inst6_p13),
    .reset(inst6_reset)
);
comp4 inst7 (
    .clk(inst7_clk),
    .ev0(inst7_ev0),
    .p11(inst7_p11),
    .p12(inst7_p12),
    .p13(inst7_p13),
    .reset(inst7_reset)
);
wire _guard0 = 1;
wire _guard1 = go0__3;
wire _guard2 = go0__3;
wire _guard3 = go0__3;
wire _guard4 = go0__3;
wire _guard5 = go0__0;
wire _guard6 = go0__0;
wire _guard7 = go0__0;
wire _guard8 = go0__0;
wire _guard9 = go0__0;
wire _guard10 = go0__0;
wire _guard11 = go0__0;
wire _guard12 = go0__0;
wire _guard13 = go0__0;
wire _guard14 = go0__0;
wire _guard15 = go0__0;
wire _guard16 = go0__0;
wire _guard17 = go0__0;
wire _guard18 = go0__0;
wire _guard19 = go0__0;
wire _guard20 = go0__0;
wire _guard21 = go0__0;
wire _guard22 = go0__0;
wire _guard23 = go0__0;
wire _guard24 = go0__0;
assign out10 =
  _guard1 ? inst6_p13 :
  32'd0;
assign out01 =
  _guard2 ? inst5_p13 :
  32'd0;
assign out11 =
  _guard3 ? inst7_p13 :
  32'd0;
assign out00 =
  _guard4 ? inst4_p13 :
  32'd0;
assign inst5_ev0 = _guard5;
assign inst5_p12 = t1;
assign inst5_clk = clk;
assign inst5_p11 = inst0_prev;
assign inst5_reset = reset;
assign go0_clk = clk;
assign go0_go = go;
assign go0_reset = reset;
assign inst3_write_en = _guard8;
assign inst3_clk = clk;
assign inst3_reset = reset;
assign inst3_in = t1;
assign inst1_write_en = _guard10;
assign inst1_clk = clk;
assign inst1_reset = reset;
assign inst1_in = t0;
assign inst0_write_en = _guard12;
assign inst0_clk = clk;
assign inst0_reset = reset;
assign inst0_in = l0;
assign inst7_ev0 = _guard14;
assign inst7_p12 = inst3_prev;
assign inst7_clk = clk;
assign inst7_p11 = inst2_prev;
assign inst7_reset = reset;
assign inst6_ev0 = _guard17;
assign inst6_p12 = inst1_prev;
assign inst6_clk = clk;
assign inst6_p11 = l1;
assign inst6_reset = reset;
assign inst2_write_en = _guard20;
assign inst2_clk = clk;
assign inst2_reset = reset;
assign inst2_in = l1;
assign inst4_ev0 = _guard22;
assign inst4_p12 = t0;
assign inst4_clk = clk;
assign inst4_p11 = l0;
assign inst4_reset = reset;
// COMPONENT END: main
endmodule
module fsm_4(
  output logic _0,
  output logic _1,
  output logic _2,
  output logic _3,
  input logic clk,
  input logic reset,
  input logic go,
  output logic done
);
// COMPONENT START: fsm_4
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
logic r2_in;
logic r2_write_en;
logic r2_clk;
logic r2_reset;
logic r2_out;
logic r2_done;
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
std_reg # (
    .WIDTH(1)
) r2 (
    .clk(r2_clk),
    .done(r2_done),
    .in(r2_in),
    .out(r2_out),
    .reset(r2_reset),
    .write_en(r2_write_en)
);
wire _guard0 = 1;
assign done = r2_out;
assign _2 = r0_out;
assign _1 = r_out;
assign _0 = go;
assign _3 = r1_out;
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
assign r2_write_en = 1'd1;
assign r2_clk = clk;
assign r2_reset = reset;
assign r2_in = r1_out;
// COMPONENT END: fsm_4
endmodule

module SAfil (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni
);

  logic[0:0] _main_le_input_l0_valid;
  logic[31:0] _main_le_input_l0_0;
  logic[31:0] _main_le_input_l1_0;
  logic[31:0] _main_le_input_t0_0;
  logic[31:0] _main_le_input_t1_0;
  logic[31:0] _main_le_out00_0;
  logic[31:0] _main_le_out01_0;
  logic[31:0] _main_le_out10_0;
  logic[31:0] _main_le_out11_0;
  main _spawn_0 (
    .clk(clk_i),
    .reset(~rst_ni)
    ,.go (_main_le_input_l0_valid)
    ,.l0 (_main_le_input_l0_0)
    ,.l1 (_main_le_input_l1_0)
    ,.t0 (_main_le_input_t0_0)
    ,.t1 (_main_le_input_t1_0)
    ,.out00 (_main_le_out00_0)
    ,.out01 (_main_le_out01_0)
    ,.out10 (_main_le_out10_0)
    ,.out11 (_main_le_out11_0)
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
  localparam logic[31:0] thread_1_wire$0 = 32'd3;
  localparam logic[31:0] thread_1_wire$1 = 32'd6;
  localparam logic[31:0] thread_1_wire$2 = 32'd9;
  localparam logic[31:0] thread_1_wire$3 = 32'd12;
  localparam logic[31:0] thread_1_wire$4 = 32'd5;
  localparam logic[31:0] thread_1_wire$5 = 32'd10;
  localparam logic[31:0] thread_1_wire$6 = 32'd15;
  localparam logic[31:0] thread_1_wire$7 = 32'd20;
  localparam logic[31:0] thread_1_wire$8 = 32'd7;
  localparam logic[31:0] thread_1_wire$9 = 32'd14;
  localparam logic[31:0] thread_1_wire$10 = 32'd21;
  localparam logic[31:0] thread_1_wire$11 = 32'd28;
  for (genvar i = 0; i < 4; i ++) begin : EVENTS1
    logic event_current;
    end
  logic _init_1;
  logic _thread_1_event_counter_3_1_q, _thread_1_event_counter_3_1_n;
  logic _thread_1_event_counter_2_1_q, _thread_1_event_counter_2_1_n;
  logic _thread_1_event_counter_1_1_q, _thread_1_event_counter_1_1_n;
  assign EVENTS1[3].event_current = _thread_1_event_counter_3_1_q;
  assign _thread_1_event_counter_3_1_n = EVENTS1[2].event_current;
  assign EVENTS1[2].event_current = _thread_1_event_counter_2_1_q;
  assign _thread_1_event_counter_2_1_n = EVENTS1[1].event_current;
  assign EVENTS1[1].event_current = _thread_1_event_counter_1_1_q;
  assign _thread_1_event_counter_1_1_n = EVENTS1[0].event_current;
  assign EVENTS1[0].event_current = _init_1 || EVENTS1[3].event_current;
  assign _main_le_input_l0_valid = EVENTS1[0].event_current || EVENTS1[1].event_current || EVENTS1[2].event_current;
  logic[1:0] _main_le_input_t1_valid_selector_q, _main_le_input_t1_valid_selector_n;
  assign _main_le_input_t1_0 = (_main_le_input_t1_valid_selector_n == 2'd0) ? thread_1_wire$3 : (_main_le_input_t1_valid_selector_n == 2'd1) ? thread_1_wire$7 : (_main_le_input_t1_valid_selector_n == 2'd2) ? thread_1_wire$11 : '0;
  logic[1:0] _main_le_input_l0_valid_selector_q, _main_le_input_l0_valid_selector_n;
  assign _main_le_input_l0_0 = (_main_le_input_l0_valid_selector_n == 2'd0) ? thread_1_wire$0 : (_main_le_input_l0_valid_selector_n == 2'd1) ? thread_1_wire$4 : (_main_le_input_l0_valid_selector_n == 2'd2) ? thread_1_wire$8 : '0;
  logic[1:0] _main_le_input_t0_valid_selector_q, _main_le_input_t0_valid_selector_n;
  assign _main_le_input_t0_0 = (_main_le_input_t0_valid_selector_n == 2'd0) ? thread_1_wire$2 : (_main_le_input_t0_valid_selector_n == 2'd1) ? thread_1_wire$6 : (_main_le_input_t0_valid_selector_n == 2'd2) ? thread_1_wire$10 : '0;
  logic[1:0] _main_le_input_l1_valid_selector_q, _main_le_input_l1_valid_selector_n;
  assign _main_le_input_l1_0 = (_main_le_input_l1_valid_selector_n == 2'd0) ? thread_1_wire$1 : (_main_le_input_l1_valid_selector_n == 2'd1) ? thread_1_wire$5 : (_main_le_input_l1_valid_selector_n == 2'd2) ? thread_1_wire$9 : '0;
  always_comb begin: _thread_1_selector
    _main_le_input_t1_valid_selector_n = _main_le_input_t1_valid_selector_q;
    if (EVENTS1[0].event_current) _main_le_input_t1_valid_selector_n = 2'd0;
    if (EVENTS1[1].event_current) _main_le_input_t1_valid_selector_n = 2'd1;
    if (EVENTS1[2].event_current) _main_le_input_t1_valid_selector_n = 2'd2;
    _main_le_input_l0_valid_selector_n = _main_le_input_l0_valid_selector_q;
    if (EVENTS1[0].event_current) _main_le_input_l0_valid_selector_n = 2'd0;
    if (EVENTS1[1].event_current) _main_le_input_l0_valid_selector_n = 2'd1;
    if (EVENTS1[2].event_current) _main_le_input_l0_valid_selector_n = 2'd2;
    _main_le_input_t0_valid_selector_n = _main_le_input_t0_valid_selector_q;
    if (EVENTS1[0].event_current) _main_le_input_t0_valid_selector_n = 2'd0;
    if (EVENTS1[1].event_current) _main_le_input_t0_valid_selector_n = 2'd1;
    if (EVENTS1[2].event_current) _main_le_input_t0_valid_selector_n = 2'd2;
    _main_le_input_l1_valid_selector_n = _main_le_input_l1_valid_selector_q;
    if (EVENTS1[0].event_current) _main_le_input_l1_valid_selector_n = 2'd0;
    if (EVENTS1[1].event_current) _main_le_input_l1_valid_selector_n = 2'd1;
    if (EVENTS1[2].event_current) _main_le_input_l1_valid_selector_n = 2'd2;
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_1_selector_trans
    if (~rst_ni) begin
      _main_le_input_t1_valid_selector_q <= '0;
      _main_le_input_l0_valid_selector_q <= '0;
      _main_le_input_t0_valid_selector_q <= '0;
      _main_le_input_l1_valid_selector_q <= '0;
    end else begin
      _main_le_input_t1_valid_selector_q <= _main_le_input_t1_valid_selector_n;
      _main_le_input_l0_valid_selector_q <= _main_le_input_l0_valid_selector_n;
      _main_le_input_t0_valid_selector_q <= _main_le_input_t0_valid_selector_n;
      _main_le_input_l1_valid_selector_q <= _main_le_input_l1_valid_selector_n;
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_1_st_transition
    if (~rst_ni) begin
      _init_1 <= 1'b1;
      _thread_1_event_counter_3_1_q <= '0;
      _thread_1_event_counter_2_1_q <= '0;
      _thread_1_event_counter_1_1_q <= '0;
    end else begin
      if (EVENTS1[2].event_current) begin
      end
      if (EVENTS1[1].event_current) begin
      end
      if (EVENTS1[0].event_current) begin
      end
      _init_1 <= 1'b0;
      _thread_1_event_counter_3_1_q <= _thread_1_event_counter_3_1_n;
      _thread_1_event_counter_2_1_q <= _thread_1_event_counter_2_1_n;
      _thread_1_event_counter_1_1_q <= _thread_1_event_counter_1_1_n;
    end
  end
  logic[31:0] thread_2_wire$14;
  logic[31:0] thread_2_wire$13;
  logic[31:0] thread_2_wire$12;
  logic[31:0] thread_2_wire$11;
  logic[31:0] thread_2_wire$10;
  logic[31:0] thread_2_wire$9;
  logic[31:0] thread_2_wire$8;
  logic[31:0] thread_2_wire$7;
  logic[31:0] thread_2_wire$6;
  logic[31:0] thread_2_wire$5;
  logic[31:0] thread_2_wire$4;
  logic[31:0] thread_2_wire$3;
  logic[31:0] thread_2_wire$2;
  logic[31:0] thread_2_wire$1;
  logic[31:0] thread_2_wire$0;
  assign thread_2_wire$0 = _main_le_out00_0;
  assign thread_2_wire$1 = _main_le_out01_0;
  assign thread_2_wire$2 = _main_le_out10_0;
  assign thread_2_wire$3 = _main_le_out11_0;
  assign thread_2_wire$4 = cycle_count_q;
  assign thread_2_wire$5 = _main_le_out00_0;
  assign thread_2_wire$6 = _main_le_out01_0;
  assign thread_2_wire$7 = _main_le_out10_0;
  assign thread_2_wire$8 = _main_le_out11_0;
  assign thread_2_wire$9 = cycle_count_q;
  assign thread_2_wire$10 = _main_le_out00_0;
  assign thread_2_wire$11 = _main_le_out01_0;
  assign thread_2_wire$12 = _main_le_out10_0;
  assign thread_2_wire$13 = _main_le_out11_0;
  assign thread_2_wire$14 = cycle_count_q;
  for (genvar i = 0; i < 5; i ++) begin : EVENTS2
    logic event_current;
    end
  logic _init_2;
  logic _thread_2_event_counter_4_1_q, _thread_2_event_counter_4_1_n;
  logic _thread_2_event_counter_3_1_q, _thread_2_event_counter_3_1_n;
  logic _thread_2_event_counter_2_1_q, _thread_2_event_counter_2_1_n;
  logic[1:0] _thread_2_event_counter_1_q, _thread_2_event_counter_1_n;
  assign EVENTS2[4].event_current = _thread_2_event_counter_4_1_q;
  assign _thread_2_event_counter_4_1_n = EVENTS2[3].event_current;
  assign EVENTS2[3].event_current = _thread_2_event_counter_3_1_q;
  assign _thread_2_event_counter_3_1_n = EVENTS2[2].event_current;
  assign EVENTS2[2].event_current = _thread_2_event_counter_2_1_q;
  assign _thread_2_event_counter_2_1_n = EVENTS2[1].event_current;
  assign EVENTS2[1].event_current = _thread_2_event_counter_1_q == 2'd3;
    assign _thread_2_event_counter_1_n = EVENTS2[0].event_current ? 2'd1 : EVENTS2[1].event_current ? '0 : _thread_2_event_counter_1_q ? (_thread_2_event_counter_1_q + 2'd1) : _thread_2_event_counter_1_q;
  assign EVENTS2[0].event_current = _init_2 || EVENTS2[4].event_current;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_2_st_transition
    if (~rst_ni) begin
      _init_2 <= 1'b1;
      _thread_2_event_counter_4_1_q <= '0;
      _thread_2_event_counter_3_1_q <= '0;
      _thread_2_event_counter_2_1_q <= '0;
      _thread_2_event_counter_1_q <= '0;
    end else begin
      if (EVENTS2[4].event_current) begin
        $finish;
      end
      if (EVENTS2[3].event_current) begin
        $display("[Cycle %d] Result 00: %d, Result 01: %d, Result 10: %d, Result 11: %d\n", thread_2_wire$14, thread_2_wire$10, thread_2_wire$11, thread_2_wire$12, thread_2_wire$13);
      end
      if (EVENTS2[2].event_current) begin
        $display("[Cycle %d] Result 00: %d, Result 01: %d, Result 10: %d, Result 11: %d\n", thread_2_wire$9, thread_2_wire$5, thread_2_wire$6, thread_2_wire$7, thread_2_wire$8);
      end
      if (EVENTS2[1].event_current) begin
        $display("[Cycle %d] Result 00: %d, Result 01: %d, Result 10: %d, Result 11: %d\n", thread_2_wire$4, thread_2_wire$0, thread_2_wire$1, thread_2_wire$2, thread_2_wire$3);
      end
      _init_2 <= 1'b0;
      _thread_2_event_counter_4_1_q <= _thread_2_event_counter_4_1_n;
      _thread_2_event_counter_3_1_q <= _thread_2_event_counter_3_1_n;
      _thread_2_event_counter_2_1_q <= _thread_2_event_counter_2_1_n;
      _thread_2_event_counter_1_q <= _thread_2_event_counter_1_n;
    end
  end
endmodule