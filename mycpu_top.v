module mycpu_top(
    input         aclk,
    input         aresetn,

    output  [ 3:0] arid,
    output  [31:0] araddr,
    output  [ 7:0] arlen,
    output  [ 2:0] arsize,
    output  [ 1:0] arburst,
    output  [ 1:0] arlock,
    output  [ 3:0] arcache,
    output  [ 2:0] arprot,
    output         arvalid,
    input          arready,

    input   [ 3:0] rid,
    input   [31:0] rdata,
    input   [1:0]  rresp,
    input          rlast,
    input          rvalid,
    output         rready,

    output  [ 3:0] awid,
    output  [31:0] awaddr,
    output  [ 7:0] awlen,
    output  [ 2:0] awsize,
    output  [ 1:0] awburst,
    output  [ 1:0] awlock,
    output  [ 3:0] awcache,
    output  [ 2:0] awprot,
    output         awvalid,
    input          awready,

    output  [ 3:0] wid,
    output  [31:0] wdata,
    output  [ 3:0] wstrb,
    output         wlast,
    output         wvalid,
    input          wready,

    input   [ 3:0] bid,
    input   [ 1:0] bresp,
    input          bvalid,
    output         bready,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn; 

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`ES_FWD_BUS_WD   -1:0] es_fwd_bus;
wire [`MS_FWD_BUS_WD   -1:0] ms_fwd_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [                 31:0] ws_to_fs_bus;
wire                         ws_flush_pipe;
wire                         ms_ex;
wire                         ms_tlb_blk;

wire        inst_sram_req;  
wire        inst_sram_wr;   
wire [ 1:0] inst_sram_size; 
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

wire        data_sram_req;  
wire        data_sram_wr;   
wire [ 1:0] data_sram_size; 
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

// TLB
// search port 0 (for fetch)
wire  [18:0] s0_vppn;
wire         s0_va_bit12;
wire  [ 9:0] s0_asid;
wire         s0_found;
wire  [ 3:0] s0_index;
wire  [19:0] s0_ppn;
wire  [ 5:0] s0_ps;
wire  [ 1:0] s0_plv;
wire  [ 1:0] s0_mat;
wire         s0_d;
wire         s0_v;
// search port 1 (for load/store)
wire  [18:0] s1_vppn;
wire         s1_va_bit12;
wire  [ 9:0] s1_asid;
wire         s1_found;
wire  [ 3:0] s1_index;
wire  [19:0] s1_ppn;
wire  [ 5:0] s1_ps;
wire  [ 1:0] s1_plv;
wire  [ 1:0] s1_mat;
wire         s1_d;
wire         s1_v;
// invtlb opcode
wire         invtlb_valid;
wire  [ 4:0] invtlb_op;
 // write port
wire         we; //w(rite) e(nable)
wire  [ 3:0] w_index;
wire         w_e;
wire  [ 5:0] w_ps;
wire  [18:0] w_vppn;
wire  [ 9:0] w_asid;
wire         w_g;
wire  [19:0] w_ppn0;
wire  [ 1:0] w_plv0;
wire  [ 1:0] w_mat0;
wire         w_d0;
wire         w_v0;
wire  [19:0] w_ppn1;
wire  [ 1:0] w_plv1;
wire  [ 1:0] w_mat1;
wire         w_d1;
wire         w_v1;
// read port
wire  [ 3:0] r_index;
wire         r_e;
wire  [18:0] r_vppn;
wire  [ 5:0] r_ps;
wire  [ 9:0] r_asid;
wire         r_g;
wire  [19:0] r_ppn0;
wire  [ 1:0] r_plv0;
wire  [ 1:0] r_mat0;
wire         r_d0;
wire         r_v0;
wire  [19:0] r_ppn1;     
wire  [ 1:0] r_plv1;
wire  [ 1:0] r_mat1;
wire         r_d1;
wire         r_v1;
wire  [31:0] tlb_asid_rvalue;
wire  [31:0] tlb_ehi_rvalue;
wire  [31:0] csr_crmd_rvalue;
wire  [31:0] csr_dmw0_rvalue;
wire  [31:0] csr_dmw1_rvalue;

