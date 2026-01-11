module cva6_ptw
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type pte_cva6_t = logic,
    parameter type tlb_update_cva6_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter int unsigned HYP_EXT = 0
) (
    input logic clk_i,  // Clock
    input logic rst_ni,  // Asynchronous reset active low
    input logic flush_i,  // flush everything, we need to do this because
                          // actually everything we do is speculative at this stage
                          // e.g.: there could be a CSR instruction that changes everything
    output logic ptw_active_o,
    output logic walking_instr_o,  // set when walking for TLB
    output logic ptw_error_o,  // set when an error occurred
    output logic ptw_error_at_g_st_o,  // set when an error occurred at the G-Stage
    output logic ptw_err_at_g_int_st_o,  // set when an error occurred at the G-Stage during S-Stage translation
    output logic ptw_access_exception_o,  // set when an PMP access exception occured
    input logic enable_translation_i,  // CSRs indicate to enable SV39 VS-Stage translation
    input logic enable_g_translation_i,  // CSRs indicate to enable SV39  G-Stage translation
    input logic en_ld_st_translation_i,  // enable virtual memory translation for load/stores
    input logic en_ld_st_g_translation_i,  // enable G-Stage translation for load/stores
    input logic v_i,  // current virtualization mode bit
    input logic ld_st_v_i,  // load/store virtualization mode bit
    input logic hlvx_inst_i,  // is a HLVX load/store instruction

    input  logic          lsu_is_store_i,  // this translation was triggered by a store
    // PTW memory interface
    input  dcache_req_o_t req_port_i,
    output dcache_req_i_t req_port_o,


    // to TLBs, update logic
    output tlb_update_cva6_t shared_tlb_update_o,

    output logic [CVA6Cfg.VLEN-1:0] update_vaddr_o,

    input logic [CVA6Cfg.ASID_WIDTH-1:0] asid_i,
    input logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_i,
    input logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_i,

    // from TLBs
    // did we miss?
    input logic                    shared_tlb_access_i,
    input logic                    shared_tlb_hit_i,
    input logic [CVA6Cfg.VLEN-1:0] shared_tlb_vaddr_i,

    input logic itlb_req_i,

    // from CSR file
    input logic [CVA6Cfg.PPNW-1:0] satp_ppn_i,   // ppn from satp
    input logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_i,  // ppn from satp
    input logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_i,  // ppn from hgatp
    input logic                    mxr_i,
    input logic                    vmxr_i,

    // Performance counters
    output logic shared_tlb_miss_o,

    // PMP
    input riscv::pmpcfg_t [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0] pmpcfg_i,
    input logic [(CVA6Cfg.NrPMPEntries > 0 ? CVA6Cfg.NrPMPEntries-1 : 0):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,
    output logic [CVA6Cfg.PLEN-1:0] bad_paddr_o,
    output logic [CVA6Cfg.GPLEN-1:0] bad_gpaddr_o
);


  
  
    logic[0:0] _mmu_ch_req_ack;
    logic[0:0] _mmu_ch_req_valid;
    logic[65:0] _mmu_ch_req_0;
    logic[61:0] _mmu_ch_csr_0;
    logic[0:0] _mmu_ch_mxr_0;
    logic[0:0] _mmu_ch_lsu_req_0;
    logic[0:0] _mmu_ch_miss_o_0;
    logic[0:0] _mmu_ch_tlb_res_valid;
    logic[108:0] _mmu_ch_tlb_res_0;
    logic[63:0] _mmu_ch_update_vaddr_o_0;
    logic[0:0] _mmu_ch_res_valid;
    logic[98:0] _mmu_ch_res_0;
    logic[0:0] _mmu_ch_status_0;
    logic[0:0] _mmu_ch_walking_instr_o_0;
    // logic[63:0] _mmu_ch_pmp_cfg_0;
    // logic[447:0] _mmu_ch_pmp_addr_0;
    logic[0:0] _dcache_ch_req_valid;
    logic[0:0] _dcache_ch_req_0;
    logic[0:0] _dcache_ch_gnt_0;
    logic[0:0] _dcache_ch_data_req_valid;
    logic[133:0] _dcache_ch_data_req_0;
    logic[0:0] _dcache_ch_data_res_ack;
    logic[0:0] _dcache_ch_data_res_valid;
    logic[67:0] _dcache_ch_data_res_0;
    logic[0:0] _flush_ch_req_valid;
    logic[0:0] _flush_ch_req_0;
    logic [55:0] pmp_addr;
    logic allow_access;



// Input Assignments
    assign _mmu_ch_req_valid = shared_tlb_access_i;
    assign _mmu_ch_req_0 = {shared_tlb_hit_i, itlb_req_i, shared_tlb_vaddr_i};
    assign _mmu_ch_csr_0 = {en_ld_st_translation_i, asid_i, satp_ppn_i, enable_translation_i};
    assign _mmu_ch_mxr_0 = mxr_i;
    assign _mmu_ch_lsu_req_0 = lsu_is_store_i;


    // assign _mmu_ch_pmp_cfg_0 = pmpcfg_i;
    // assign _mmu_ch_pmp_addr_0 = pmpaddr_i;
    assign _dcache_ch_data_res_valid = req_port_i.data_rvalid;
    assign _dcache_ch_gnt_0 = req_port_i.data_gnt;
    assign _dcache_ch_data_res_0 = {req_port_i.data_rid, req_port_i.data_rdata, req_port_i.data_ruser[0]};
    assign _flush_ch_req_valid = flush_i;
    assign _flush_ch_req_0 = 1'b0;

    assign shared_tlb_miss_o = _mmu_ch_miss_o_0;
    assign update_vaddr_o = _mmu_ch_update_vaddr_o_0;
    
    assign shared_tlb_update_o.content = pte_cva6_t'(_mmu_ch_tlb_res_0[0+:64]);
    assign shared_tlb_update_o.valid = _mmu_ch_tlb_res_valid;
    assign shared_tlb_update_o.asid = _mmu_ch_tlb_res_0[64+:16];
    assign shared_tlb_update_o.vpn = _mmu_ch_tlb_res_0[80+:27];
    assign shared_tlb_update_o.is_page = _mmu_ch_tlb_res_0[107+:2];
    assign shared_tlb_update_o.vmid = '0;
    assign shared_tlb_update_o.v_st_enbl = '0;

    assign ptw_active_o = _mmu_ch_status_0;
    assign walking_instr_o = _mmu_ch_walking_instr_o_0;

    assign bad_paddr_o = _mmu_ch_res_0[0+:56];
    assign ptw_access_exception_o = _mmu_ch_res_0[56] & _mmu_ch_res_valid;
    assign ptw_error_o = _mmu_ch_res_0[57] & _mmu_ch_res_valid;
    assign bad_gpaddr_o = _mmu_ch_res_0[58+:41];
    assign ptw_error_at_g_st_o = '0;
    assign ptw_err_at_g_int_st_o = '0;


    assign req_port_o = '{
        address_index : _dcache_ch_data_req_0[122+:12],
        address_tag : _dcache_ch_data_req_0[78+:44],
        data_wdata : _dcache_ch_data_req_0[14+:64],
        data_wuser : _dcache_ch_data_req_0[13],
        data_req : _dcache_ch_req_valid,
        data_we : '0,
        data_be : _dcache_ch_data_req_0[5+:8],
        data_size : _dcache_ch_data_req_0[3+:2],
        data_id : _dcache_ch_data_req_0[0+:3],
        kill_req : '0,
        tag_valid : _dcache_ch_data_req_valid
    };
      pmp #(
      .CVA6Cfg(CVA6Cfg)
  ) i_pmp_ptw (
      .addr_i       (pmp_addr),
      // PTW access are always checked as if in S-Mode...
      .priv_lvl_i   (riscv::PRIV_LVL_S),
      // ...and they are always loads
      .access_type_i(riscv::ACCESS_READ),
      // Configuration
      .conf_addr_i  (pmpaddr_i),
      .conf_i       (pmpcfg_i),
      .allow_o      (allow_access)
  );

    anvil_ptw anvil_spawn(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        ._mmu_ch_req_ack(_mmu_ch_req_ack),
        ._mmu_ch_req_valid(_mmu_ch_req_valid),
        ._mmu_ch_req_0(_mmu_ch_req_0),
        ._mmu_ch_csr_0(_mmu_ch_csr_0),
        ._mmu_ch_mxr_0(_mmu_ch_mxr_0),
        ._mmu_ch_lsu_req_0(_mmu_ch_lsu_req_0),
        ._mmu_ch_miss_o_0(_mmu_ch_miss_o_0),
        ._mmu_ch_tlb_res_valid(_mmu_ch_tlb_res_valid),
        ._mmu_ch_tlb_res_0(_mmu_ch_tlb_res_0),
        ._mmu_ch_update_vaddr_o_0(_mmu_ch_update_vaddr_o_0),
        ._mmu_ch_res_valid(_mmu_ch_res_valid),
        ._mmu_ch_res_0(_mmu_ch_res_0),
        ._mmu_ch_status_0(_mmu_ch_status_0),
        ._mmu_ch_walking_instr_o_0(_mmu_ch_walking_instr_o_0),
        // ._mmu_ch_pmp_cfg_0(_mmu_ch_pmp_cfg_0),
        // ._mmu_ch_pmp_addr_0(_mmu_ch_pmp_addr_0),
        ._dcache_ch_gnt_0(_dcache_ch_gnt_0),
        ._dcache_ch_req_valid(_dcache_ch_req_valid),
        ._dcache_ch_req_0(_dcache_ch_req_0),
        ._dcache_ch_data_req_valid(_dcache_ch_data_req_valid),
        ._dcache_ch_data_req_0(_dcache_ch_data_req_0),
        ._dcache_ch_data_res_ack(_dcache_ch_data_res_ack),
        ._dcache_ch_data_res_valid(_dcache_ch_data_res_valid),
        ._dcache_ch_data_res_0(_dcache_ch_data_res_0),
        ._flush_ch_req_valid(_flush_ch_req_valid),
        ._flush_ch_req_0(_flush_ch_req_0),
        ._pmp_ep_ri_addr_i_0(pmp_addr),
        ._pmp_ep_ri_res_0(allow_access)
    );

endmodule