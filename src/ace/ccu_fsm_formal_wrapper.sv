

module ccu_fsm_formal_wrapper;

  localparam int unsigned AxiDataWidth     = 8;
  localparam int unsigned DcacheLineWidth  = 16;  // Must be 2*AxiDataWidth per module constraint
  localparam int unsigned NoMstPorts       = 2;   // 2 master ports
  localparam int unsigned SlvAxiIDWidth    = 1;   // 1-bit ID
  localparam int unsigned AxiAddrWidth     = 32;  // 32-bit address
  localparam int unsigned AxiStrbWidth     = AxiDataWidth / 8;
  localparam int unsigned AxiUserWidth     = 1;
  
  localparam int unsigned MstIdxBits       = $clog2(NoMstPorts);
  localparam int unsigned FullIdWidth      = SlvAxiIDWidth + MstIdxBits;

  
  // Basic types
  typedef logic [FullIdWidth-1:0]   id_t;
  typedef logic [AxiAddrWidth-1:0]  addr_t;
  typedef logic [AxiDataWidth-1:0]  data_t;
  typedef logic [AxiStrbWidth-1:0]  strb_t;
  typedef logic [AxiUserWidth-1:0]  user_t;

  // ACE Write Address Channel
  typedef struct packed {
    id_t        id;
    addr_t      addr;
    logic [7:0] len;      // burst length
    logic [2:0] size;     // burst size
    logic [1:0] burst;    // burst type
    logic       lock;     // atomic access
    logic [3:0] cache;    // cache attributes
    logic [2:0] prot;     // protection
    logic [3:0] qos;      // quality of service
    logic [3:0] region;   // region identifier
    logic [5:0] atop;     // atomic operation
    user_t      user;     // user signal
    // ACE-specific
    logic [2:0] snoop;    // snoop type
    logic [1:0] bar;      // barrier
    logic [1:0] domain;   // domain
    logic       awunique; // write unique
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
    // ACE-specific
    logic [3:0] snoop;    // snoop type (4-bit for reads)
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
    logic [3:0] resp;  // 4-bit for ACE (includes RACK/WACK)
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
    logic [3:0] snoop;  // snoop transaction type
    logic [2:0] prot;
  } ac_chan_t;

  // Snoop Data Channel
  typedef struct packed {
    data_t data;
    logic  last;
  } cd_chan_t;

  // Snoop Response Channel (5-bit packed)
  typedef struct packed {
    logic dataTransfer;  // bit 0
    logic error;         // bit 1
    logic passDirty;     // bit 2
    logic isShared;      // bit 3
    logic wasUnique;     // bit 4
  } crresp_t;

  // Snoop Request (Master to Slave)
  typedef struct packed {
    ac_chan_t ac;
    logic     ac_valid;
    logic     cr_ready;
    logic     cd_ready;
  } snoop_req_t;

  // Snoop Response (Slave to Master)
  typedef struct packed {
    logic     ac_ready;
    crresp_t  cr_resp;
    logic     cr_valid;
    cd_chan_t cd;
    logic     cd_valid;
  } snoop_resp_t;

  logic                       clk;
  logic                       rst_n;
  
  mst_req_t                   ccu_req_i;
  mst_resp_t                  ccu_resp_o;
  
  mst_req_t                   ccu_req_o;
  mst_resp_t                  ccu_resp_i;
  
  snoop_req_t  [NoMstPorts-1:0] s2m_req_o;
  snoop_resp_t [NoMstPorts-1:0] m2s_resp_i;

  ccu_fsm #(
    .DcacheLineWidth ( DcacheLineWidth ),
    .AxiDataWidth    ( AxiDataWidth    ),
    .NoMstPorts      ( NoMstPorts      ),
    .SlvAxiIDWidth   ( SlvAxiIDWidth   ),
    .mst_req_t       ( mst_req_t       ),
    .mst_resp_t      ( mst_resp_t      ),
    .snoop_req_t     ( snoop_req_t     ),
    .snoop_resp_t    ( snoop_resp_t    )
  ) i_ccu_fsm (
    .clk_i       ( clk         ),
    .rst_ni      ( rst_n       ),
    .ccu_req_i   ( ccu_req_i   ),
    .ccu_resp_o  ( ccu_resp_o  ),
    .ccu_req_o   ( ccu_req_o   ),
    .ccu_resp_i  ( ccu_resp_i  ),
    .s2m_req_o   ( s2m_req_o   ),
    .m2s_resp_i  ( m2s_resp_i  )
  );


endmodule
