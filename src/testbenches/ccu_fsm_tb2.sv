// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// ACE Cache Controller (ccu_fsm) Testbench
// Features:
// - 4 slaves with dual FSMs (request generation + snoop response)
// - Round-robin arbiter for request arbitration
// - Simple memory controller (256B RAM)
// - Request pattern aligned with src/compat/test_ace.anvil

`include "ace/typedef.svh"

module ccu_fsm_tb(
  input logic clk,
  input logic rst_n
);

  // ========================
  // Parameters - Matching ccu_fsm
  // ========================
  localparam int unsigned AxiDataWidth     = 8;
  localparam int unsigned DcacheLineWidth  = 16;
  localparam int unsigned NoMstPorts       = 4;
  localparam int unsigned SlvAxiIDWidth    = 1;
  localparam int unsigned AxiAddrWidth     = 32;
  localparam int unsigned AxiStrbWidth     = AxiDataWidth / 8;
  localparam int unsigned AxiUserWidth     = 1;
  
  localparam int unsigned MstIdxBits       = $clog2(NoMstPorts);
  localparam int unsigned FullIdWidth      = SlvAxiIDWidth + MstIdxBits;
  localparam int unsigned DcacheLineWords  = DcacheLineWidth / AxiDataWidth;

  // Memory parameters
  localparam int unsigned MemSize          = 256;
  localparam int unsigned MemAddrBits      = $clog2(MemSize);

  // Timing parameters
  localparam int unsigned ClkPeriod        = 10;
  localparam int unsigned RstCycles        = 5;
  localparam int unsigned SimCycles        = 1024;

  // ========================
  // Type Definitions - Matching ccu_fsm
  // ========================
  typedef logic [FullIdWidth-1:0]   id_t;
  typedef logic [AxiAddrWidth-1:0]  addr_t;
  typedef logic [AxiDataWidth-1:0]  data_t;
  typedef logic [AxiStrbWidth-1:0]  strb_t;
  typedef logic [AxiUserWidth-1:0]  user_t;

  // ACE Write Address Channel
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

  // ACE Read Address Channel
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

  // AXI Write Data Channel
  typedef struct packed {
    data_t data;
    strb_t strb;
    logic  last;
    user_t user;
  } w_chan_t;

  // AXI Write Response Channel
  typedef struct packed {
    id_t       id;
    logic [1:0] resp;
    user_t     user;
  } b_chan_t;

  // ACE Read Data Channel
  typedef struct packed {
    id_t       id;
    data_t     data;
    logic [3:0] resp;
    logic      last;
    user_t     user;
  } r_chan_t;

  // ACE Master Request
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

  // ACE Master Response
  typedef struct packed {
    logic     aw_ready;
    logic     ar_ready;
    logic     w_ready;
    logic     b_valid;
    b_chan_t  b;
    logic     r_valid;
    r_chan_t  r;
  } mst_resp_t;

  // Snoop Address/Command Channel
  typedef struct packed {
    addr_t      addr;
    logic [3:0] snoop;
    logic [2:0] prot;
  } ac_chan_t;

  // Snoop Data Channel
  typedef struct packed {
    data_t data;
    logic  last;
  } cd_chan_t;

  // Snoop Response Channel
  typedef struct packed {
    logic dataTransfer;
    logic error;
    logic passDirty;
    logic isShared;
    logic wasUnique;
  } crresp_t;

  // Snoop Request
  typedef struct packed {
    ac_chan_t ac;
    logic     ac_valid;
    logic     cr_ready;
    logic     cd_ready;
  } snoop_req_t;

  // Snoop Response
  typedef struct packed {
    logic     ac_ready;
    crresp_t  cr_resp;
    logic     cr_valid;
    cd_chan_t cd;
    logic     cd_valid;
  } snoop_resp_t;

  // Cache states
  typedef enum logic [1:0] {
    CACHE_INVALID = 2'b00,
    CACHE_SHARED  = 2'b01,
    CACHE_UNIQUE  = 2'b10,
    CACHE_DIRTY   = 2'b11
  } cache_state_t;

  // ========================
  // Clock and Reset
  // ========================


  // ========================
  // DUT Signals
  // ========================
  mst_req_t                    ccu_req_from_arb;
  mst_resp_t                   ccu_resp_to_arb;
  mst_req_t                    ccu_req_to_mem;
  mst_resp_t                   ccu_resp_from_mem;
  snoop_req_t  [NoMstPorts-1:0] snoop_req_to_slaves;
  snoop_resp_t [NoMstPorts-1:0] snoop_resp_from_slaves;

  // ========================
  // Slave Request Signals (to arbiter)
  // ========================
  mst_req_t  [NoMstPorts-1:0] slave_req;
  mst_resp_t [NoMstPorts-1:0] slave_resp;

  // ========================
  // DUT Instantiation
  // ========================
  ccu_fsm #(
    .DcacheLineWidth (DcacheLineWidth),
    .AxiDataWidth    (AxiDataWidth),
    .NoMstPorts      (NoMstPorts),
    .SlvAxiIDWidth   (SlvAxiIDWidth),
    .mst_req_t       (mst_req_t),
    .mst_resp_t      (mst_resp_t),
    .snoop_req_t     (snoop_req_t),
    .snoop_resp_t    (snoop_resp_t)
  ) i_ccu_fsm (
    .clk_i        (clk),
    .rst_ni       (rst_n),
    .ccu_req_i    (ccu_req_from_arb),
    .ccu_resp_o   (ccu_resp_to_arb),
    .ccu_req_o    (ccu_req_to_mem),
    .ccu_resp_i   (ccu_resp_from_mem),
    .s2m_req_o    (snoop_req_to_slaves),
    .m2s_resp_i   (snoop_resp_from_slaves)
  );

  // ========================
  // Memory Controller
  // ========================
  mem_controller #(
    .AxiDataWidth   (AxiDataWidth),
    .AxiAddrWidth   (AxiAddrWidth),
    .MemSize        (MemSize),
    .mst_req_t      (mst_req_t),
    .mst_resp_t     (mst_resp_t),
    .ar_chan_t      (ar_chan_t),
    .aw_chan_t      (aw_chan_t)
  ) i_mem_controller (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .req_i          (ccu_req_to_mem),
    .resp_o         (ccu_resp_from_mem)
  );

  // ========================
  // Arbiter
  // ========================
  arbiter #(
    .NoMstPorts     (NoMstPorts),
    .mst_req_t      (mst_req_t),
    .mst_resp_t     (mst_resp_t)
  ) i_arbiter (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .slave_req_i    (slave_req),
    .slave_resp_o   (slave_resp),
    .master_req_o   (ccu_req_from_arb),
    .master_resp_i  (ccu_resp_to_arb)
  );

  // ========================
  // Slave Instantiations
  // ========================
  genvar i;
  generate
    for (i = 0; i < NoMstPorts; i++) begin : gen_slaves
      ace_slave #(
        .SlaveId        (i),
        .AxiDataWidth   (AxiDataWidth),
        .AxiAddrWidth   (AxiAddrWidth),
        .SlvAxiIDWidth  (SlvAxiIDWidth),
        .MstIdxBits     (MstIdxBits),
        .mst_req_t      (mst_req_t),
        .mst_resp_t     (mst_resp_t),
        .snoop_req_t    (snoop_req_t),
        .snoop_resp_t   (snoop_resp_t),
        .ar_chan_t      (ar_chan_t),
        .aw_chan_t      (aw_chan_t),
        .w_chan_t       (w_chan_t),
        .ac_chan_t      (ac_chan_t),
        .cache_state_t  (cache_state_t),
        .CACHE_INVALID  (CACHE_INVALID),
        .CACHE_SHARED   (CACHE_SHARED),
        .CACHE_UNIQUE   (CACHE_UNIQUE),
        .CACHE_DIRTY    (CACHE_DIRTY)
      ) i_ace_slave (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .req_o          (slave_req[i]),
        .resp_i         (slave_resp[i]),
        .snoop_req_i    (snoop_req_to_slaves[i]),
        .snoop_resp_o   (snoop_resp_from_slaves[i])
      );
    end
  endgenerate

  logic [15:0] tb_cycle;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tb_cycle <= '0;
    end else begin
      tb_cycle <= tb_cycle + 16'd1;
      if (tb_cycle == 16'(SimCycles - 1)) begin
        $finish;
      end
    end
  end



endmodule
// ========================
// Memory Controller Module
// ========================
module mem_controller #(
  parameter int unsigned AxiDataWidth = 8,
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned MemSize = 256,
  parameter type mst_req_t = logic,
  parameter type mst_resp_t = logic,
  parameter type ar_chan_t = logic,
  parameter type aw_chan_t = logic
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  mst_req_t   req_i,
  output mst_resp_t  resp_o
);

  localparam int unsigned MemAddrBits = $clog2(MemSize);
  
  // Memory array
  logic [AxiDataWidth-1:0] mem [MemSize];
  logic [15:0] cycle_count;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= '0;
    end else begin
      cycle_count <= cycle_count + 16'd1;
    end
  end
  
  // State machine
  typedef enum logic [2:0] {
    IDLE,
    READ_WAIT,
    READ_RESP,
    WRITE_DATA,
    WRITE_RESP
  } state_t;
  
  state_t state_d, state_q;
  
  // Transaction storage
  ar_chan_t ar_holder;
  aw_chan_t aw_holder;
  logic [7:0] beat_count;
  logic [AxiAddrWidth-1:0] current_addr;
  
  // State register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
    end else begin
      state_q <= state_d;
    end
  end
  
  // State machine
  always_comb begin
    state_d = state_q;
    
    case (state_q)
      IDLE: begin
        if (req_i.ar_valid) begin
          state_d = READ_WAIT;
        end else if (req_i.aw_valid) begin
          state_d = WRITE_DATA;
        end
      end
      
      READ_WAIT: begin
        state_d = READ_RESP;
      end
      
      READ_RESP: begin
        if (req_i.r_ready && resp_o.r_valid && resp_o.r.last) begin
          state_d = IDLE;
        end
      end
      
      WRITE_DATA: begin
        if (req_i.w_valid && resp_o.w_ready && req_i.w.last) begin
          state_d = WRITE_RESP;
        end
      end
      
      WRITE_RESP: begin
        if (req_i.b_ready && resp_o.b_valid) begin
          state_d = IDLE;
        end
      end
      
      default: state_d = IDLE;
    endcase
  end
  
  // Hold AR request
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_holder <= '0;
      current_addr <= '0;
      beat_count <= '0;
    end else begin
      if (state_q == IDLE && req_i.ar_valid) begin
        ar_holder <= req_i.ar;
        current_addr <= req_i.ar.addr;
        beat_count <= '0;
      end else if (state_q == READ_RESP && req_i.r_ready && resp_o.r_valid) begin
        beat_count <= beat_count + 1;
        current_addr <= current_addr + 1;
      end
    end
  end
  
  // Hold AW request
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_holder <= '0;
    end else begin
      if (state_q == IDLE && req_i.aw_valid) begin
        aw_holder <= req_i.aw;
        current_addr <= req_i.aw.addr;
        beat_count <= '0;
      end else if (state_q == WRITE_DATA && req_i.w_valid && resp_o.w_ready) begin
        beat_count <= beat_count + 1;
        current_addr <= current_addr + 1;
      end
    end
  end
  
  // Write to memory
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < MemSize; i++) begin
        mem[i] <= '0;
      end
    end else if (state_q == WRITE_DATA && req_i.w_valid && resp_o.w_ready) begin
      mem[current_addr[MemAddrBits-1:0]] <= req_i.w.data;
`ifdef ACE_TB_DUT_TRACE
      $display("[Cycle %5d] Memory write addr %3d data %3d",
               cycle_count + 16'd1, current_addr[7:0], req_i.w.data);
`endif
    end
  end

`ifdef ACE_TB_DUT_TRACE
  always_ff @(posedge clk_i) begin
    if (rst_ni && state_q == READ_RESP && req_i.r_ready && resp_o.r_valid) begin
      $display("[Cycle %5d] Memory read addr %3d data %3d",
               cycle_count + 16'd1, current_addr[7:0], resp_o.r.data);
    end
  end
`endif
  
  // Output logic
  always_comb begin
    resp_o = '0;
    
    case (state_q)
      IDLE: begin
        resp_o.ar_ready = 1'b1;
        resp_o.aw_ready = 1'b1;
      end
      
      READ_RESP: begin
        resp_o.r_valid = 1'b1;
        resp_o.r.id = ar_holder.id;
        resp_o.r.data = mem[current_addr[MemAddrBits-1:0]];
        resp_o.r.resp = 4'b0000; // OKAY
        resp_o.r.last = (beat_count == ar_holder.len);
        resp_o.r.user = '0;
      end
      
      WRITE_DATA: begin
        resp_o.w_ready = 1'b1;
      end
      
      WRITE_RESP: begin
        resp_o.b_valid = 1'b1;
        resp_o.b.id = aw_holder.id;
        resp_o.b.resp = 2'b00; // OKAY
        resp_o.b.user = '0;
      end
    endcase
  end

`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
  wire f_ar_rcv = (state_q == IDLE) && req_i.ar_valid;      // ar_ready is 1 in IDLE
  // AR has priority in IDLE: an AW presented in the same cycle is handshaken
  // (aw_ready is 1) but not processed, so it is excluded from this view.
  wire f_aw_rcv = (state_q == IDLE) && req_i.aw_valid && !req_i.ar_valid;
  wire f_r_snd  = (state_q == READ_RESP) && req_i.r_ready;   // r_valid is 1 in READ_RESP
  wire f_w_rcv  = (state_q == WRITE_DATA) && req_i.w_valid;  // w_ready is 1 in WRITE_DATA
  wire f_b_snd  = (state_q == WRITE_RESP) && req_i.b_ready;  // b_valid is 1 in WRITE_RESP
  wire f_busy   = (state_q != IDLE);
`endif


endmodule

// ========================
// Round-Robin Arbiter Module
// ========================
module arbiter #(
  parameter int unsigned NoMstPorts = 4,
  parameter type mst_req_t = logic,
  parameter type mst_resp_t = logic
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  mst_req_t  [NoMstPorts-1:0] slave_req_i,
  output mst_resp_t [NoMstPorts-1:0] slave_resp_o,
  output mst_req_t                   master_req_o,
  input  mst_resp_t                  master_resp_i
);

  localparam int unsigned IdxBits = $clog2(NoMstPorts);
  
  // Arbiter state
  typedef enum logic [1:0] {
    ARB_IDLE,
    ARB_READ,
    ARB_WRITE
  } arb_state_t;
  
  arb_state_t state_d, state_q;
  logic [IdxBits-1:0] selected_d, selected_q;
  logic [IdxBits-1:0] rr_pointer_d, rr_pointer_q;
  
  // State register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ARB_IDLE;
      selected_q <= '0;
      rr_pointer_q <= '0;
    end else begin
      state_q <= state_d;
      selected_q <= selected_d;
      rr_pointer_q <= rr_pointer_d;
    end
  end
  
  // Arbiter logic
  always_comb begin
    state_d = state_q;
    selected_d = selected_q;
    rr_pointer_d = rr_pointer_q;
    master_req_o = '0;
    slave_resp_o = '0;
    
    case (state_q)
      ARB_IDLE: begin
        // Round-robin selection
        logic found;
        automatic int idx;
        found = 1'b0;
        
        // Search from current pointer
        for (int i = 0; i < NoMstPorts; i++) begin
          idx = (rr_pointer_q + i) % NoMstPorts;
          if (!found && (slave_req_i[idx].ar_valid || slave_req_i[idx].aw_valid)) begin
            selected_d = idx[IdxBits-1:0];
            rr_pointer_d = (idx + 1) % NoMstPorts;
            found = 1'b1;
            
            if (slave_req_i[idx].ar_valid) begin
              state_d = ARB_READ;
            end else begin
              state_d = ARB_WRITE;
            end
          end
        end
      end
      
      ARB_READ: begin
        // Forward selected slave's read request
        master_req_o.ar = slave_req_i[selected_q].ar;
        master_req_o.ar_valid = slave_req_i[selected_q].ar_valid;
        master_req_o.r_ready = slave_req_i[selected_q].r_ready;
        
        slave_resp_o[selected_q].ar_ready = master_resp_i.ar_ready;
        slave_resp_o[selected_q].r = master_resp_i.r;
        slave_resp_o[selected_q].r_valid = master_resp_i.r_valid;
        
        // Transaction complete when r_valid && r_ready && r_last
        if (master_resp_i.r_valid && slave_req_i[selected_q].r_ready && master_resp_i.r.last) begin
          state_d = ARB_IDLE;
        end
      end
      
      ARB_WRITE: begin
        // Forward selected slave's write request
        master_req_o.aw = slave_req_i[selected_q].aw;
        master_req_o.aw_valid = slave_req_i[selected_q].aw_valid;
        master_req_o.w = slave_req_i[selected_q].w;
        master_req_o.w_valid = slave_req_i[selected_q].w_valid;
        master_req_o.b_ready = slave_req_i[selected_q].b_ready;
        
        slave_resp_o[selected_q].aw_ready = master_resp_i.aw_ready;
        slave_resp_o[selected_q].w_ready = master_resp_i.w_ready;
        slave_resp_o[selected_q].b = master_resp_i.b;
        slave_resp_o[selected_q].b_valid = master_resp_i.b_valid;
        
        // Transaction complete when b_valid && b_ready
        if (master_resp_i.b_valid && slave_req_i[selected_q].b_ready) begin
          state_d = ARB_IDLE;
        end
      end
    endcase
  end

`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
  wire                 f_busy  = (state_q != ARB_IDLE);
  wire                 f_read  = (state_q == ARB_READ);
  wire                 f_write = (state_q == ARB_WRITE);
  wire [IdxBits-1:0]   f_sel   = selected_q;
`endif


endmodule

// ========================
// ACE Slave Module with Dual FSMs
// ========================
module ace_slave #(
  parameter int unsigned SlaveId = 0,
  parameter int unsigned AxiDataWidth = 8,
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned SlvAxiIDWidth = 1,
  parameter int unsigned MstIdxBits = 2,
  parameter type mst_req_t = logic,
  parameter type mst_resp_t = logic,
  parameter type snoop_req_t = logic,
  parameter type snoop_resp_t = logic,
  parameter type ar_chan_t = logic,
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type ac_chan_t = logic,
  parameter type cache_state_t = logic [1:0],
  parameter cache_state_t CACHE_INVALID = 2'b00,
  parameter cache_state_t CACHE_SHARED = 2'b01,
  parameter cache_state_t CACHE_UNIQUE = 2'b10,
  parameter cache_state_t CACHE_DIRTY = 2'b11
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  output mst_req_t   req_o,
  input  mst_resp_t  resp_i,
  input  snoop_req_t snoop_req_i,
  output snoop_resp_t snoop_resp_o
);

  localparam int unsigned DcacheLineWords = 2;
  localparam int unsigned CacheLines = 16; // Small cache for state tracking
  
  // Transaction types to cycle through
  typedef enum logic [2:0] {
    TX_READ_SHARED,
    TX_READ_UNIQUE,
    TX_CLEAN_UNIQUE,
    TX_WRITE_UNIQUE,
    TX_READ_NO_SNOOP
  } tx_type_t;
  
  // Request FSM states
  typedef enum logic [2:0] {
    REQ_IDLE,
    REQ_SEND_AR,
    REQ_WAIT_R,
    REQ_SEND_AW,
    REQ_SEND_W,
    REQ_WAIT_B
  } req_state_t;
  
  // Snoop FSM states
  typedef enum logic [1:0] {
    SNP_IDLE,
    SNP_WAIT_AC,
    SNP_SEND_CR,
    SNP_SEND_CD
  } snp_state_t;
  
  // FSM state registers
  req_state_t req_state_d, req_state_q;
  snp_state_t snp_state_d, snp_state_q;
  
  // Request FSM signals
  logic [31:0] cycle_count;
  logic [2:0] tx_type_count;
  tx_type_t current_tx_type;
  logic [AxiAddrWidth-1:0] req_addr;
  logic [7:0] r_beat_count;
  logic [7:0] addr_base;
  logic [7:0] delay_count;
  logic [7:0] write_data;
  
  // Snoop FSM signals
  ac_chan_t ac_holder;
  logic [7:0] cd_beat_count;
  
  // Simple cache state (per line)
  cache_state_t [CacheLines-1:0] cache_state;
  logic [CacheLines-1:0][DcacheLineWords-1:0][AxiDataWidth-1:0] cache_data;

  localparam logic [7:0] SlaveIdByte = SlaveId[7:0];
  
  // Helper function: get cache line index from address
  function automatic logic [$clog2(CacheLines)-1:0] get_line_idx(logic [AxiAddrWidth-1:0] addr);
    return addr[$clog2(CacheLines)-1:0];
  endfunction

  function automatic tx_type_t decode_tx_type(logic [2:0] tx_count);
    case (tx_count)
      3'd0: decode_tx_type = TX_READ_SHARED;
      3'd1: decode_tx_type = TX_READ_UNIQUE;
      3'd2: decode_tx_type = TX_CLEAN_UNIQUE;
      3'd3: decode_tx_type = TX_WRITE_UNIQUE;
      3'd4: decode_tx_type = TX_READ_NO_SNOOP;
      default: decode_tx_type = TX_READ_SHARED;
    endcase
  endfunction

  function automatic logic [2:0] next_tx_count(logic [2:0] tx_count);
    if (tx_count == 3'd4) begin
      next_tx_count = 3'd0;
    end else begin
      next_tx_count = tx_count + 3'd1;
    end
  endfunction

  function automatic logic [7:0] delay_for_tx(logic [2:0] tx_count);
    case (decode_tx_type(tx_count))
      TX_READ_SHARED:   delay_for_tx = 8'd2;
      TX_READ_UNIQUE:   delay_for_tx = 8'd2;
      TX_CLEAN_UNIQUE:  delay_for_tx = 8'd4;
      TX_WRITE_UNIQUE:  delay_for_tx = 8'd8;
      TX_READ_NO_SNOOP: delay_for_tx = 8'd16;
      default:          delay_for_tx = 8'd2;
    endcase
  endfunction
  
  // ========================
  // Request FSM
  // ========================
  
  // Cycle counter for matching the Anvil cache_client cycle waits.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
    end
  end
  
  assign current_tx_type = decode_tx_type(tx_type_count);
  assign write_data = cycle_count[7:0] + SlaveIdByte;
  
  // State register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_state_q <= REQ_IDLE;
      tx_type_count <= 0;
      req_addr <= '0;
      addr_base <= '0;
      delay_count <= delay_for_tx(3'd0);
    end else begin
      req_state_q <= req_state_d;

      if (req_state_q == REQ_IDLE) begin
        if (delay_count != 0) begin
          delay_count <= delay_count - 8'd1;
        end
        if (delay_count <= 8'd1) begin
          req_addr <= AxiAddrWidth'(addr_base + SlaveIdByte);
`ifdef ACE_TB_DUT_TRACE
          case (current_tx_type)
            TX_READ_SHARED: begin
              $display("[Cycle %5d] Client %10d read-shared addr %3d",
                       cycle_count + 32'd1, SlaveId, addr_base + SlaveIdByte);
            end
            TX_READ_UNIQUE: begin
              $display("[Cycle %5d] Client %10d read-unique addr %3d",
                       cycle_count + 32'd1, SlaveId, addr_base + SlaveIdByte);
            end
            TX_CLEAN_UNIQUE: begin
              $display("[Cycle %5d] Client %10d clean-unique addr %3d",
                       cycle_count + 32'd1, SlaveId, addr_base + SlaveIdByte);
            end
            TX_WRITE_UNIQUE: begin
              $display("[Cycle %5d] Client %10d write-unique addr %3d data %3d",
                       cycle_count + 32'd1, SlaveId, addr_base + SlaveIdByte,
                       cycle_count[7:0] + 8'd1 + SlaveIdByte);
            end
            TX_READ_NO_SNOOP: begin
              $display("[Cycle %5d] Client %10d read-no-snoop addr %3d",
                       cycle_count + 32'd1, SlaveId, addr_base + SlaveIdByte);
            end
            default: begin
            end
          endcase
`endif
        end
      end

      if ((req_state_q == REQ_WAIT_R && resp_i.r_valid && req_o.r_ready && resp_i.r.last) ||
          (req_state_q == REQ_WAIT_B && resp_i.b_valid && req_o.b_ready)) begin
        tx_type_count <= next_tx_count(tx_type_count);
        delay_count <= delay_for_tx(next_tx_count(tx_type_count));
        addr_base <= addr_base + 8'd1;
      end
    end
  end
  
`ifdef ACE_TB_DUT_TRACE
  always_ff @(posedge clk_i) begin
    if (rst_ni && req_state_q == REQ_WAIT_R && resp_i.r_valid && req_o.r_ready && resp_i.r.last) begin
      $display("[Cycle %0d] Client %0d response op %0d addr %0d data %0d ack %0d",
               cycle_count + 1, SlaveId, tx_type_count, req_addr[7:0], resp_i.r.data,
               current_tx_type == TX_CLEAN_UNIQUE);
    end
    if (rst_ni && req_state_q == REQ_WAIT_B && resp_i.b_valid && req_o.b_ready) begin
      $display("[Cycle %0d] Client %0d response op %0d addr %0d data 0 ack 1",
               cycle_count + 1, SlaveId, tx_type_count, req_addr[7:0]);
    end
  end
`endif

  // Beat counter
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      r_beat_count <= 0;
    end else begin
      if (req_state_q == REQ_WAIT_R && resp_i.r_valid && req_o.r_ready) begin
        r_beat_count <= r_beat_count + 1;
      end else if (req_state_q == REQ_IDLE) begin
        r_beat_count <= 0;
      end
    end
  end
  
  // Request FSM next state logic
  always_comb begin
    req_state_d = req_state_q;
    
    case (req_state_q)
      REQ_IDLE: begin
        if (delay_count <= 8'd1) begin
          if (current_tx_type == TX_WRITE_UNIQUE) begin
            req_state_d = REQ_SEND_AW;
          end else begin
            req_state_d = REQ_SEND_AR;
          end
        end
      end
      
      REQ_SEND_AR: begin
        if (resp_i.ar_ready) begin
          req_state_d = REQ_WAIT_R;
        end
      end
      
      REQ_WAIT_R: begin
        if (resp_i.r_valid && req_o.r_ready && resp_i.r.last) begin
          req_state_d = REQ_IDLE;
        end
      end
      
      REQ_SEND_AW: begin
        if (resp_i.aw_ready) begin
          req_state_d = REQ_SEND_W;
        end
      end
      
      REQ_SEND_W: begin
        if (resp_i.w_ready && req_o.w.last) begin
          req_state_d = REQ_WAIT_B;
        end
      end
      
      REQ_WAIT_B: begin
        if (resp_i.b_valid && req_o.b_ready) begin
          req_state_d = REQ_IDLE;
        end
      end
    endcase
  end
  
  // Request FSM output logic
  always_comb begin
    req_o = '0;
    
    case (req_state_q)
      REQ_SEND_AR, REQ_WAIT_R: begin
        req_o.ar_valid = (req_state_q == REQ_SEND_AR);
        req_o.ar.id = {MstIdxBits'(SlaveId), {SlvAxiIDWidth{1'b0}}};
        req_o.ar.addr = req_addr;
        req_o.ar.size = 3'b000; // 1 byte
        req_o.ar.burst = 2'b01; // INCR
        req_o.ar.domain = 2'b01; // Inner shareable
        req_o.ar.bar = 2'b00;
        req_o.r_ready = 1'b1;
        
        // Set snoop type based on transaction
        case (current_tx_type)
          TX_READ_SHARED: begin
            req_o.ar.snoop = 4'b0001; // READ_SHARED
            req_o.ar.len = 8'd0;
          end
          TX_READ_UNIQUE: begin
            req_o.ar.snoop = 4'b0111; // READ_UNIQUE
            req_o.ar.len = 8'd0;
          end
          TX_CLEAN_UNIQUE: begin
            req_o.ar.snoop = 4'b1011; // CLEAN_UNIQUE
            req_o.ar.len = 8'd0; // No data
          end
          TX_READ_NO_SNOOP: begin
            req_o.ar.snoop = 4'b0000; // READ_NO_SNOOP
            req_o.ar.domain = 2'b00; // Non-shareable
            req_o.ar.len = 8'd0; // Single beat
          end
          default: begin
            req_o.ar.snoop = 4'b0001;
            req_o.ar.len = 8'd0;
          end
        endcase
      end
      
      REQ_SEND_AW, REQ_SEND_W, REQ_WAIT_B: begin
        if (req_state_q == REQ_SEND_AW) begin
          req_o.aw_valid = 1'b1;
          req_o.aw.id = {MstIdxBits'(SlaveId), {SlvAxiIDWidth{1'b0}}};
          req_o.aw.addr = req_addr;
          req_o.aw.len = 8'd0;
          req_o.aw.size = 3'b000;
          req_o.aw.burst = 2'b01; // INCR
          req_o.aw.snoop = 3'b000; // WRITE_UNIQUE
          req_o.aw.domain = 2'b01; // Inner shareable
          req_o.aw.bar = 2'b00;
        end
        
        if (req_state_q == REQ_SEND_W) begin
          req_o.w_valid = 1'b1;
          req_o.w.data = write_data;
          req_o.w.strb = '1;
          req_o.w.last = 1'b1;
        end
        
        if (req_state_q == REQ_WAIT_B) begin
          req_o.b_ready = 1'b1;
        end
      end
    endcase
  end
  
  // ========================
  // Snoop FSM
  // ========================
  
  // State register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      snp_state_q <= SNP_IDLE;
      ac_holder <= '0;
      cd_beat_count <= 0;
    end else begin
      snp_state_q <= snp_state_d;
      
      if (snp_state_q == SNP_IDLE && snoop_req_i.ac_valid) begin
        ac_holder <= snoop_req_i.ac;
      end
      
      if (snp_state_q == SNP_SEND_CD && snoop_req_i.cd_ready && snoop_resp_o.cd_valid) begin
        cd_beat_count <= cd_beat_count + 1;
      end else if (snp_state_q == SNP_IDLE) begin
        cd_beat_count <= 0;
      end
    end
  end
  
  // Snoop FSM next state logic
  always_comb begin
    snp_state_d = snp_state_q;
    
    case (snp_state_q)
      SNP_IDLE: begin
        if (snoop_req_i.ac_valid) begin
          snp_state_d = SNP_WAIT_AC;
        end
      end
      
      SNP_WAIT_AC: begin
        snp_state_d = SNP_SEND_CR;
      end
      
      SNP_SEND_CR: begin
        if (snoop_req_i.cr_ready && snoop_resp_o.cr_valid) begin
          // Check if we need to send data
          if (snoop_resp_o.cr_resp.dataTransfer) begin
            snp_state_d = SNP_SEND_CD;
          end else begin
            snp_state_d = SNP_IDLE;
          end
        end
      end
      
      SNP_SEND_CD: begin
        if (snoop_req_i.cd_ready && snoop_resp_o.cd_valid && snoop_resp_o.cd.last) begin
          snp_state_d = SNP_IDLE;
        end
      end
    endcase
  end
  
  // Snoop FSM output logic
  always_comb begin
    logic [$clog2(CacheLines)-1:0] line_idx;
    cache_state_t current_state;
    
    snoop_resp_o = '0;
    line_idx = get_line_idx(ac_holder.addr);
    current_state = cache_state[line_idx];
    
    case (snp_state_q)
      SNP_WAIT_AC: begin
        snoop_resp_o.ac_ready = 1'b1;
      end
      
      SNP_SEND_CR: begin
        snoop_resp_o.cr_valid = 1'b1;
        
        // Response based on snoop command and current state
        case (ac_holder.snoop)
          4'b1001: begin // CLEAN_INVALID
            snoop_resp_o.cr_resp.dataTransfer = (current_state == CACHE_DIRTY);
            snoop_resp_o.cr_resp.passDirty = (current_state == CACHE_DIRTY);
            snoop_resp_o.cr_resp.error = 1'b0;
            snoop_resp_o.cr_resp.isShared = 1'b0;
            snoop_resp_o.cr_resp.wasUnique = (current_state == CACHE_UNIQUE || 
                                              current_state == CACHE_DIRTY);
          end
          
          4'b0001: begin // READ_SHARED
            snoop_resp_o.cr_resp.dataTransfer = (current_state == CACHE_DIRTY || 
                                                 current_state == CACHE_UNIQUE);
            snoop_resp_o.cr_resp.passDirty = (current_state == CACHE_DIRTY);
            snoop_resp_o.cr_resp.error = 1'b0;
            snoop_resp_o.cr_resp.isShared = (current_state == CACHE_SHARED);
            snoop_resp_o.cr_resp.wasUnique = (current_state == CACHE_UNIQUE || 
                                              current_state == CACHE_DIRTY);
          end
          
          4'b0111: begin // READ_UNIQUE
            snoop_resp_o.cr_resp.dataTransfer = (current_state == CACHE_DIRTY);
            snoop_resp_o.cr_resp.passDirty = (current_state == CACHE_DIRTY);
            snoop_resp_o.cr_resp.error = 1'b0;
            snoop_resp_o.cr_resp.isShared = 1'b0;
            snoop_resp_o.cr_resp.wasUnique = (current_state == CACHE_UNIQUE || 
                                              current_state == CACHE_DIRTY);
          end
          
          default: begin
            snoop_resp_o.cr_resp.dataTransfer = 1'b0;
            snoop_resp_o.cr_resp.error = 1'b0;
          end
        endcase
      end
      
      SNP_SEND_CD: begin
        snoop_resp_o.cd_valid = 1'b1;
        snoop_resp_o.cd.data = cache_data[line_idx][cd_beat_count[0]];
        snoop_resp_o.cd.last = (cd_beat_count == 8'(DcacheLineWords - 1));
      end
    endcase
  end
  
  // Update cache state based on snoop commands
  always_ff @(posedge clk_i or negedge rst_ni) begin
    logic [$clog2(CacheLines)-1:0] line_idx;
    
    if (!rst_ni) begin
      for (int i = 0; i < CacheLines; i++) begin
        cache_state[i] <= CACHE_INVALID;
        for (int j = 0; j < DcacheLineWords; j++) begin
          cache_data[i][j] <= '0;
        end
      end
    end else begin
      line_idx = get_line_idx(ac_holder.addr);
      
      // Update state on CR valid
      if (snp_state_q == SNP_SEND_CR && snoop_req_i.cr_ready && snoop_resp_o.cr_valid) begin
        case (ac_holder.snoop)
          4'b1001: cache_state[line_idx] <= CACHE_INVALID; // CLEAN_INVALID
          4'b0001: begin // READ_SHARED
            if (cache_state[line_idx] != CACHE_INVALID) begin
              cache_state[line_idx] <= CACHE_SHARED;
            end
          end
          4'b0111: cache_state[line_idx] <= CACHE_INVALID; // READ_UNIQUE
        endcase
      end
      
      // Update state on request completion
      if (req_state_q == REQ_WAIT_R && resp_i.r_valid && req_o.r_ready &&
          current_tx_type != TX_CLEAN_UNIQUE && current_tx_type != TX_READ_NO_SNOOP) begin
        line_idx = get_line_idx(req_addr);
        cache_data[line_idx][r_beat_count[0]] <= resp_i.r.data;
        if (resp_i.r.last && r_beat_count == 0) begin
          cache_data[line_idx][1] <= resp_i.r.data;
        end
      end

      if (req_state_q == REQ_WAIT_R && resp_i.r_valid && req_o.r_ready && resp_i.r.last) begin
        line_idx = get_line_idx(req_addr);
        case (current_tx_type)
          TX_READ_SHARED: cache_state[line_idx] <= CACHE_SHARED;
          TX_READ_UNIQUE: cache_state[line_idx] <= CACHE_UNIQUE;
          TX_CLEAN_UNIQUE: cache_state[line_idx] <= CACHE_UNIQUE;
          default: cache_state[line_idx] <= CACHE_INVALID;
        endcase
      end
      
      if (req_state_q == REQ_WAIT_B && resp_i.b_valid && req_o.b_ready) begin
        line_idx = get_line_idx(req_addr);
        cache_state[line_idx] <= CACHE_DIRTY;
        for (int j = 0; j < DcacheLineWords; j++) begin
          cache_data[line_idx][j] <= write_data;
        end
      end
    end
  end

`ifdef FORMAL_COMM_SAFETY
  // Communication-safety self-report, read hierarchically by the formal
  // harness in formal/comm_safety/sv/comm_safety_tb_wrappers.sv. Each f_*
  // signal is this participant's OWN view of an exchange: the condition under
  // which its FSM treats the message as done in this cycle.
  // Request FSM (client side of the cache-request channel).
  wire f_ar_snd   = (req_state_q == REQ_SEND_AR) && resp_i.ar_ready;   // ar_valid is 1 in SEND_AR
  wire f_r_rcv    = (req_state_q == REQ_WAIT_R) && resp_i.r_valid && req_o.r_ready;
  wire f_aw_snd   = (req_state_q == REQ_SEND_AW) && resp_i.aw_ready;   // aw_valid is 1 in SEND_AW
  wire f_w_snd    = (req_state_q == REQ_SEND_W) && resp_i.w_ready;     // w_valid is 1 in SEND_W
  wire f_b_rcv    = (req_state_q == REQ_WAIT_B) && resp_i.b_valid && req_o.b_ready;
  wire f_req_busy = (req_state_q != REQ_IDLE);
  // Snoop FSM. The FSM samples ac_valid in SNP_IDLE but only raises ac_ready in
  // SNP_WAIT_AC, so the handshake it relies on is the one in SNP_WAIT_AC.
  wire f_ac_rcv   = (snp_state_q == SNP_WAIT_AC);
  wire f_cr_snd   = (snp_state_q == SNP_SEND_CR) && snoop_req_i.cr_ready;  // cr_valid is 1 in SEND_CR
  wire f_cd_snd   = (snp_state_q == SNP_SEND_CD) && snoop_req_i.cd_ready;  // cd_valid is 1 in SEND_CD
  wire f_snp_busy = (snp_state_q != SNP_IDLE);
`endif


endmodule
