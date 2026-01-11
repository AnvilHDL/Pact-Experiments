module cva6_tlb
import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type pte_cva6_t = logic,
    parameter type tlb_update_cva6_t = logic,
    parameter int unsigned TLB_ENTRIES = 4,
    parameter int unsigned HYP_EXT = 0
) (
    input logic clk_i,  // Clock
    input logic rst_ni,  // Asynchronous reset active low
    input logic flush_i,  // Flush normal translations signal
    input logic flush_vvma_i,  // Flush vs stage signal
    input logic flush_gvma_i,  // Flush g stage signal
    input logic s_st_enbl_i,  // s-stage enabled
    input logic g_st_enbl_i,  // g-stage enabled
    input logic v_i,  // virtualization mode
    // Update TLB
    input tlb_update_cva6_t update_i,
    // Lookup signals
    input logic lu_access_i,
    input logic [CVA6Cfg.ASID_WIDTH-1:0] lu_asid_i,
    input logic [CVA6Cfg.VMID_WIDTH-1:0] lu_vmid_i,
    input logic [CVA6Cfg.VLEN-1:0] lu_vaddr_i,
    output logic [CVA6Cfg.GPLEN-1:0] lu_gpaddr_o,
    output pte_cva6_t lu_content_o,
    output pte_cva6_t lu_g_content_o,
    input logic [CVA6Cfg.ASID_WIDTH-1:0] asid_to_be_flushed_i,
    input logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_to_be_flushed_i,
    input logic [CVA6Cfg.VLEN-1:0] vaddr_to_be_flushed_i,
    input logic [CVA6Cfg.GPLEN-1:0] gpaddr_to_be_flushed_i,
    output logic [CVA6Cfg.PtLevels-2:0] lu_is_page_o,
    output logic lu_hit_o
);


logic [65:0] tmp_content;

assign lu_gpaddr_o = '0;
assign lu_g_content_o = '0;
assign lu_content_o = lu_access_i?pte_cva6_t'(tmp_content[65:2]):64'd0;
assign lu_is_page_o[1:0] = lu_access_i?tmp_content[1:0]:2'd0;
    
anvil_tlb tlb_cva(
    //Inputs
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    ._lu_ch_req_0({lu_access_i,s_st_enbl_i,lu_asid_i,lu_vaddr_i}),
    ._flush_issue_ch_req_0({flush_i,asid_to_be_flushed_i,vaddr_to_be_flushed_i}),
    ._update_ch_req_0({update_i.valid,update_i.v_st_enbl[0],update_i.is_page,update_i.vpn,update_i.asid,update_i.content}),
    //Outputs
    ._lu_ch_hit_0(lu_hit_o),
    ._lu_ch_res_0(tmp_content)
);

// end
endmodule