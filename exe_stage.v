`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //forward
    output [`ES_FWD_BUS_WD   -1:0] es_fwd_bus    ,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [1 :0] data_sram_size,
    output [3 :0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input [31:0]  data_sram_rdata,
    
    input         es_flush_pipe,
    input         ms_ex,
    input         ms_tlb_blk,

    // search port 1 (for load/store)
    output  [18:0] s1_vppn,
    output         s1_va_bit12,
    output  [ 9:0] s1_asid,
    input          s1_found,
    input   [ 3:0] s1_index,
    input   [19:0] s1_ppn,
    input   [ 5:0] s1_ps,
    input   [ 1:0] s1_plv,
    input   [ 1:0] s1_mat,
    input          s1_d,
    input          s1_v,
    // invtlb opcode
    output         invtlb_valid,
    output  [ 4:0] invtlb_op,
    input   [31:0] tlb_asid_rvalue,
    input   [31:0] tlb_ehi_rvalue,
    input   [31:0] csr_crmd_rvalue,
    input   [31:0] csr_dmw0_rvalue,
    input   [31:0] csr_dmw1_rvalue
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [11:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;

wire        es_res_from_mem;
wire [ 4:0] es_load_op     ;
wire [ 2:0] es_st_op       ;
wire [31:0] es_st_data     ;
wire [ 3:0] es_st_strb     ;
wire [31:0] es_vaddr       ;
wire [ 1:0] es_vaddr_type  ;

wire        es_fwd_valid   ;
wire        es_blk_valid   ;
wire [31:0] es_fwd_result  ;
wire        es_mem_req     ;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result     ;
reg  [ 3:0] div_cycle     ;
reg  [ 3:0] divu_cycle    ;

wire        es_mul_signed  ;
wire        es_mul_unsigned;
wire        es_mul_high    ;
wire        es_div_signed  ;
wire        es_div_unsigned;
wire        es_div_mod     ;

wire        es_ex;
wire        ds_to_es_ex;
wire [13:0] ds_csr_num;
wire [13:0] es_csr_num;
wire        es_csr_we;
wire        es_csr_re;
wire [31:0] es_csr_wmask;
wire        es_ertn;
wire        es_syscall;
wire [31:0] es_csr_wvalue;
wire [ 8:0] es_csr_esubcode;
wire [ 8:0] ds_to_es_csr_esubcode;
wire [ 5:0] ds_csr_ecode;
wire [ 5:0] es_csr_ecode;
wire        es_st_ex;
wire        es_ale_h;
wire        es_ale_w;
wire [ 1:0] es_cnt_op;
wire [ 4:0] es_tlb_op;
wire        tlb_blk;
wire        ds_to_es_refetch;
wire        es_refetch;
wire [31:0] tlb_pa;
wire        es_ex_tlbr;
wire        es_ex_pis;
wire        es_ex_pil;
wire        es_ex_pme;
wire        es_ex_ppi;
wire        es_ex_adem;
wire [31:0] es_pa;
wire        dmw0_hit;
wire        dmw1_hit;
wire [31:0] dmw_pa;

assign {ds_to_es_refetch,
        es_tlb_op   ,
        invtlb_op   ,
        es_cnt_op,
        ds_to_es_csr_esubcode,
        ds_to_es_ex ,
        es_ertn     ,
        ds_csr_ecode,
        es_csr_re   ,
        es_csr_we   ,
        ds_csr_num  ,
        es_csr_wmask,
        es_load_op     ,
        es_st_op    ,
        es_mul_signed  ,  //155:155
        es_mul_unsigned,  //154:154
        es_mul_high    ,  //153:153
        es_div_signed  ,  //152:152
        es_div_unsigned,  //151:151
        es_div_mod     ,  //150:150
        es_alu_op      ,  //149:138
        es_res_from_mem,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

assign es_csr_esubcode = ((!ds_to_es_ex) && es_ex_adem) ? 9'h1 : ds_to_es_csr_esubcode;
assign es_refetch = ds_to_es_refetch;
assign es_to_ms_bus = {s1_found    ,
                       s1_index    ,
                       es_refetch  ,
                       es_tlb_op   ,
                       es_mem_req  ,
                       es_vaddr    ,
                       es_csr_esubcode,
                       es_ex       ,
                       es_ertn     ,
                       es_csr_wvalue,
                       es_csr_ecode,
                       es_csr_re   ,
                       es_csr_we   ,
                       es_csr_num  ,
                       es_csr_wmask,
                       es_load_op     ,
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result      ,  //63:32
                       es_pc             //31:0
                      };

//------------forward-------------
assign es_mem_req = es_res_from_mem || es_mem_we;

assign es_fwd_result = es_cnt_op[1] ? timer_cnt[63:32]
                    : es_cnt_op[0] ? timer_cnt[31: 0]  
                    : es_alu_result;

assign es_fwd_valid = es_to_ms_valid && es_gr_we;

assign es_blk_valid = es_valid && es_res_from_mem ? 1'b1 :
                      data_sram_process && es_res_from_mem ? 1'b1 :
                      1'b0;


assign es_fwd_bus = {es_csr_re && es_to_ms_valid ,
                     es_fwd_valid ,   //38:38
                     es_blk_valid ,   //37:37
                     es_dest      ,   //36:32
                     es_result   //31:0
                    };

wire es_div_valid;
assign es_div_valid = (~(es_div_signed | es_div_unsigned)) 
                     | (es_div_signed & signed_dout_tvalid) 
                     | (es_div_unsigned & unsigned_dout_tvalid);

assign es_ready_go    = (es_flush_pipe || es_div_valid) 
                     && ((data_sram_req && data_sram_addr_ok) || !es_mem_req || es_ale_h || es_ale_w || es_ex_tlbr || es_ex_pis || es_ex_pil || es_ex_pme || es_ex_ppi || es_ex_adem)
                     && !tlb_blk;

assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && ~es_flush_pipe ;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_flush_pipe) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

//----------------mul&div--------------------
wire [63:0] unsigned_prod         ;
wire [63:0] signed_prod           ;

reg         signed_divisor_tvalid ;
wire        signed_divisor_tready ;
reg         signed_dividend_tvalid;
wire        signed_dividend_tready;
wire [31:0] signed_divisor_tdata  ;
wire [31:0] signed_dividend_tdata ;
wire [63:0] signed_div_result     ;

reg         unsigned_divisor_tvalid ;
wire        unsigned_divisor_tready ;
wire [31:0] unsigned_divisor_tdata  ;
reg         unsigned_dividend_tvalid;
wire        unsigned_dividend_tready;
wire [31:0] unsigned_dividend_tdata ;
wire [63:0] unsigned_div_result     ;

wire        signed_dout_tvalid      ;
wire        unsigned_dout_tvalid    ;

assign unsigned_prod = es_alu_src1 * es_alu_src2;
assign signed_prod = $signed(es_alu_src1) * $signed(es_alu_src2);


div_signed u_div_signed(
    .aclk                       (clk),
    .s_axis_divisor_tvalid      (signed_divisor_tvalid),
    .s_axis_divisor_tready      (signed_divisor_tready),
    .s_axis_divisor_tdata       (signed_divisor_tdata),
    .s_axis_dividend_tvalid     (signed_dividend_tvalid),
    .s_axis_dividend_tready     (signed_dividend_tready),
    .s_axis_dividend_tdata      (signed_dividend_tdata),
    .m_axis_dout_tvalid         (signed_dout_tvalid),
    .m_axis_dout_tdata          (signed_div_result)
    
    );

assign signed_divisor_tdata = es_alu_src2;
assign signed_dividend_tdata = es_alu_src1;

always @(posedge clk)
begin
    if(reset) begin
        signed_divisor_tvalid <= 1'b0;
        signed_dividend_tvalid <= 1'b0;
    end
    else if(es_valid & es_div_signed & ~signed_divisor_tready & ~signed_dividend_tready & (div_cycle==4'd0) )
    begin
        signed_divisor_tvalid <= 1'b1;
        signed_dividend_tvalid <= 1'b1;
    end
    else 
    begin
        signed_divisor_tvalid <= 1'b0;
        signed_dividend_tvalid <= 1'b0;
    end
    
end

div_unsigned u_div_unsigned(
    .aclk                       (clk),
    .s_axis_divisor_tvalid      (unsigned_divisor_tvalid),
    .s_axis_divisor_tready      (unsigned_divisor_tready),
    .s_axis_divisor_tdata       (unsigned_divisor_tdata),
    .s_axis_dividend_tvalid     (unsigned_dividend_tvalid),
    .s_axis_dividend_tready     (unsigned_dividend_tready),
    .s_axis_dividend_tdata      (unsigned_dividend_tdata),
    .m_axis_dout_tvalid         (unsigned_dout_tvalid),
    .m_axis_dout_tdata          (unsigned_div_result)
    
    );

assign unsigned_divisor_tdata = es_alu_src2;
assign unsigned_dividend_tdata = es_alu_src1;

always @(posedge clk)
begin
    if(reset) begin
        unsigned_divisor_tvalid <= 1'b0;
        unsigned_dividend_tvalid <= 1'b0;
    end
    else if(es_valid & es_div_unsigned & ~unsigned_divisor_tready & ~unsigned_dividend_tready  & (divu_cycle==4'd0))
    begin
        unsigned_divisor_tvalid <= 1'b1;
        unsigned_dividend_tvalid <= 1'b1;
    end
    else
    begin
        unsigned_divisor_tvalid <= 1'b0;
        unsigned_dividend_tvalid <= 1'b0;
    end
    
end

always @(posedge clk)
begin
    if(reset) begin
       div_cycle <= 4'd0;
    end
    else if(signed_dout_tvalid)
    begin
        div_cycle <= 4'd0;
    end
    else if (es_valid &es_div_signed & signed_divisor_tready)
    begin
        div_cycle <= div_cycle + 4'd1;
    end
    else
        div_cycle <= div_cycle;
    
end


always @(posedge clk)
begin
    if(reset) begin
       divu_cycle <= 4'd0;
    end
    else if(unsigned_dout_tvalid)
    begin
        divu_cycle <= 4'd0;
    end
    else if (es_valid & es_div_unsigned & unsigned_divisor_tready)
    begin
        divu_cycle <= divu_cycle + 4'd1;
    end
    else
        divu_cycle <= divu_cycle;
    
end

reg [63:0] timer_cnt;
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 64'h0;
    else 
        timer_cnt <= timer_cnt + 1'b1;
end

assign es_result = (es_mul_signed   &&  es_mul_high)? signed_prod[63:32] :
                   (es_mul_signed   && ~es_mul_high)? signed_prod[31:0] :
                   (es_mul_unsigned &&  es_mul_high)? unsigned_prod[63:32]:
                   (es_div_signed   &&  es_div_mod) ? signed_div_result[63:32]:
                   (es_div_signed   && ~es_div_mod) ? signed_div_result[31:0]:
                   (es_div_unsigned &&  es_div_mod) ? unsigned_div_result[63:32]:
                   (es_div_unsigned && ~es_div_mod) ? unsigned_div_result[31:0] :
                   es_cnt_op[1] ? timer_cnt[63:32] :
                   es_cnt_op[0] ? timer_cnt[31: 0] : 
                   es_alu_result;
                                   
//assign es_vaddr = es_alu_result;
assign es_vaddr = (ds_csr_ecode == `ECODE_PIF || ds_csr_ecode == `ECODE_PME 
                || ds_csr_ecode == `ECODE_PPI || ds_csr_ecode == `ECODE_TLBR) ? es_pc : es_alu_result;

assign es_vaddr_type = es_vaddr[1:0];

assign es_st_data = {32{es_st_op[0]}} & {4{es_rkd_value[ 7:0]}}
                  | {32{es_st_op[1]}} & {2{es_rkd_value[15:0]}}
                  | {32{es_st_op[2]}} & es_rkd_value;

assign es_st_strb = { 4{es_st_op[0]}} & (4'b0001 << es_vaddr_type)
                  | { 4{es_st_op[1]}} & (4'b0011 << es_vaddr_type)
                  | { 4{es_st_op[2]}} & 4'b1111;

//---------Exception-------------
assign es_ale_h = es_vaddr_type[0] && (es_load_op[1] || es_load_op[4] || es_st_op[1]);
assign es_ale_w = es_vaddr_type && (es_load_op[2] || es_st_op[2]);
assign es_ex_adem = es_mem_req && es_alu_result[31] && csr_crmd_rvalue[`CSR_CRMD_PG] && !(dmw0_hit || dmw1_hit);

assign es_csr_ecode = ds_to_es_ex ? ds_csr_ecode
                    : (es_ale_h || es_ale_w) ? `ECODE_ALE
                    : es_ex_adem  ? `ECODE_ADE 
                    : es_ex_tlbr  ? `ECODE_TLBR
                    : es_ex_pil   ? `ECODE_PIL
                    : es_ex_pis   ? `ECODE_PIS
                    : es_ex_pme   ? `ECODE_PME
                    : es_ex_ppi   ? `ECODE_PPI
                    : 6'h0; 

assign es_csr_num = ds_to_es_ex ? ds_csr_num
                  : (es_ale_h || es_ale_w || es_ex_pis || es_ex_pil || es_ex_pme || es_ex_ppi || es_ex_adem) ? `CSR_EENTRY 
                  : (es_ex_tlbr) ? `CSR_TLBRENTRY
                  :  ds_csr_num;

assign es_csr_wvalue = es_rkd_value; 

assign es_st_ex = es_ex || ms_ex || es_flush_pipe; // exception from exe, mem, wb

assign es_ex = (ds_to_es_ex || es_ale_h || es_ale_w || es_ex_tlbr || es_ex_pis || es_ex_pil || es_ex_pme || es_ex_ppi || es_ex_adem) && es_valid; 

//------------TLB------------------
assign s1_vppn = (es_tlb_op != 5'b0) ? 
                 (es_tlb_op == `TLB_INV ? es_rkd_value[31:13] : tlb_ehi_rvalue[31:13])
                                    : es_alu_result[31:13];

assign s1_asid = es_tlb_op == `TLB_INV ? es_rj_value[9:0] : tlb_asid_rvalue[9:0];

assign s1_va_bit12 =  (es_tlb_op != 5'b0) ? 1'b0 : es_alu_result[12];

assign invtlb_valid = (es_tlb_op == `TLB_INV);

assign tlb_blk = ms_tlb_blk && es_tlb_op == `TLB_SRCH;

assign tlb_pa = (s1_ps == 6'd12) ? {s1_ppn, es_alu_result[11:0]} : {s1_ppn[9:0], es_alu_result[21:0]};

assign es_ex_tlbr = !s1_found && csr_crmd_rvalue[`CSR_CRMD_PG] && es_mem_req && !(dmw0_hit || dmw1_hit);
assign es_ex_pis = s1_found && csr_crmd_rvalue[`CSR_CRMD_PG] && !s1_v && es_mem_we && !(dmw0_hit || dmw1_hit);
assign es_ex_pil = s1_found && csr_crmd_rvalue[`CSR_CRMD_PG] && !s1_v && es_res_from_mem && !(dmw0_hit || dmw1_hit);
assign es_ex_pme = s1_found && csr_crmd_rvalue[`CSR_CRMD_PG] && s1_v && es_mem_we && !s1_d && !(csr_crmd_rvalue[`CSR_CRMD_PLV] > s1_plv) && !(dmw0_hit || dmw1_hit);
assign es_ex_ppi = s1_found && csr_crmd_rvalue[`CSR_CRMD_PG] && s1_v 
&& (csr_crmd_rvalue[`CSR_CRMD_PLV]==3'd3 && s1_plv==3'd0) && es_mem_req && !(dmw0_hit || dmw1_hit);

assign dmw0_hit = (csr_crmd_rvalue[`CSR_CRMD_PLV] == 2'd0 ? csr_dmw0_rvalue[`CSR_DMW_PLV0] : csr_dmw0_rvalue[`CSR_DMW_PLV3])
               && (es_alu_result[31:29] == csr_dmw0_rvalue[`CSR_DMW_VSEG]);

assign dmw1_hit = (csr_crmd_rvalue[`CSR_CRMD_PLV] == 2'd0 ? csr_dmw1_rvalue[`CSR_DMW_PLV0] : csr_dmw1_rvalue[`CSR_DMW_PLV3])
               && (es_alu_result[31:29] == csr_dmw1_rvalue[`CSR_DMW_VSEG]);

assign dmw_pa = dmw0_hit ? {csr_dmw0_rvalue[`CSR_DMW_PSEG], es_alu_result[28:0]}
              : dmw1_hit ? {csr_dmw1_rvalue[`CSR_DMW_PSEG], es_alu_result[28:0]}
              : 32'b0;

assign es_pa = csr_crmd_rvalue[`CSR_CRMD_DA] ? es_alu_result : (dmw0_hit || dmw1_hit) ? dmw_pa : tlb_pa;

// data sram
reg data_sram_process;
always@(posedge clk) begin
    if(reset) begin
        data_sram_process <= 1'b0;
    end
    else if(data_sram_addr_ok && data_sram_req) begin
        data_sram_process <= 1'b1;
    end
    else if(data_sram_data_ok) begin
        data_sram_process <= 1'b0;
    end
end
assign data_sram_req    = ~es_ex_adem && ~es_st_ex && (es_res_from_mem || es_mem_we) && es_valid && ms_allowin /* && ~data_sram_process */;
assign data_sram_wr     =  ~es_ex_adem && es_mem_we && ~es_st_ex && ~es_flush_pipe;
assign data_sram_wstrb  = (es_mem_we && ~es_st_ex && ~es_flush_pipe) ? es_st_strb : 4'h0;
assign data_sram_addr   = es_pa;
assign data_sram_wdata  = es_st_data;
assign data_sram_size   = ( es_load_op[2] || es_st_op[2] ) ? 2'd2 :
                          ( es_load_op[1] || es_load_op[4] || es_st_op[1] ) ? 2'd1 :
                          2'd0;

endmodule
