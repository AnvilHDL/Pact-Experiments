

// Wrapper for AES key expansion module

module aes_sub_bytes_wrapper(
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[129:0] _ep_req_0,
  input logic[0:0] _ep_req_valid,
  output logic[127:0] _ep_res_0
);
aes_pkg::sp2v_e out_valid, out_ack,en;
assign out_ack = out_valid == aes_pkg::SP2V_HIGH ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
assign en = _ep_req_valid ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;

aes_sub_bytes #(
  .SecSBoxImpl(aes_pkg::SBoxImplLut)
) dut (
  .clk_i,
  .rst_ni,
  .en_i(en),
  .out_req_o(out_valid),
  .out_ack_i(out_ack),
  .op_i(_ep_req_0[0+:2]),
  .data_i(_ep_req_0[2+:128]),
  .mask_i('0),
  .prd_i(0),
  .data_o(_ep_res_0),
  .mask_o(),
  .err_o()
);

endmodule 
module aes_key_expand_wrapper (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[0:0] _ep_init_valid,
  input logic[4:0] _ep_init_0,
  output logic[0:0] _ep_req_ack,
  input logic[0:0] _ep_req_valid,
  input logic[264:0] _ep_req_0,
  output logic[256:0] _ep_res_0
);

          aes_pkg::sp2v_e en,out_valid,out_ack;
          assign out_ack =  _ep_req_valid && (out_valid == aes_pkg::SP2V_HIGH) ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
          assign en = _ep_req_valid ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
          
          // Simulate req_ack as always high for this simple test
          assign _ep_req_ack = 1'b1;

          // Convert 256-bit key to 8x32 format for OpenTitan
          logic [7:0][31:0] key_input [1];
          logic [7:0][31:0] key_output [1];
          
          // Pack the key correctly
          always_comb begin
            for (int i = 0; i < 8; i++) begin
              key_input[0][i] = _ep_req_0[9 + i*32 +: 32];
            end
          end
          
          // Pack output key
          always_comb begin
            for (int i = 0; i < 8; i++) begin
              _ep_res_0[((i*32)+1) +: 32] = key_output[0][i];
            end
            _ep_res_0[0] = 1'b0; // err_o
          end

          aes_key_expand #(
            .AES192Enable (0),
            .SecMasking   (0),
            .SecSBoxImpl  (aes_pkg::SBoxImplLut)
          ) dut (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .cfg_valid_i (1'b1),
            .op_i (aes_pkg::ciph_op_e'(_ep_init_0[4:3])),
            .en_i (en),
            .prd_we_i (1'b0),
            .out_req_o (out_valid),
            .out_ack_i (out_ack),
            .clear_i (_ep_init_valid),
            .round_i (_ep_req_0[5+:4]),
            .key_len_i(aes_pkg::key_len_e'(_ep_init_0[0+:3])),
            .key_i(key_input),
            .prd_i(32'h0),
            .key_o(key_output),
            .err_o ()
        );

endmodule



module aes_shift_rows_wrapper(
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[129:0] _ep_req_0,
  output logic[127:0] _ep_res_0
);
aes_pkg::sp2v_e out_valid, out_ack;
assign out_ack = out_valid == aes_pkg::SP2V_HIGH ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
aes_shift_rows dut (
  .op_i(_ep_req_0[0+:2]),
  .data_i(_ep_req_0[2+:128]),
  .data_o(_ep_res_0)
);

endmodule


module aes_mix_columns_wrapper(
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  input logic[129:0] _ep_req_0,
  output logic[127:0] _ep_res_0
);
aes_pkg::sp2v_e out_valid, out_ack;
assign out_ack = out_valid == aes_pkg::SP2V_HIGH ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
aes_mix_columns dut(
  .op_i(_ep_req_0[0+:2]),
  .data_i(_ep_req_0[2+:128]),
  .data_o(_ep_res_0)
);

endmodule


module aes_cipher_core_wrapper (
  input logic[0:0] clk_i,
  input logic[0:0] rst_ni,
  output logic[0:0] _ep_dec_key_gen_req_ack,
  input logic[0:0] _ep_dec_key_gen_req_valid,
  input logic[0:0] _ep_dec_key_gen_req_0,
  input logic[255:0] _ep_key_pack_0,
  input logic[2:0] _ep_key_len_i_0,
  output logic[0:0] _ep_crypt_ack,
  input logic[0:0] _ep_crypt_valid,
  input logic[127:0] _ep_crypt_0,
  input logic[5:0] _ep_ctrl_0,
  // input logic[0:0] _ep_crypt_res_ack,
  output logic[0:0] _ep_crypt_res_valid,
  output logic[257:0] _ep_crypt_res_0,
  output logic [0:0] _ep_dec_key_gen_res_ack,
  output logic[0:0] _ep_dec_key_gen_res_valid,
  output logic[0:0] _ep_dec_key_gen_res_0,
  input logic[0:0] _ep_data_out_clear_i_valid,
  input logic[127:0] _ep_data_out_clear_i_0,
  input logic[0:0] _ep_key_clear_i_valid,
  input logic[255:0] _ep_key_clear_i_0,
  output logic[0:0] _ep_data_out_clear_o_0,
  output logic[0:0] _ep_key_clear_o_0,
  input logic[0:0] _entr_ep_req_ack,
  output logic[0:0] _entr_ep_req_valid,
  output logic[0:0] _entr_ep_req_0,
  input logic[0:0] _entr_ep_res_0
);

  localparam int NumShares = 1;
  localparam int EntropyWidth = 1;

  aes_pkg::sp2v_e                       in_valid_i;
  aes_pkg::sp2v_e                       in_ready_o;
  aes_pkg::sp2v_e                       out_valid_o;
  aes_pkg::sp2v_e                       out_ready_i;
  aes_pkg::ciph_op_e                    op_i;
  aes_pkg::sp2v_e                       crypt_i;
  aes_pkg::sp2v_e                       crypt_o;
  aes_pkg::sp2v_e                       dec_key_gen_i;
  aes_pkg::sp2v_e                       dec_key_gen_o;
  logic                        data_out_clear_i;
  logic                        data_out_clear_o;
  logic                        alert_fatal_i;
  logic                        alert_o;
  logic                        cfg_valid_i; // Used for gating assertions only.
  
  aes_pkg::key_len_e                    key_len_i;
  logic                        prng_reseed_i;
  logic                        prng_reseed_o;
  logic                        key_clear_i;
  logic                        key_clear_o;
  
  logic        [3:0][3:0][7:0] prd_clearing_state_i [NumShares];
  logic            [7:0][31:0] prd_clearing_key_i [NumShares];

  
  logic                        force_masks_i;
  logic        [3:0][3:0][7:0] data_in_mask_o;
  logic                        entropy_req_o;
  logic                        entropy_ack_i;
  logic     [EntropyWidth-1:0] entropy_i;

  
  logic        [3:0][3:0][7:0] state_init_i [NumShares];
  logic            [7:0][31:0] key_init_i [NumShares];
  logic        [3:0][3:0][7:0] state_o [NumShares];
  
  assign in_valid_i = (_ep_crypt_valid | _ep_dec_key_gen_req_valid)&(in_ready_o == aes_pkg::SP2V_HIGH) ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
  assign out_ready_i = ((_ep_crypt_res_valid == 1'd1)||(_ep_dec_key_gen_res_ack == 1'd1)) ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
  assign op_i = aes_pkg::ciph_op_e'(_ep_ctrl_0[0+:2]);
  assign cfg_valid_i = _ep_ctrl_0[2];
  assign crypt_i = (_ep_crypt_valid) ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
  assign dec_key_gen_i = (_ep_dec_key_gen_req_valid) ? aes_pkg::SP2V_HIGH : aes_pkg::SP2V_LOW;
  assign state_init_i[0] = _ep_crypt_0;
  assign key_init_i[0] = _ep_key_pack_0[0+:256];
  assign key_len_i = aes_pkg::key_len_e'(_ep_key_len_i_0);
  assign prng_reseed_i = _ep_ctrl_0[5];
  assign key_clear_i = _ep_key_clear_i_valid;
  assign data_out_clear_i = _ep_data_out_clear_i_valid;
  assign alert_fatal_i = _ep_ctrl_0[4];
  assign force_masks_i = _ep_ctrl_0[3];
  assign prd_clearing_key_i[0] = _ep_key_clear_i_0;
  assign prd_clearing_state_i[0] = _ep_data_out_clear_i_0;
  assign entropy_ack_i = _entr_ep_req_ack;
  assign entropy_i = _entr_ep_res_0; 
  


  //Output Ports

  assign _ep_crypt_ack = (in_ready_o == aes_pkg::SP2V_HIGH && _ep_crypt_valid == 1'd1) ? 1'b1 : 1'b0;
  assign _ep_dec_key_gen_req_ack = (in_ready_o == aes_pkg::SP2V_HIGH && _ep_dec_key_gen_req_valid == 1'd1) ? 1'b1 : 1'b0;
  assign _ep_crypt_res_valid = ((out_valid_o == aes_pkg::SP2V_HIGH)&&(crypt_o == aes_pkg::SP2V_HIGH)) ? 1'b1 : 1'b0;
  assign _ep_dec_key_gen_res_valid = ((out_valid_o == aes_pkg::SP2V_HIGH)&&(dec_key_gen_o == aes_pkg::SP2V_HIGH)) ? 1'b1 : 1'b0;
  assign _ep_crypt_res_0[0+:128] = state_o[0];
  assign _ep_crypt_res_0[128] = prng_reseed_o;
  assign _ep_key_clear_o_0 = key_clear_o;
  assign _ep_data_out_clear_o_0 = data_out_clear_o;
  assign _ep_crypt_res_0[129] = alert_o;
  assign _ep_crypt_res_0[130+:128] = data_in_mask_o[0];
  assign _ep_dec_key_gen_res_0[0] = alert_o;
  assign _entr_ep_req_valid = entropy_req_o;
  assign _entr_ep_req_0 =entropy_req_o;


  aes_cipher_core #(
    .AES192Enable(0),
    .CiphOpFwdOnly(0),
    .SecMasking(0),
    .SecSBoxImpl(aes_pkg::SBoxImplLut),
    .SecAllowForcingMasks(0),
    .SecSkipPRNGReseeding(0),
    .EntropyWidth(EntropyWidth)
  ) dut_core (
    .clk_i,
    .rst_ni,
    .cfg_valid_i(cfg_valid_i), // Always valid for this wrapper
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .op_i(op_i),
    .key_len_i(key_len_i),
    .crypt_i(crypt_i),
    .crypt_o(crypt_o),
    .dec_key_gen_i(dec_key_gen_i),
    .dec_key_gen_o(dec_key_gen_o),

    .prng_reseed_i(prng_reseed_i),
    .prng_reseed_o(prng_reseed_o),
    .key_clear_i(key_clear_i),
    .key_clear_o(key_clear_o),
    .data_out_clear_i(data_out_clear_i),
    .data_out_clear_o(data_out_clear_o),
    .alert_fatal_i(alert_fatal_i),
    .alert_o(alert_o),
    .prd_clearing_state_i(prd_clearing_state_i),
    .prd_clearing_key_i(prd_clearing_key_i),
    .force_masks_i(force_masks_i),
    .data_in_mask_o(data_in_mask_o),
    .entropy_req_o(entropy_req_o),
    .entropy_ack_i(entropy_ack_i),
    .entropy_i(entropy_i), // Not used in this wrapper
    .state_init_i(state_init_i),
    .key_init_i(key_init_i),
    .state_o(state_o)
  );

endmodule