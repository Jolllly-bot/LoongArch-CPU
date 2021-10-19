`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output [31:0] ws_to_fs_bus,
    output        ws_flush_pipe
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire [13:0] ws_csr_num;
wire ws_csr_we;
wire ws_csr_re;
wire [31:0] ws_csr_wmask;
wire [31:0] ws_csr_rvalue;
wire [31:0] ws_csr_wvalue;

wire ws_ertn;
wire ws_syscall;

wire         wb_ex;
wire  [ 5:0] wb_ecode;
wire  [ 8:0] wb_esubcode;
wire         eret_flush;
wire         ws_flush_pipe;


assign {ws_csr_wvalue,
        ws_ertn,
        ws_syscall,
        ws_csr_re   ,
        ws_csr_we   ,
        ws_csr_num  ,
        ws_csr_wmask,
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = (ws_gr_we || ws_csr_re) && ws_valid;
assign rf_waddr = ws_dest;
//---------------------------------------
assign rf_wdata = ws_csr_re ? ws_csr_rvalue : ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_csr_re ? ws_csr_rvalue : ws_final_result;

assign eret_flush = ws_ertn;
assign wb_ecode = `ECODE_SYS;

assign wb_esubcode = 9'b0;
assign wb_ex = ws_syscall;

assign ws_flush_pipe = (wb_ex|eret_flush) && ws_valid;
assign ws_to_fs_bus = ws_csr_rvalue;

csr u_csr(
    .clk    (clk      ),
    .reset  (reset    ),
    .csr_re (ws_csr_re | ws_ertn),
    .csr_num (ws_csr_num),
    .csr_rvalue(ws_csr_rvalue),
    .csr_we  (ws_csr_we),
    .csr_wmask(ws_csr_wmask),
    .csr_wvalue(ws_csr_wvalue),
    .wb_ex(wb_ex),
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .eret_flush(eret_flush),
    .wb_pc(ws_pc)
    );

endmodule
