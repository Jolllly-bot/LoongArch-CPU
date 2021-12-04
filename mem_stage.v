`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //forward
    output [`MS_FWD_BUS_WD   -1:0] ms_fwd_bus    ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input                          data_sram_data_ok,
    input  ms_flush_pipe,
    output ms_to_es_ex,
    output ms_tlb_blk
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire [ 4:0] ms_load_op;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_result;
wire [31:0] ms_pc;

wire        ms_fwd_valid;
wire        ms_tlb_blk;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire [ 3:0] ms_vaddr_type;
wire [31:0] lb_data;
wire [31:0] lbu_data;
wire [31:0] lh_data;
wire [31:0] lhu_data;
wire [31:0] lw_data;


wire        es_to_ms_ex;
wire        ms_ex;
wire [13:0] ms_csr_num;
wire        ms_csr_we;
wire        ms_csr_re;
wire [31:0] ms_csr_wmask;
wire        ms_ertn;
wire        ms_syscall;
wire [31:0] ms_csr_wvalue;
wire [ 5:0] ms_csr_ecode;
wire [ 8:0] ms_csr_esubcode;
wire [31:0] ms_vaddr;
wire        ms_mem_req;
wire [ 4:0] ms_tlb_op;
wire        es_to_ms_refetch;
wire        ms_refetch;
wire        ms_s1_found;
wire [ 3:0] ms_s1_index;

assign {ms_s1_found,
        ms_s1_index,
        es_to_ms_refetch ,
        ms_tlb_op  ,
        ms_mem_req ,
        ms_vaddr,
        ms_csr_esubcode ,
        es_to_ms_ex  ,
        ms_ertn,
        ms_csr_wvalue,
        ms_csr_ecode,
        ms_csr_re   ,
        ms_csr_we   ,
        ms_csr_num  ,
        ms_csr_wmask,
        ms_load_op     ,
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;


assign ms_ex = es_to_ms_ex && ms_to_ws_valid; 
assign ms_to_es_ex = (es_to_ms_ex || ms_ertn) && ms_to_ws_valid;
assign ms_refetch = es_to_ms_refetch;
assign ms_to_ws_bus = {ms_s1_found  ,
                       ms_s1_index  ,
                       ms_refetch   ,
                       ms_tlb_op,
                       ms_vaddr,
                       ms_csr_esubcode,
                       ms_ex       ,
                       ms_ertn     ,
                       ms_csr_wvalue,
                       ms_csr_ecode,
                       ms_csr_re   ,
                       ms_csr_we   ,
                       ms_csr_num  ,
                       ms_csr_wmask,
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };


//---------forward------------
assign ms_tlb_blk = ms_to_ws_valid 
                && (ms_csr_we && (ms_csr_num == `CSR_ASID || ms_csr_num == `CSR_TLBEHI))
                && (ms_tlb_op == `TLB_RD); //TODO?

assign ms_fwd_valid = ms_to_ws_valid && ms_gr_we;

assign ms_fwd_bus = {ms_csr_re && ms_to_ws_valid,
                     ms_fwd_valid   , //37:37
                     ms_dest        , //36:32
                     ms_final_result  //31:0
                    };

assign ms_ready_go    = data_sram_data_ok || !ms_mem_req || es_to_ms_ex;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go && ~ms_flush_pipe;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_flush_pipe) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end


decoder_2_4 u_dec_ms(.in(ms_vaddr[1:0]), .out(ms_vaddr_type));

assign lb_data = {32{ms_vaddr_type[0]}} & {{24{data_sram_rdata[ 7]}}, data_sram_rdata[ 7: 0]}
                |{32{ms_vaddr_type[1]}} & {{24{data_sram_rdata[15]}}, data_sram_rdata[15: 8]}
                |{32{ms_vaddr_type[2]}} & {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]}
                |{32{ms_vaddr_type[3]}} & {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]};

assign lbu_data = {32{ms_vaddr_type[0]}} & {24'b0, data_sram_rdata[ 7: 0]}
                 |{32{ms_vaddr_type[1]}} & {24'b0, data_sram_rdata[15: 8]}
                 |{32{ms_vaddr_type[2]}} & {24'b0, data_sram_rdata[23:16]}
                 |{32{ms_vaddr_type[3]}} & {24'b0, data_sram_rdata[31:24]};

assign lh_data = {32{ ms_vaddr_type[0]}} & {{16{data_sram_rdata[15]}}, data_sram_rdata[15: 0]}
                |{32{~ms_vaddr_type[0]}} & {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]};

assign lhu_data = {32{ ms_vaddr_type[0]}} & {16'b0, data_sram_rdata[15: 0]}
                 |{32{~ms_vaddr_type[0]}} & {16'b0, data_sram_rdata[31:16]};

assign lw_data = data_sram_rdata;

assign mem_result = {32{ms_load_op[0]}} & lb_data
                  | {32{ms_load_op[1]}} & lh_data
                  | {32{ms_load_op[2]}} & lw_data
                  | {32{ms_load_op[3]}} & lbu_data
                  | {32{ms_load_op[4]}} & lhu_data;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_result;
                                         

endmodule
