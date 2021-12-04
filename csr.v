`include "mycpu.h"

module csr(
  input         clk,
  input         reset,
  input         csr_re,
  input  [13:0] csr_num,
  output [31:0] csr_rvalue,
  input         csr_we,
  input  [31:0] csr_wmask,
  input  [31:0] csr_wvalue,
  input         wb_ex,
  input  [ 5:0] wb_ecode,
  input  [ 8:0] wb_esubcode,
  input         eret_flush,
  input  [31:0] wb_pc,
  output        has_int,
  input  [ 7:0] hw_int_in,
  input         ipi_int_in,
  input  [31:0] coreid_in,
  input  [31:0] wb_vaddr,
  input  [ 4:0] tlb_op, // Search read write fill invalid
  input         tlb_hit,
  input         tlb_re,
  input  [31:0] tlb_idx_wvalue,
  input  [31:0] tlb_ehi_wvalue,
  input  [31:0] tlb_elo0_wvalue,
  input  [31:0] tlb_elo1_wvalue,
  input  [31:0] tlb_asid_wvalue,

  output [31:0] tlb_idx_rvalue,
  output [31:0] tlb_ehi_rvalue,
  output [31:0] tlb_elo0_rvalue,
  output [31:0] tlb_elo1_rvalue,
  output [31:0] tlb_asid_rvalue,
  output [31:0] tlb_dmw0_rvalue,
  output [31:0] tlb_dmw1_rvalue,
  output [31:0] csr_estat_rvalue,

  output [31:0] csr_crmd_rvalue
);

//CRMD
  reg  [ 1:0] csr_crmd_plv;
  reg         csr_crmd_ie;
  reg         csr_crmd_da;
  reg         csr_crmd_pg;
  
  always @(posedge clk) begin
    if (reset)begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
        csr_crmd_da  <= 1'b1;
        csr_crmd_pg  <= 1'b0;
    end
    else if (wb_ex)begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if (eret_flush)begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
        if(csr_estat_ecode == 6'h3f)begin
          csr_crmd_da  <= 1'b0;
          csr_crmd_pg  <= 1'b1;
        end
    end
    else if (csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] 
                     | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE] 
                     | ~csr_wmask[`CSR_CRMD_PIE] & csr_crmd_ie;
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA] 
                     | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG] 
                     | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
    end 
    else if (wb_ecode == `ECODE_TLBR) begin
        csr_crmd_da  <= 1'b1;
        csr_crmd_pg  <= 1'b0;
    end
  end

  assign csr_crmd_rvalue = {27'b0, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

//PRMD
  wire [31:0] csr_prmd_rvalue;
  reg         csr_prmd_pie;
  reg  [ 1:0] csr_prmd_pplv;

  always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV] 
                      | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE] 
                      | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
  end

  assign csr_prmd_rvalue = {29'b0,csr_prmd_pie,csr_prmd_pplv};
//ECFG
  wire [31:0] csr_ecfg_rvalue;
  reg [12:0] csr_ecfg_lie;
  
  always @(posedge clk) begin
    if (reset)
      csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
      csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE] 
                    | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
  end
   
  assign csr_ecfg_rvalue = {19'b0,csr_ecfg_lie}; 


//ESTAT
  //wire [31:0] csr_estat_rvalue;
  reg  [12:0] csr_estat_is;
  reg  [ 5:0] csr_estat_ecode;
  reg  [ 8:0] csr_estat_esubcode;

  always @(posedge clk) begin
    if (reset)begin
      csr_estat_is[1:0] <= 2'b0;
      csr_estat_is[11] <= 1'b0;
    end    
    else if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] 
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    
    csr_estat_is[9:2] <= hw_int_in[7:0];
   // csr_estat_is[9:2] <= 8'b0;

    csr_estat_is[10] <= 1'b0;
    
    if (timer_cnt[31:0]==32'b0)
      csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
      csr_estat_is[11] <= 1'b0;

    csr_estat_is[12] <= ipi_int_in;
    // csr_estat_is[12] <= 1'b0;
  end
  
  always @(posedge clk) begin
    if (wb_ex) begin
      csr_estat_ecode <= wb_ecode;
      csr_estat_esubcode <= wb_esubcode;
    end
  end

  assign csr_estat_rvalue = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};

//ERA
  wire [31:0] csr_era_rvalue;
  reg  [31:0] csr_era_pc;

  always @(posedge clk) begin
    if (wb_ex)
      csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
      csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] 
                 | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
  end

  assign csr_era_rvalue = csr_era_pc;

//BADV
  wire [31:0] csr_badv_rvalue;
  wire wb_ex_addr_err;
  reg [31:0] csr_badv_vaddr;

  assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE || wb_ecode==`ECODE_TLBR || wb_ecode==`ECODE_PIF || wb_ecode==`ECODE_PIL || wb_ecode==`ECODE_PIS || wb_ecode==`ECODE_PPI || wb_ecode==`ECODE_PME ;
  
  always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err)
      csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    else if (csr_we && csr_num==`CSR_BADV)begin
      csr_badv_vaddr <= csr_wmask & csr_wvalue 
                     | ~csr_wmask & csr_badv_vaddr;      
    end
  end
  
  assign csr_badv_rvalue = csr_badv_vaddr; 

