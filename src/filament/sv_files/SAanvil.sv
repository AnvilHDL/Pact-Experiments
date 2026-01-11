/* verilator lint_off UNOPTFLAT */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHCONCAT */
module Add (
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
module MultComb (
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
module FastMult (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  output logic[31:0] _endp_output_0
);
  logic[0:0] _mult_ri_input_l_valid;
  logic[31:0] _mult_ri_input_l_0;
  logic[31:0] _mult_ri_input_r_0;
  logic[31:0] _mult_ri_output_0;
  MultComb _spawn_0 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_mult_ri_input_l_valid)
    ,._endp_input_l_0 (_mult_ri_input_l_0)
    ,._endp_input_r_0 (_mult_ri_input_r_0)
    ,._endp_output_0 (_mult_ri_output_0)
  );
  logic[31:0] final_q;
  logic[31:0] l_q;
  logic[31:0] ot_q;
  logic[31:0] r_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$6;
  logic[31:0] thread_0_wire$5;
  logic[31:0] thread_0_wire$4;
  logic[31:0] thread_0_wire$3;
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _endp_input_l_0;
  assign thread_0_wire$1 = _endp_input_r_0;
  assign thread_0_wire$2 = l_q;
  assign thread_0_wire$3 = r_q;
  assign thread_0_wire$4 = _mult_ri_output_0;
  assign thread_0_wire$5 = ot_q;
  assign thread_0_wire$6 = final_q;
  for (genvar i = 0; i < 5; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_4_1_q, _thread_0_event_counter_4_1_n;
  logic _thread_0_event_counter_3_1_q, _thread_0_event_counter_3_1_n;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[4].event_current = _thread_0_event_counter_4_1_q;
  assign _thread_0_event_counter_4_1_n = EVENTS0[3].event_current;
  assign EVENTS0[3].event_current = _thread_0_event_counter_3_1_q;
  assign _thread_0_event_counter_3_1_n = EVENTS0[2].event_current;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_output_0 = thread_0_wire$6;
  assign _mult_ri_input_l_valid = EVENTS0[2].event_current;
  assign _mult_ri_input_l_0 = thread_0_wire$2;
  assign _mult_ri_input_r_0 = thread_0_wire$3;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      final_q <= '0;
      l_q <= '0;
      ot_q <= '0;
      r_q <= '0;
      _thread_0_event_counter_4_1_q <= '0;
      _thread_0_event_counter_3_1_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[4].event_current) begin
      end
      if (EVENTS0[3].event_current) begin
        final_q[0 +: 32] <= thread_0_wire$5;
      end
      if (EVENTS0[2].event_current) begin
        ot_q[0 +: 32] <= thread_0_wire$4;
      end
      if (EVENTS0[1].event_current) begin
        r_q[0 +: 32] <= thread_0_wire$1;
        l_q[0 +: 32] <= thread_0_wire$0;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_4_1_q <= _thread_0_event_counter_4_1_n;
      _thread_0_event_counter_3_1_q <= _thread_0_event_counter_3_1_n;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Prev (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[31:0] _endp_input_0,
  input logic[0:0] _endp_prev_ack,
  output logic[31:0] _endp_prev_0
);
  logic[31:0] prev_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = prev_q;
  assign thread_0_wire$1 = _endp_input_0;
  for (genvar i = 0; i < 3; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_prev_ack;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_prev_ack;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[2].event_current;
  assign _endp_prev_0 = thread_0_wire$0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      prev_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[1].event_current) begin
        prev_q[0 +: 32] <= thread_0_wire$1;
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module Process (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _endp_input_l_valid,
  input logic[31:0] _endp_input_l_0,
  input logic[31:0] _endp_input_r_0,
  output logic[31:0] _endp_output_0
);
  logic[0:0] _fast_mult_le_input_l_valid;
  logic[31:0] _fast_mult_le_input_l_0;
  logic[31:0] _fast_mult_le_input_r_0;
  logic[31:0] _fast_mult_le_output_0;
  logic[31:0] _prev_le_input_0;
  logic[0:0] _prev_le_prev_ack;
  logic[31:0] _prev_le_prev_0;
  logic[0:0] _add_le_input_l_valid;
  logic[31:0] _add_le_input_l_0;
  logic[31:0] _add_le_input_r_0;
  logic[31:0] _add_le_output_0;
  Prev _spawn_0 (
    .clk_i,
    .rst_ni
    ,._endp_input_0 (_prev_le_input_0)
    ,._endp_prev_ack (_prev_le_prev_ack)
    ,._endp_prev_0 (_prev_le_prev_0)
  );
  FastMult _spawn_1 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_fast_mult_le_input_l_valid)
    ,._endp_input_l_0 (_fast_mult_le_input_l_0)
    ,._endp_input_r_0 (_fast_mult_le_input_r_0)
    ,._endp_output_0 (_fast_mult_le_output_0)
  );
  Add_0 _spawn_2 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_add_le_input_l_valid)
    ,._endp_input_l_0 (_add_le_input_l_0)
    ,._endp_input_r_0 (_add_le_input_r_0)
    ,._endp_output_0 (_add_le_output_0)
  );
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
  assign thread_0_wire$2 = _fast_mult_le_output_0;
  assign thread_0_wire$3 = _prev_le_prev_0;
  assign thread_0_wire$4 = _add_le_output_0;
  for (genvar i = 0; i < 4; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_3_1_q, _thread_0_event_counter_3_1_n;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_counter_2_2_q, _thread_0_event_counter_2_2_n;
  logic _thread_0_event_counter_2_3_q, _thread_0_event_counter_2_3_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[3].event_current = _thread_0_event_counter_3_1_q;
  assign _thread_0_event_counter_3_1_n = EVENTS0[1].event_current;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_3_q;
  assign _thread_0_event_counter_2_2_n = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_3_n = _thread_0_event_counter_2_2_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _endp_input_l_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_endp_input_l_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[3].event_current;
  assign _prev_le_prev_ack = EVENTS0[2].event_current;
  assign _fast_mult_le_input_r_0 = thread_0_wire$1;
  assign _fast_mult_le_input_l_valid = EVENTS0[1].event_current;
  assign _fast_mult_le_input_l_0 = thread_0_wire$0;
  assign _add_le_input_l_valid = EVENTS0[2].event_current;
  assign _add_le_input_l_0 = thread_0_wire$3;
  assign _endp_output_0 = thread_0_wire$4;
  assign _prev_le_input_0 = thread_0_wire$4;
  assign _add_le_input_r_0 = thread_0_wire$2;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      _thread_0_event_counter_3_1_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_counter_2_2_q <= '0;
      _thread_0_event_counter_2_3_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[2].event_current) begin
      end
      if (EVENTS0[1].event_current) begin
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_3_1_q <= _thread_0_event_counter_3_1_n;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_counter_2_2_q <= _thread_0_event_counter_2_2_n;
      _thread_0_event_counter_2_3_q <= _thread_0_event_counter_2_3_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module SA (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _ep_input_l0_valid,
  input logic[31:0] _ep_input_l0_0,
  input logic[31:0] _ep_input_l1_0,
  input logic[31:0] _ep_input_t0_0,
  input logic[31:0] _ep_input_t1_0,
  output logic[31:0] _ep_out00_0,
  output logic[31:0] _ep_out01_0,
  output logic[31:0] _ep_out10_0,
  output logic[31:0] _ep_out11_0
);
  logic[31:0] _prev_le1_input_0;
  logic[0:0] _prev_le1_prev_ack;
  logic[31:0] _prev_le1_prev_0;
  logic[31:0] _prev_le2_input_0;
  logic[0:0] _prev_le2_prev_ack;
  logic[31:0] _prev_le2_prev_0;
  logic[31:0] _prev_le3_input_0;
  logic[0:0] _prev_le3_prev_ack;
  logic[31:0] _prev_le3_prev_0;
  logic[31:0] _prev_le4_input_0;
  logic[0:0] _prev_le4_prev_ack;
  logic[31:0] _prev_le4_prev_0;
  logic[0:0] _proc_le1_input_l_valid;
  logic[31:0] _proc_le1_input_l_0;
  logic[31:0] _proc_le1_input_r_0;
  logic[31:0] _proc_le1_output_0;
  logic[0:0] _proc_le2_input_l_valid;
  logic[31:0] _proc_le2_input_l_0;
  logic[31:0] _proc_le2_input_r_0;
  logic[31:0] _proc_le2_output_0;
  logic[0:0] _proc_le3_input_l_valid;
  logic[31:0] _proc_le3_input_l_0;
  logic[31:0] _proc_le3_input_r_0;
  logic[31:0] _proc_le3_output_0;
  logic[0:0] _proc_le4_input_l_valid;
  logic[31:0] _proc_le4_input_l_0;
  logic[31:0] _proc_le4_input_r_0;
  logic[31:0] _proc_le4_output_0;
  Process _spawn_0 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_proc_le1_input_l_valid)
    ,._endp_input_l_0 (_proc_le1_input_l_0)
    ,._endp_input_r_0 (_proc_le1_input_r_0)
    ,._endp_output_0 (_proc_le1_output_0)
  );
  Process _spawn_1 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_proc_le2_input_l_valid)
    ,._endp_input_l_0 (_proc_le2_input_l_0)
    ,._endp_input_r_0 (_proc_le2_input_r_0)
    ,._endp_output_0 (_proc_le2_output_0)
  );
  Process _spawn_2 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_proc_le3_input_l_valid)
    ,._endp_input_l_0 (_proc_le3_input_l_0)
    ,._endp_input_r_0 (_proc_le3_input_r_0)
    ,._endp_output_0 (_proc_le3_output_0)
  );
  Process _spawn_3 (
    .clk_i,
    .rst_ni
    ,._endp_input_l_valid (_proc_le4_input_l_valid)
    ,._endp_input_l_0 (_proc_le4_input_l_0)
    ,._endp_input_r_0 (_proc_le4_input_r_0)
    ,._endp_output_0 (_proc_le4_output_0)
  );
  Prev _spawn_4 (
    .clk_i,
    .rst_ni
    ,._endp_input_0 (_prev_le1_input_0)
    ,._endp_prev_ack (_prev_le1_prev_ack)
    ,._endp_prev_0 (_prev_le1_prev_0)
  );
  Prev _spawn_5 (
    .clk_i,
    .rst_ni
    ,._endp_input_0 (_prev_le2_input_0)
    ,._endp_prev_ack (_prev_le2_prev_ack)
    ,._endp_prev_0 (_prev_le2_prev_0)
  );
  Prev _spawn_6 (
    .clk_i,
    .rst_ni
    ,._endp_input_0 (_prev_le3_input_0)
    ,._endp_prev_ack (_prev_le3_prev_ack)
    ,._endp_prev_0 (_prev_le3_prev_0)
  );
  Prev _spawn_7 (
    .clk_i,
    .rst_ni
    ,._endp_input_0 (_prev_le4_input_0)
    ,._endp_prev_ack (_prev_le4_prev_ack)
    ,._endp_prev_0 (_prev_le4_prev_0)
  );
  always_ff @(posedge clk_i or negedge rst_ni) begin : _proc_transition
    if (~rst_ni) begin
    end
  end
  logic[31:0] thread_0_wire$11;
  logic[31:0] thread_0_wire$10;
  logic[31:0] thread_0_wire$9;
  logic[31:0] thread_0_wire$8;
  logic[31:0] thread_0_wire$7;
  logic[31:0] thread_0_wire$6;
  logic[31:0] thread_0_wire$5;
  logic[31:0] thread_0_wire$4;
  logic[31:0] thread_0_wire$3;
  logic[31:0] thread_0_wire$2;
  logic[31:0] thread_0_wire$1;
  logic[31:0] thread_0_wire$0;
  assign thread_0_wire$0 = _ep_input_l0_0;
  assign thread_0_wire$1 = _ep_input_l1_0;
  assign thread_0_wire$2 = _ep_input_t0_0;
  assign thread_0_wire$3 = _ep_input_t1_0;
  assign thread_0_wire$4 = _prev_le1_prev_0;
  assign thread_0_wire$5 = _prev_le2_prev_0;
  assign thread_0_wire$6 = _prev_le3_prev_0;
  assign thread_0_wire$7 = _prev_le4_prev_0;
  assign thread_0_wire$8 = _proc_le1_output_0;
  assign thread_0_wire$9 = _proc_le2_output_0;
  assign thread_0_wire$10 = _proc_le3_output_0;
  assign thread_0_wire$11 = _proc_le4_output_0;
  for (genvar i = 0; i < 4; i ++) begin : EVENTS0
    logic event_current;
    end
  logic _init_0;
  logic _thread_0_event_counter_3_1_q, _thread_0_event_counter_3_1_n;
  logic _thread_0_event_counter_2_1_q, _thread_0_event_counter_2_1_n;
  logic _thread_0_event_counter_2_2_q, _thread_0_event_counter_2_2_n;
  logic _thread_0_event_counter_2_3_q, _thread_0_event_counter_2_3_n;
  logic _thread_0_event_syncstate_1_q, _thread_0_event_syncstate_1_n;
  assign EVENTS0[3].event_current = _thread_0_event_counter_3_1_q;
  assign _thread_0_event_counter_3_1_n = EVENTS0[1].event_current;
  assign EVENTS0[2].event_current = _thread_0_event_counter_2_3_q;
  assign _thread_0_event_counter_2_2_n = _thread_0_event_counter_2_1_q;
  assign _thread_0_event_counter_2_3_n = _thread_0_event_counter_2_2_q;
  assign _thread_0_event_counter_2_1_n = EVENTS0[1].event_current;
  assign EVENTS0[1].event_current = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && _ep_input_l0_valid;
    assign _thread_0_event_syncstate_1_n = (EVENTS0[0].event_current || _thread_0_event_syncstate_1_q) && !_ep_input_l0_valid;
  assign EVENTS0[0].event_current = _init_0 || EVENTS0[3].event_current;
  assign _prev_le1_prev_ack = EVENTS0[1].event_current;
  assign _prev_le3_prev_ack = EVENTS0[1].event_current;
  assign _prev_le2_prev_ack = EVENTS0[1].event_current;
  assign _prev_le4_prev_ack = EVENTS0[1].event_current;
  assign _prev_le2_input_0 = thread_0_wire$2;
  assign _proc_le4_input_l_valid = EVENTS0[1].event_current;
  assign _proc_le4_input_l_0 = thread_0_wire$6;
  assign _proc_le4_input_r_0 = thread_0_wire$7;
  assign _proc_le1_input_r_0 = thread_0_wire$2;
  assign _proc_le3_input_l_valid = EVENTS0[1].event_current;
  assign _proc_le3_input_l_0 = thread_0_wire$1;
  assign _proc_le2_input_l_valid = EVENTS0[1].event_current;
  assign _proc_le2_input_l_0 = thread_0_wire$4;
  assign _proc_le3_input_r_0 = thread_0_wire$5;
  assign _prev_le3_input_0 = thread_0_wire$1;
  assign _prev_le1_input_0 = thread_0_wire$0;
  assign _proc_le1_input_l_valid = EVENTS0[1].event_current;
  assign _proc_le1_input_l_0 = thread_0_wire$0;
  assign _proc_le2_input_r_0 = thread_0_wire$3;
  assign _ep_out01_0 = thread_0_wire$9;
  assign _ep_out00_0 = thread_0_wire$8;
  assign _ep_out11_0 = thread_0_wire$11;
  assign _prev_le4_input_0 = thread_0_wire$3;
  assign _ep_out10_0 = thread_0_wire$10;
  always_ff @(posedge clk_i or negedge rst_ni) begin : _thread_0_st_transition
    if (~rst_ni) begin
      _init_0 <= 1'b1;
      _thread_0_event_counter_3_1_q <= '0;
      _thread_0_event_counter_2_1_q <= '0;
      _thread_0_event_counter_2_2_q <= '0;
      _thread_0_event_counter_2_3_q <= '0;
      _thread_0_event_syncstate_1_q <= '0;
    end else begin
      if (EVENTS0[2].event_current) begin
      end
      if (EVENTS0[1].event_current) begin
      end
      _init_0 <= 1'b0;
      _thread_0_event_counter_3_1_q <= _thread_0_event_counter_3_1_n;
      _thread_0_event_counter_2_1_q <= _thread_0_event_counter_2_1_n;
      _thread_0_event_counter_2_2_q <= _thread_0_event_counter_2_2_n;
      _thread_0_event_counter_2_3_q <= _thread_0_event_counter_2_3_n;
      _thread_0_event_syncstate_1_q <= _thread_0_event_syncstate_1_n;
    end
  end
endmodule
module SAanvil (
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
  SA _spawn_0 (
    .clk_i,
    .rst_ni
    ,._ep_input_l0_valid (_main_le_input_l0_valid)
    ,._ep_input_l0_0 (_main_le_input_l0_0)
    ,._ep_input_l1_0 (_main_le_input_l1_0)
    ,._ep_input_t0_0 (_main_le_input_t0_0)
    ,._ep_input_t1_0 (_main_le_input_t1_0)
    ,._ep_out00_0 (_main_le_out00_0)
    ,._ep_out01_0 (_main_le_out01_0)
    ,._ep_out10_0 (_main_le_out10_0)
    ,._ep_out11_0 (_main_le_out11_0)
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
