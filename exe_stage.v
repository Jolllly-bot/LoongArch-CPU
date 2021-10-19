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
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input         es_flush_pipe  ,
    input         ms_ex
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
wire [ 2:0] es_st_op    ;
wire [31:0] es_st_data     ;
wire [ 3:0] es_st_strb     ;
wire [ 1:0] es_vaddr       ;

wire        es_mul_signed  ;
wire        es_mul_unsigned;
wire        es_mul_high    ;
wire        es_div_signed  ;
wire        es_div_unsigned;
wire        es_div_mod     ;

wire [13:0] es_csr_num;
wire        es_csr_we;
wire        es_csr_re;
wire [31:0] es_csr_wmask;
wire        es_ertn;
wire        es_syscall;
wire [31:0] es_csr_wvalue;
wire        no_ex;

assign {es_ertn,
        es_syscall,
        es_csr_re   ,
        es_csr_we   ,
        es_csr_num  ,
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

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_result     ;
reg  [3:0] div_cycle      ;
reg  [3:0] divu_cycle     ;

assign es_csr_wvalue = es_rkd_value;

assign es_to_ms_bus = {es_csr_wvalue,
                       es_ertn,
                       es_syscall,
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

//forward path
wire es_fwd_valid;
wire es_blk_valid;

assign es_fwd_valid = es_valid && es_gr_we;
assign es_blk_valid = es_valid && es_res_from_mem;
assign es_fwd_bus = {es_fwd_valid ,   //38:38
                     es_blk_valid ,   //37:37
                     es_dest      ,   //36:32
                     es_alu_result    //31:0
                    };

assign es_ready_go    = (~(es_div_signed | es_div_unsigned)) 
                        | (es_div_signed & signed_dout_tvalid) 
                        | (es_div_unsigned & unsigned_dout_tvalid);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && ~es_flush_pipe;
always @(posedge clk) begin
    if (reset) begin     
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

//-------------------------------------------
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
    else if(es_div_signed & ~signed_divisor_tready & ~signed_dividend_tready & (div_cycle==4'd0) )
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
    else if(es_div_unsigned & ~unsigned_divisor_tready & ~unsigned_dividend_tready  & (divu_cycle==4'd0))
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
    else if (es_div_signed & signed_divisor_tready)
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
    else if (es_div_unsigned & unsigned_divisor_tready)
    begin
        divu_cycle <= divu_cycle + 4'd1;
    end
    else
        divu_cycle <= divu_cycle;
    
end

assign es_result = (es_mul_signed   &&  es_mul_high)? signed_prod[63:32] :
                   (es_mul_signed   && ~es_mul_high)? signed_prod[31:0] :
                   (es_mul_unsigned &&  es_mul_high)? unsigned_prod[63:32]:
                   (es_div_signed   &&  es_div_mod) ? signed_div_result[63:32]:
                   (es_div_signed   && ~es_div_mod) ? signed_div_result[31:0]:
                   (es_div_unsigned &&  es_div_mod) ? unsigned_div_result[63:32]:
                   (es_div_unsigned && ~es_div_mod) ? unsigned_div_result[31:0] :
                                                      es_alu_result;
                                                      

assign es_vaddr = es_alu_result[1:0];

assign es_st_data = {32{es_st_op[0]}} & {4{es_rkd_value[ 7:0]}}
                  | {32{es_st_op[1]}} & {2{es_rkd_value[15:0]}}
                  | {32{es_st_op[2]}} & es_rkd_value;

assign es_st_strb = { 4{es_st_op[0]}} & (4'b0001 << es_vaddr)
                  | { 4{es_st_op[1]}} & (4'b0011 << es_vaddr)
                  | { 4{es_st_op[2]}} & 4'b1111;

assign es_st_ex = es_syscall || es_ertn || ms_ex || es_flush_pipe; // from exe, mem, wb

assign data_sram_en    = (es_res_from_mem || es_mem_we) && es_valid;
assign data_sram_wen   = (es_mem_we && ~es_st_ex) ? es_st_strb : 4'h0;
assign data_sram_addr  = {es_alu_result[31:2], 2'b0};
assign data_sram_wdata = es_st_data;

endmodule