//EENTRY
  wire [31:0] csr_eentry_rvalue;
  reg  [25:0] csr_eentry_va;
  
  always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] 
                       | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
  end

  assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};

//SAVE
  reg [31:0] csr_save0_data;
  reg [31:0] csr_save1_data;
  reg [31:0] csr_save2_data;
  reg [31:0] csr_save3_data;

  always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
      csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] 
                      | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
      csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] 
                      | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
      csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] 
                      | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
      csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] 
                      | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
  end


//TCFG
  reg csr_tcfg_en;
  reg csr_tcfg_periodic;
  reg [29:0] csr_tcfg_initval;
  wire [31:0] csr_tcfg_rvalue;
  reg  [31:0] timer_cnt;
  wire [31:0] tcfg_next_value;


always @(posedge clk) begin
  if (reset)
    csr_tcfg_en <= 1'b0;
  else if (csr_we && csr_num==`CSR_TCFG)
    csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN] 
                | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
  
  if (csr_we && csr_num==`CSR_TCFG) begin
    csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIODIC]&csr_wvalue[`CSR_TCFG_PERIODIC] 
                      | ~csr_wmask[`CSR_TCFG_PERIODIC]&csr_tcfg_periodic;
    csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL]&csr_wvalue[`CSR_TCFG_INITVAL] 
                      | ~csr_wmask[`CSR_TCFG_INITVAL]&csr_tcfg_initval;
  end

end

  always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
  end

  assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
                        | ~csr_wmask[31:0]&{csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

  assign csr_tcfg_rvalue = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};

//TID
reg  [31:0] csr_tid_tid       ;
wire [31:0] csr_tid_rvalue    ;

