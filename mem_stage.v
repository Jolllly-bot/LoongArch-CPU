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
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire [ 4:0] ms_load_op;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
assign {ms_load_op     ,
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

//ms forward path
wire ms_fwd_valid;

assign ms_fwd_valid = ms_valid && ms_gr_we;
assign ms_fwd_bus = {ms_fwd_valid   , //37:37
                     ms_dest        , //36:32
                     ms_final_result  //31:0
                    };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

wire [ 3:0] mem_addr;
wire [31:0] lb_data;
wire [31:0] lbu_data;
wire [31:0] lh_data;
wire [31:0] lhu_data;
wire [31:0] lw_data;

decoder_2_4 u_dec_ms(.in(ms_alu_result[1:0]), .out(mem_addr));

assign lb_data = {32{mem_addr[0]}} & {{24{data_sram_rdata[ 7]}}, data_sram_rdata[ 7: 0]}
                |{32{mem_addr[1]}} & {{24{data_sram_rdata[15]}}, data_sram_rdata[15: 8]}
                |{32{mem_addr[2]}} & {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]}
                |{32{mem_addr[3]}} & {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]};

assign lbu_data = {32{mem_addr[0]}} & {24'b0, data_sram_rdata[ 7: 0]}
                 |{32{mem_addr[1]}} & {24'b0, data_sram_rdata[15: 8]}
                 |{32{mem_addr[2]}} & {24'b0, data_sram_rdata[23:16]}
                 |{32{mem_addr[3]}} & {24'b0, data_sram_rdata[31:24]};

assign lh_data = {32{ mem_addr[0]}} & {{16{data_sram_rdata[15]}}, data_sram_rdata[15: 0]}
                |{32{~mem_addr[0]}} & {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]};

assign lhu_data = {32{ mem_addr[0]}} & {16'b0, data_sram_rdata[15: 0]}
                 |{32{~mem_addr[0]}} & {16'b0, data_sram_rdata[31:16]};

assign lw_data = data_sram_rdata;

assign mem_result = {32{ms_load_op[0]}} & lb_data
                  | {32{ms_load_op[1]}} & lh_data
                  | {32{ms_load_op[2]}} & lw_data
                  | {32{ms_load_op[3]}} & lbu_data
                  | {32{ms_load_op[4]}} & lhu_data;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;
                                         

endmodule
