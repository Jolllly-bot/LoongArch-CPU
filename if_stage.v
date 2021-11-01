`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_ram_req,
    output        inst_ram_wr,
    output [1 :0] inst_ram_size,
    output [3 :0] inst_ram_wstrb,
    output [31:0] inst_ram_addr,
    output [31:0] inst_ram_wdata;
    input         inst_ram_addr_ok,
    input         inst_ram_data_ok,
    input [31:0]  inst_ram_rdata,

    input  [31:0] ws_to_fs_bus   ,
    input         fs_flush_pipe
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_taken_cancel,br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

assign fs_to_ds_bus = {fs_ex,
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
wire fs_ex;
wire fs_ex_adef;

assign fs_ex = fs_valid && fs_ex_adef;
assign fs_ex_adef = nextpc[1] || nextpc[0];

assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = fs_flush_pipe ? ws_to_fs_bus : 
                      br_taken ? br_target 
                      : seq_pc; 

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && ~fs_flush_pipe && ~br_taken;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign inst_ram_req    = to_fs_valid && fs_allowin;
assign inst_ram_wr     = 1'b0;
assign inst_ram_wstrb  = 4'h0;
assign inst_ram_addr   = nextpc; 
assign inst_ram_wdata  = 32'b0;

assign fs_inst         = inst_ram_rdata;

endmodule