axi_bridge u_axi_bridge(
    .aclk           (aclk    ),
    .aresetn        (aresetn ),

    .arid           (arid    ),
    .araddr         (araddr  ),
    .arlen          (arlen   ),
    .arsize         (arsize  ),
    .arburst        (arburst ),
    .arlock         (arlock  ),
    .arcache        (arcache ),
    .arprot         (arprot  ),
    .arvalid        (arvalid ),
    .arready        (arready ),

    .rid            (rid     ),
    .rdata          (rdata   ),
    .rvalid         (rvalid  ),
    .rready         (rready  ),

    .awid           (awid    ),
    .awaddr         (awaddr  ),
    .awlen          (awlen   ),
    .awsize         (awsize  ),
    .awburst        (awburst ),
    .awlock         (awlock  ),
    .awcache        (awcache ),
    .awprot         (awprot  ),
    .awvalid        (awvalid ),
    .awready        (awready ),

    .wid            (wid     ),
    .wdata          (wdata   ),
    .wstrb          (wstrb   ),
    .wlast          (wlast   ),
    .wvalid         (wvalid  ),
    .wready         (wready  ),

    .bvalid         (bvalid  ),
    .bready         (bready  ),

    .inst_sram_req      (inst_sram_req    ),
    .inst_sram_wr       (inst_sram_wr     ),
    .inst_sram_size     (inst_sram_size   ),
    .inst_sram_addr     (inst_sram_addr   ),
    .inst_sram_wdata    (inst_sram_wdata  ),
    .inst_sram_rdata    (inst_sram_rdata  ),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),

    .data_sram_req      (data_sram_req    ),
    .data_sram_wr       (data_sram_wr     ),
    .data_sram_size     (data_sram_size   ),
    .data_sram_addr     (data_sram_addr   ),
    .data_sram_wdata    (data_sram_wdata  ),
    .data_sram_wstrb    (data_sram_wstrb  ),
    .data_sram_rdata    (data_sram_rdata  ),
    .data_sram_addr_ok  (data_sram_addr_ok),
    .data_sram_data_ok  (data_sram_data_ok)
);

