/* verilator lint_off UNOPTFLAT */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHCONCAT */
module AluAnvil (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni
);
  logic[0:0] _alu_le_input_l_valid;
  logic[31:0] _alu_le_input_l_0;
  logic[31:0] _alu_le_input_r_0;
  logic[0:0] _alu_le_input_op_0;
  logic[31:0] _alu_le_output_0;
  anvilALU_0 _spawn_0 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_alu_le_input_l_valid)
    ,._endp_input_l_0 (_alu_le_input_l_0)
    ,._endp_input_r_0 (_alu_le_input_r_0)
    ,._endp_input_op_0 (_alu_le_input_op_0)
    ,._endp_output_0 (_alu_le_output_0)
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
module anvilALU_0 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  input logic[0:0] _endp_input_op_0,
  output logic[31:0] _endp_output_0
);
  logic[0:0] _mux_le_input_l_valid;
  logic[31:0] _mux_le_input_l_0;
  logic[31:0] _mux_le_input_r_0;
  logic[0:0] _mux_le_input_op_0;
  logic[31:0] _mux_le_output_0;
  logic[0:0] _add_le_input_l_valid;
  logic[31:0] _add_le_input_l_0;
  logic[31:0] _add_le_input_r_0;
  logic[31:0] _add_le_output_0;
  logic[0:0] _reg0_le_input_v_valid;
  logic[31:0] _reg0_le_input_v_0;
  logic[31:0] _reg0_le_output_0;
  logic[0:0] _reg1_le_input_v_valid;
  logic[31:0] _reg1_le_input_v_0;
  logic[31:0] _reg1_le_output_0;
  logic[0:0] _sub_le_input_l_valid;
  logic[31:0] _sub_le_input_l_0;
  logic[31:0] _sub_le_input_r_0;
  logic[31:0] _sub_le_output_0;
  Add_0 _spawn_0 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_add_le_input_l_valid)
    ,._endp_input_l_0 (_add_le_input_l_0)
    ,._endp_input_r_0 (_add_le_input_r_0)
    ,._endp_output_0 (_add_le_output_0)
  );
  Mux_0 _spawn_1 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_mux_le_input_l_valid)
    ,._endp_input_l_0 (_mux_le_input_l_0)
    ,._endp_input_r_0 (_mux_le_input_r_0)
    ,._endp_input_op_0 (_mux_le_input_op_0)
    ,._endp_output_0 (_mux_le_output_0)
  );
  Reg_0 _spawn_2 (
    .clk_i,
    .rst_ni
    ,._endp_input_v_valid (_reg0_le_input_v_valid)
    ,._endp_input_v_0 (_reg0_le_input_v_0)
    ,._endp_output_0 (_reg0_le_output_0)
  );
  Reg_1 _spawn_3 (
    .clk_i,
    .rst_ni
    ,._endp_input_v_valid (_reg1_le_input_v_valid)
    ,._endp_input_v_0 (_reg1_le_input_v_0)
    ,._endp_output_0 (_reg1_le_output_0)
  );
  SubtractDelayed_0 _spawn_4 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_sub_le_input_l_valid)
    ,._endp_input_l_0 (_sub_le_input_l_0)
    ,._endp_input_r_0 (_sub_le_input_r_0)
    ,._endp_output_0 (_sub_le_output_0)
  );
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$7;
  logic[0:0] thread_0_wire$6;
  logic[31:0] thread_0_wire$5;
  logic[31:0] thread_0_wire$4;
  logic[31:0] thread_0_wire$3;
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_l_0;
  assign thread_0_wire$1 = _endp_input_r_0;
  assign thread_0_wire$2 = _add_le_output_0;
  assign thread_0_wire$3 = _reg0_le_output_0;
  assign thread_0_wire$4 = _reg1_le_output_0;
  assign thread_0_wire$5 = _sub_le_output_0;
  assign thread_0_wire$6 = _endp_input_op_0;
  assign thread_0_wire$7 = _mux_le_output_0;
  for (genvar i = 0; i < 5; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_4_1_q, _thread_0_event_counter_4_1_n;
  logic _thread_0_event_counter_4_2_q, _thread_0_event_counter_4_2_n;
  logic _thread_0_event_counter_3_1_q, _thread_0_event_counter_3_1_n;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[4].event_current = _thread_0_event_counter_4_2_q;
  assign _thread_0_event_counter_4_2_n = _thread_0_event_counter_4_1_q;
  assign _thread_0_event_counter_4_1_n = EVENTS0[1].event_current;
  assign EVENTS0[3].event_current = _thread_0_event_counter_3_1_q;
  assign _thread_0_event_counter_3_1_n = EVENTS0[2].event_current;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _mux_le_input_r_0 = thread_0_wire$5;
  assign _reg1_le_input_v_valid = EVENTS0[2].event_current;
  assign _reg1_le_input_v_0 = thread_0_wire$3;
  assign _add_le_input_l_valid = EVENTS0[1].event_current;
  assign _add_le_input_l_0 = thread_0_wire$0;
  assign _endp_output_0 = thread_0_wire$7;
  assign _reg0_le_input_v_valid = EVENTS0[1].event_current;
  assign _reg0_le_input_v_0 = thread_0_wire$2;
  assign _mux_le_input_l_valid = EVENTS0[4].event_current;
  assign _mux_le_input_l_0 = thread_0_wire$4;
  assign _mux_le_input_op_0 = thread_0_wire$6;
  assign _sub_le_input_l_valid = EVENTS0[1].event_current;
  assign _sub_le_input_l_0 = thread_0_wire$0;
  assign _add_le_input_r_0 = thread_0_wire$1;
  assign _sub_le_input_r_0 = thread_0_wire$1;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      _thread_0_event_counter_4_1_q <= '0;
      _thread_0_event_counter_4_2_q <= '0;
      _thread_0_event_counter_3_1_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[4].event_current) begin
      end
      if (EVENTS0[3].event_current) begin
      end
      if (EVENTS0[2].event_current) begin
      end
      if (EVENTS0[1].event_current) begin
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_4_1_q <= _thread_0_event_counter_4_1_n;
      _thread_0_event_counter_4_2_q <= _thread_0_event_counter_4_2_n;
      _thread_0_event_counter_3_1_q <= _thread_0_event_counter_3_1_n;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Add_0 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  output logic[31:0] _endp_output_0
);
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_l_0;
  assign thread_0_wire$1 = _endp_input_r_0;
  assign thread_0_wire$2 = thread_0_wire$0 + thread_0_wire$1;
  for (genvar i = 0; i < 3; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$2;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[1].event_current) begin
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Mux_0 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  input logic[0:0] _endp_input_op_0,
  output logic[31:0] _endp_output_0
);
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$3;
  logic[0:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_l_0;
  assign thread_0_wire$1 = _endp_input_r_0;
  assign thread_0_wire$2 = _endp_input_op_0;
  assign thread_0_wire$3 = (thread_0_wire$2) ? thread_0_wire$1 : thread_0_wire$0;
  for (genvar i = 0; i < 3; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$3;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[1].event_current) begin
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Reg_0 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_v_valid,
  input logic[31:0] _endp_input_v_0,
  output logic[31:0] _endp_output_0
);
  logic[31:0] r_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_v_0;
  assign thread_0_wire$1 = r_q;
  for (genvar i = 0; i < 3; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_v_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_v_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$1;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      r_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[2].event_current) begin
      end
      if (EVENTS0[1].event_current) begin
        r_q[0 +: 32] <= thread_0_wire$0;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Reg_1 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_v_valid,
  input logic[31:0] _endp_input_v_0,
  output logic[31:0] _endp_output_0
);
  logic[31:0] r_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_v_0;
  assign thread_0_wire$1 = r_q;
  for (genvar i = 0; i < 3; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_v_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_v_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$1;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      r_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[2].event_current) begin
      end
      if (EVENTS0[1].event_current) begin
        r_q[0 +: 32] <= thread_0_wire$0;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module SubtractDelayed_0 (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  output logic[31:0] _endp_output_0
);
  logic[31:0] r0_q;
  logic[31:0] r1_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$4;
  logic[31:0] thread_0_wire$3;
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_l_0;
  assign thread_0_wire$1 = _endp_input_r_0;
  assign thread_0_wire$2 = thread_0_wire$0 - thread_0_wire$1;
  assign thread_0_wire$3 = r0_q;
  assign thread_0_wire$4 = r1_q;
  for (genvar i = 0; i < 4; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_3_1_q, _thread_0_event_counter_3_1_n;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[3].event_current = _thread_0_event_counter_3_1_q;
  assign _thread_0_event_counter_3_1_n = EVENTS0[2].event_current;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$4;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      r0_q <= '0;
      r1_q <= '0;
      _thread_0_event_counter_3_1_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[3].event_current) begin
      end
      if (EVENTS0[2].event_current) begin
        r1_q[0 +: 32] <= thread_0_wire$3;
      end
      if (EVENTS0[1].event_current) begin
        r0_q[0 +: 32] <= thread_0_wire$2;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_3_1_q <= _thread_0_event_counter_3_1_n;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