always @(posedge clk) begin
  if (reset)
    csr_tid_tid <= coreid_in;
  else if (csr_we && csr_num==`CSR_TID)
    csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID] 
                | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
end

assign csr_tid_rvalue = csr_tid_tid;  

//TVAL
wire [31:0] csr_tval_rvalue;
wire [31:0] csr_tval_timeval  ;

assign csr_tval_timeval = timer_cnt[31:0];

assign csr_tval_rvalue = csr_tval_timeval;

//TICLR
wire        csr_ticlr_clr     ;
wire [31:0] csr_ticlr_rvalue  ;

assign csr_ticlr_clr = 1'b0;
assign csr_ticlr_rvalue  =  {31'b0, csr_ticlr_clr};

//DMW0 DMW1
reg          tlb_dmw0_plv0;
reg          tlb_dmw0_plv3;
reg  [5 : 4] tlb_dmw0_mat;
reg  [27:25] tlb_dmw0_pseg;
reg  [31:29] tlb_dmw0_vseg; 
reg          tlb_dmw1_plv0;
reg          tlb_dmw1_plv3;
reg  [5 : 4] tlb_dmw1_mat;
reg  [27:25] tlb_dmw1_pseg;
reg  [31:29] tlb_dmw1_vseg;
always @(posedge clk ) begin
    if(reset) begin
        tlb_dmw0_plv0 <= 1'b0;
        tlb_dmw0_plv3 <= 1'b0;
        tlb_dmw0_mat  <= 2'b0;
        tlb_dmw0_pseg <= 3'b0;
        tlb_dmw0_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW0)begin
        tlb_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & tlb_dmw0_plv0; 
        tlb_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & tlb_dmw0_plv3; 
        tlb_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT]  & tlb_dmw0_mat; 
        tlb_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & tlb_dmw0_pseg;
        tlb_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & tlb_dmw0_vseg;   
    end
end

assign tlb_dmw0_rvalue      = {tlb_dmw0_vseg, 1'b0, tlb_dmw0_pseg, 19'b0, tlb_dmw0_mat, tlb_dmw0_plv3, 2'b0, tlb_dmw0_plv0};

always @(posedge clk ) begin
    if(reset) begin
        tlb_dmw1_plv0 <= 1'b0;
        tlb_dmw1_plv3 <= 1'b0;
        tlb_dmw1_mat  <= 2'b0;
        tlb_dmw1_pseg <= 3'b0;
        tlb_dmw1_vseg <= 3'b0;
    end
    else if(csr_we && csr_num == `CSR_DMW1)begin
        tlb_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                       | ~csr_wmask[`CSR_DMW_PLV0] & tlb_dmw1_plv0; 
        tlb_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                       | ~csr_wmask[`CSR_DMW_PLV3] & tlb_dmw1_plv3; 
        tlb_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]
                       | ~csr_wmask[`CSR_DMW_MAT]  & tlb_dmw1_mat; 
        tlb_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                       | ~csr_wmask[`CSR_DMW_PSEG] & tlb_dmw1_pseg;
        tlb_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                       | ~csr_wmask[`CSR_DMW_VSEG] & tlb_dmw1_vseg;   
    end
end

assign tlb_dmw1_rvalue      = {tlb_dmw1_vseg, 1'b0, tlb_dmw1_pseg, 19'b0, tlb_dmw1_mat, tlb_dmw1_plv3, 2'b0, tlb_dmw1_plv0};


//ASID
reg  [9:0] tlb_asid_asid;

always @(posedge clk) begin
  if(reset)begin
    tlb_asid_asid <= 10'b0;
  end
  else if (tlb_op == `TLB_RD && tlb_re) begin
    tlb_asid_asid <= tlb_asid_wvalue[`CSR_ASID_ASID];
  end
  else if(csr_we && csr_num == `CSR_ASID)begin
    tlb_asid_asid  <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                   | ~csr_wmask[`CSR_ASID_ASID] & tlb_asid_asid; 
  end
end

assign tlb_asid_rvalue = {8'b0, 8'd10, 6'h0, tlb_asid_asid};

//TLBIDX
reg  [ 3:0] tlb_idx_index;
reg  [ 5:0] tlb_idx_ps;
reg         tlb_idx_ne;

always @(posedge clk ) begin
    if(reset) begin
        tlb_idx_index <= 4'h0;
    end
    else if(tlb_op == `TLB_SRCH && tlb_hit) begin
        tlb_idx_index <= tlb_idx_wvalue[`CSR_TLBIDX_INDEX];
    end 
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        tlb_idx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX]
                      | ~csr_wmask[`CSR_TLBIDX_INDEX] & tlb_idx_index;
    end
end

always @(posedge clk ) begin
    if(reset) begin
        tlb_idx_ps <= 6'h0;
    end
    else if(tlb_op == `TLB_RD && tlb_re) begin
        tlb_idx_ps <= tlb_idx_wvalue[`CSR_TLBIDX_PS];
    end
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        tlb_idx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                  | ~csr_wmask[`CSR_TLBIDX_PS] & tlb_idx_ps;
    end
end

always @(posedge clk ) begin
    if(reset) begin
        tlb_idx_ne <= 1'b0;
    end
    else if(tlb_op == `TLB_SRCH) begin
      if(tlb_hit) begin
        tlb_idx_ne <= 1'b0;
      end
      else begin
        tlb_idx_ne <= 1'b1;
      end
    end
    else if(tlb_op == `TLB_RD) begin
      tlb_idx_ne <= tlb_idx_wvalue[`CSR_TLBIDX_NE];
    end
    else if(csr_we && csr_num == `CSR_TLBIDX) begin
        tlb_idx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                  |  ~csr_wmask[`CSR_TLBIDX_NE] & tlb_idx_ne; 
    end
end

