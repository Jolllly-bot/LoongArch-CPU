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
  input  [31:0] wb_pc
);

//CRMD
  wire [31:0] csr_crmd_rvalue;
  reg  [ 1:0] csr_crmd_plv;
  reg         csr_crmd_ie;
  reg         csr_crmd_da;
  
  always @(posedge clk) begin
    if (reset)begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
        csr_crmd_da  <= 1'b1;
    end
    else if (wb_ex)begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if (eret_flush)begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
    end
    else if (csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV] 
                     | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE] 
                     | ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
    end
  end

  assign csr_crmd_rvalue = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

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

 /* wire [31:0] csr_ecfg_rvalue;
  reg [12:0] csr_ecfg_lie;
  
  always @(posedge clk) begin
    if (reset)
      csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG)
      csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE] 
                    | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
  end
   
  assign csr_ecfg_rvalue = {19'b0,csr_ecfg_lie}; */


//ESTAT
  wire [31:0] csr_estat_rvalue;
  reg  [12:0] csr_estat_is;
  reg  [ 5:0] csr_estat_ecode;
  reg  [ 8:0] csr_estat_esubcode;

  always @(posedge clk) begin
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] 
                          | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
    
    //csr_estat_is[9:2] <= hw_int_in[7:0];
    csr_estat_is[9:2] <= 8'b0;

    csr_estat_is[10] <= 1'b0;
    
    if (timer_cnt[31:0]==32'b0)
      csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
      csr_estat_is[11] <= 1'b0;

   // csr_estat_is[12] <= ipi_int_in;
     csr_estat_is[12] <= 1'b0;
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
  reg [31:0] csr_era_pc;

  always @(posedge clk) begin
    if (wb_ex)
      csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
      csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] 
                 | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
  end

  assign csr_era_rvalue = csr_era_pc;

/*  wire [31:0] csr_badr_rvalue;
  wire wb_ex_addr_err;
  reg [31:0] csr_badv_vaddr;

  assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
  
  always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err)
      csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
  end
  
  assign csr_badr_rvalue = csr_badv_vaddr; */

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
  wire [31:0] tcfg_next_value;
  wire [31:0] csr_tval;
  reg [31:0] timer_cnt;

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

//TVAL
  assign csr_tval = timer_cnt[31:0];


  assign csr_rvalue = {32{csr_num==`CSR_CRMD}}   & csr_crmd_rvalue
                    | {32{csr_num==`CSR_PRMD}}   & csr_prmd_rvalue
                    | {32{csr_num==`CSR_ESTAT}}  & csr_estat_rvalue
                    | {32{csr_num==`CSR_ERA}}    & csr_era_rvalue
                    | {32{csr_num==`CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_num==`CSR_SAVE0}}  & csr_save0_data
                    | {32{csr_num==`CSR_SAVE1}}  & csr_save1_data
                    | {32{csr_num==`CSR_SAVE2}}  & csr_save2_data
                    | {32{csr_num==`CSR_SAVE3}}  & csr_save3_data;


endmodule