// IF stage
if_stage if_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req     (inst_sram_req    ),
    .inst_sram_wr      (inst_sram_wr     ),
    .inst_sram_size    (inst_sram_size   ),
    .inst_sram_wstrb   (inst_sram_wstrb  ),
    .inst_sram_addr    (inst_sram_addr   ),
    .inst_sram_wdata   (inst_sram_wdata  ),
    .inst_sram_addr_ok (inst_sram_addr_ok),
    .inst_sram_data_ok (inst_sram_data_ok),
    .inst_sram_rdata   (inst_sram_rdata  ),
    .ws_to_fs_bus      (ws_to_fs_bus     ),
    .fs_flush_pipe     (ws_flush_pipe    ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    .csr_crmd_rvalue(csr_crmd_rvalue),
    .tlb_asid_rvalue(tlb_asid_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue)
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //from es & ms: forward
    .es_fwd_bus     (es_fwd_bus     ),
    .ms_fwd_bus     (ms_fwd_bus     ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .ds_flush_pipe  (ws_flush_pipe)
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //forward
    .es_fwd_bus     (es_fwd_bus     ),
    // data sram interface
    .data_sram_req     (data_sram_req    ),
    .data_sram_wr      (data_sram_wr     ),
    .data_sram_size    (data_sram_size   ),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr    (data_sram_addr   ),
    .data_sram_wdata   (data_sram_wdata  ),
    .data_sram_addr_ok (data_sram_addr_ok),
    .data_sram_data_ok (data_sram_data_ok),
    .data_sram_rdata   (data_sram_rdata  ),
    .es_flush_pipe     (ws_flush_pipe    ),
    .ms_ex             (ms_ex            ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    .tlb_ehi_rvalue(tlb_ehi_rvalue ),
    .tlb_asid_rvalue(tlb_asid_rvalue),
    .ms_tlb_blk     (ms_tlb_blk     ),
    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue)
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //forward
    .ms_fwd_bus     (ms_fwd_bus     ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .ms_flush_pipe  (ws_flush_pipe  ),
    .ms_to_es_ex    (ms_ex          ),
    .ms_tlb_blk     (ms_tlb_blk     )
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_to_fs_bus     (ws_to_fs_bus     ),
    .ws_flush_pipe    (ws_flush_pipe    ),
    // write port
    .we            (we             ), //w(rite) e(nable)
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           ),
    .ws_ehi_rvalue(tlb_ehi_rvalue  ),
    .ws_asid_rvalue(tlb_asid_rvalue),
    .ws_crmd_rvalue(csr_crmd_rvalue),
    .ws_dmw0_rvalue(csr_dmw0_rvalue),
    .ws_dmw1_rvalue(csr_dmw1_rvalue)
);

// TLB
tlb tlb(
    .clk           (aclk           ),
    .reset         (reset          ),
    // search port 0 (for fetch)
    .s0_vppn       (s0_vppn        ),
    .s0_va_bit12   (s0_va_bit12    ),
    .s0_asid       (s0_asid        ),
    .s0_found      (s0_found       ),
    .s0_index      (s0_index       ),
    .s0_ppn        (s0_ppn         ),  
    .s0_ps         (s0_ps          ),
    .s0_plv        (s0_plv         ),
    .s0_mat        (s0_mat         ),
    .s0_d          (s0_d           ),
    .s0_v          (s0_v           ),
    // search port 1 (for load/store)
    .s1_vppn       (s1_vppn        ),
    .s1_va_bit12   (s1_va_bit12    ),
    .s1_asid       (s1_asid        ),
    .s1_found      (s1_found       ),
    .s1_index      (s1_index       ),
    .s1_ppn        (s1_ppn         ),
    .s1_ps         (s1_ps          ),
    .s1_plv        (s1_plv         ),
    .s1_mat        (s1_mat         ),
    .s1_d          (s1_d           ),
    .s1_v          (s1_v           ),
    // invtlb opcode
    .invtlb_valid  (invtlb_valid   ),
    .invtlb_op     (invtlb_op      ),
    // write port
    .we            (we             ), //w(rite) e(nable)
    .w_index       (w_index        ),
    .w_e           (w_e            ),
    .w_ps          (w_ps           ),
    .w_vppn        (w_vppn         ),
    .w_asid        (w_asid         ),
    .w_g           (w_g            ),
    .w_ppn0        (w_ppn0         ),
    .w_plv0        (w_plv0         ),
    .w_mat0        (w_mat0         ),
    .w_d0          (w_d0           ),
    .w_v0          (w_v0           ),
    .w_ppn1        (w_ppn1         ),
    .w_plv1        (w_plv1         ),
    .w_mat1        (w_mat1         ),
    .w_d1          (w_d1           ),
    .w_v1          (w_v1           ),
    // read port
    .r_index       (r_index        ),
    .r_e           (r_e            ),
    .r_vppn        (r_vppn         ),
    .r_ps          (r_ps           ),
    .r_asid        (r_asid         ),
    .r_g           (r_g            ),
    .r_ppn0        (r_ppn0         ),
    .r_plv0        (r_plv0         ),
    .r_mat0        (r_mat0         ),
    .r_d0          (r_d0           ),
    .r_v0          (r_v0           ),
    .r_ppn1        (r_ppn1         ),     
    .r_plv1        (r_plv1         ),
    .r_mat1        (r_mat1         ),
    .r_d1          (r_d1           ),
    .r_v1          (r_v1           )
);

endmodule