assign tlb_idx_rvalue = {tlb_idx_ne, 1'b0, tlb_idx_ps, 20'b0, tlb_idx_index};

//TLBEHI
reg [18:0] tlb_ehi_vppn;
always @(posedge clk ) begin
    if(reset) begin
        tlb_ehi_vppn <= 19'b0;
    end
    else if(wb_ecode == `ECODE_TLBR || wb_ecode == `ECODE_PIL || wb_ecode == `ECODE_PIS ||
            wb_ecode == `ECODE_PIF || wb_ecode == `ECODE_PPI || wb_ecode == `ECODE_PME)
    begin
        tlb_ehi_vppn <= wb_vaddr[`CSR_TLBEHI_VPPN];
    end
    else if(tlb_op == `TLB_RD && tlb_re) begin
        tlb_ehi_vppn <= tlb_ehi_wvalue[`CSR_TLBEHI_VPPN];
    end
    else if(csr_we && csr_num == `CSR_TLBEHI) begin
        tlb_ehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                    | ~csr_wmask[`CSR_TLBEHI_VPPN] & tlb_ehi_vppn;   
    end
end

assign tlb_ehi_rvalue = {tlb_ehi_vppn,13'h0};

//TLBELO
reg          tlb_elo0_v;
reg          tlb_elo0_d;
reg  [1:0] tlb_elo0_plv;
reg  [1:0] tlb_elo0_mat;
reg          tlb_elo0_g;
reg  [23:0] tlb_elo0_ppn;
reg          tlb_elo1_v;
reg          tlb_elo1_d;
reg  [1:0] tlb_elo1_plv;
reg  [1:0] tlb_elo1_mat;
reg          tlb_elo1_g;
reg  [23:0] tlb_elo1_ppn;

always @(posedge clk ) begin
    if(reset) begin
        tlb_elo0_v   <= 1'b0;
        tlb_elo0_d   <= 1'b0;
        tlb_elo0_plv <= 2'b0;
        tlb_elo0_mat <= 2'b0;
        tlb_elo0_g   <= 1'b0;
        tlb_elo0_ppn <= 24'b0;
    end
    else if (tlb_op == `TLB_RD && tlb_re) begin
        tlb_elo0_v   <= tlb_elo0_wvalue[`CSR_TLBELO_V];
        tlb_elo0_d   <= tlb_elo0_wvalue[`CSR_TLBELO_D];
        tlb_elo0_plv <= tlb_elo0_wvalue[`CSR_TLBELO_PLV];
        tlb_elo0_mat <= tlb_elo0_wvalue[`CSR_TLBELO_MAT];
        tlb_elo0_ppn <= tlb_elo0_wvalue[`CSR_TLBELO_PPN];
        tlb_elo0_g   <= tlb_elo0_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO0) begin
        tlb_elo0_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & tlb_elo0_v; 
        tlb_elo0_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & tlb_elo0_d;
        tlb_elo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & tlb_elo0_plv;
        tlb_elo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & tlb_elo0_mat;
        tlb_elo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & tlb_elo0_ppn;
        tlb_elo0_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & tlb_elo0_g;    
    end
end

assign tlb_elo0_rvalue   = {tlb_elo0_ppn, 1'b0, tlb_elo0_g, tlb_elo0_mat, tlb_elo0_plv, tlb_elo0_d, tlb_elo0_v}; 

always @(posedge clk ) begin
    if(reset) begin
        tlb_elo1_v   <= 1'b0;
        tlb_elo1_d   <= 1'b0;
        tlb_elo1_plv <= 2'b0;
        tlb_elo1_mat <= 2'b0;
        tlb_elo1_g   <= 1'b0;
        tlb_elo1_ppn <= 24'b0;
    end
    else if (tlb_op == `TLB_RD && tlb_re) begin
        tlb_elo1_v   <= tlb_elo1_wvalue[`CSR_TLBELO_V];
        tlb_elo1_d   <= tlb_elo1_wvalue[`CSR_TLBELO_D];
        tlb_elo1_plv <= tlb_elo1_wvalue[`CSR_TLBELO_PLV];
        tlb_elo1_mat <= tlb_elo1_wvalue[`CSR_TLBELO_MAT];
        tlb_elo1_ppn <= tlb_elo1_wvalue[`CSR_TLBELO_PPN];
        tlb_elo1_g   <= tlb_elo1_wvalue[`CSR_TLBELO_G];  
    end
    else if(csr_we && csr_num == `CSR_TLBELO1) begin
        tlb_elo1_v   <= csr_wmask[`CSR_TLBELO_V] & csr_wvalue[`CSR_TLBELO_V]
                        | ~csr_wmask[`CSR_TLBELO_V] & tlb_elo1_v; 
        tlb_elo1_d   <= csr_wmask[`CSR_TLBELO_D] & csr_wvalue[`CSR_TLBELO_D]
                        | ~csr_wmask[`CSR_TLBELO_D] & tlb_elo1_d;
        tlb_elo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV]
                        | ~csr_wmask[`CSR_TLBELO_PLV] & tlb_elo1_plv;
        tlb_elo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT]
                        | ~csr_wmask[`CSR_TLBELO_MAT] & tlb_elo1_mat;
        tlb_elo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN]
                        | ~csr_wmask[`CSR_TLBELO_PPN] & tlb_elo1_ppn;
        tlb_elo1_g   <= csr_wmask[`CSR_TLBELO_G] & csr_wvalue[`CSR_TLBELO_G]
                        | ~csr_wmask[`CSR_TLBELO_G] & tlb_elo1_g;    
    end
 
end
assign tlb_elo1_rvalue   = {tlb_elo1_ppn, 1'b0, tlb_elo1_g, tlb_elo1_mat, tlb_elo1_plv, tlb_elo1_d, tlb_elo1_v}; 


//TLBRENTRY
reg   [25:0] tlb_rentry_pa;
wire  [31:0] tlb_rentry_rvalue;
always @(posedge clk ) begin
    if(reset)begin
        tlb_rentry_pa <= 26'b0;
    end 
    else if(csr_we && csr_num == `CSR_TLBRENTRY) begin
        tlb_rentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                         | ~csr_wmask[`CSR_TLBRENTRY_PA] & tlb_rentry_pa; 
    end
end
assign tlb_rentry_rvalue = {tlb_rentry_pa, 6'b0}; 


assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);

assign csr_rvalue =   {32{csr_num ==`CSR_CRMD}}      & csr_crmd_rvalue
                    | {32{csr_num ==`CSR_PRMD}}      & csr_prmd_rvalue
                    | {32{csr_num ==`CSR_ESTAT}}     & csr_estat_rvalue
                    | {32{csr_num ==`CSR_ERA}}       & csr_era_rvalue
                    | {32{csr_num ==`CSR_EENTRY}}    & csr_eentry_rvalue
                    | {32{csr_num ==`CSR_SAVE0}}     & csr_save0_data
                    | {32{csr_num ==`CSR_SAVE1}}     & csr_save1_data
                    | {32{csr_num ==`CSR_SAVE2}}     & csr_save2_data
                    | {32{csr_num ==`CSR_SAVE3}}     & csr_save3_data
                    | {32{csr_num ==`CSR_TID}}       & csr_tid_rvalue
                    | {32{csr_num ==`CSR_TCFG}}      & csr_tcfg_rvalue
                    | {32{csr_num ==`CSR_TVAL}}      & csr_tval_rvalue
                    | {32{csr_num ==`CSR_TICLR}}     & csr_ticlr_rvalue
                    | {32{csr_num ==`CSR_BADV}}      & csr_badv_rvalue
                    | {32{csr_num ==`CSR_ECFG}}      & csr_ecfg_rvalue
                    | {32{csr_num == `CSR_TLBIDX}}   & tlb_idx_rvalue
                    | {32{csr_num == `CSR_TLBEHI}}   & tlb_ehi_rvalue
                    | {32{csr_num == `CSR_TLBELO0}}  & tlb_elo0_rvalue
                    | {32{csr_num == `CSR_TLBELO1}}  & tlb_elo1_rvalue
                    | {32{csr_num == `CSR_TLBRENTRY}} & tlb_rentry_rvalue
                    | {32{csr_num == `CSR_ASID}}     & tlb_asid_rvalue
                    | {32{csr_num == `CSR_DMW0}}     & tlb_dmw0_rvalue
                    | {32{csr_num == `CSR_DMW1}}     & tlb_dmw1_rvalue;

endmodule