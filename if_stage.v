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
    output        inst_sram_req,
    output        inst_sram_wr,
    output [1 :0] inst_sram_size,
    output [3 :0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input [31:0]  inst_sram_rdata,

    input  [31:0] ws_to_fs_bus   ,
    input         fs_flush_pipe
);
wire        pre_fs_ready_go;
reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_taken_cancel,br_target} = br_bus;

reg         fs_inst_valid;
reg  [31:0] fs_inst_r;
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

assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = fs_flush_pipe ? ws_to_fs_bus :
                      pc_buffer_valid ? pc_buffer :
                      br_taken ? br_target :
                      seq_pc; 

assign pre_fs_ready_go = inst_sram_req && inst_sram_addr_ok;
assign to_fs_valid  = pre_fs_ready_go; //TODO

reg        pc_buffer_valid;
reg [31:0] pc_buffer;
reg        cancel_r;

always @(posedge clk) begin
    if (reset) begin
        pc_buffer_valid <= 1'b0;
        pc_buffer <= 32'h0;
    end
    else if (!pre_fs_ready_go && fs_flush_pipe) begin
        pc_buffer_valid <= 1'b1;
        pc_buffer <= ws_to_fs_bus;
    end
    else if (!pre_fs_ready_go && br_taken) begin
        pc_buffer_valid <= 1'b1;
        pc_buffer <= br_target;
    end
    else if (pre_fs_ready_go) begin
        pc_buffer_valid <= 1'b0;
        pc_buffer <= 32'h0;
    end
end

// IF stage
assign fs_ready_go    = ((fs_valid && inst_sram_data_ok) || fs_inst_valid ) && !cancel_r;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
    else if (br_taken_cancel || fs_flush_pipe) begin
        fs_valid <= 1'b0;
    end

    if (reset) begin
        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end

     if (reset) begin
        fs_inst_valid <= 1'b0;
        fs_inst_r <= 32'h0;
    end
    else if ( /* !fs_inst_valid && */  fs_valid && fs_ready_go && !ds_allowin) begin
        fs_inst_valid <= 1'b1;
        fs_inst_r     <= inst_sram_rdata;
    end
    else if ((br_taken_cancel || fs_flush_pipe) && fs_inst_valid && !fs_allowin && fs_ready_go) begin
         fs_inst_valid <= 1'b0;
    end
    else begin
        fs_inst_valid <= 1'b0;
        fs_inst_r <= 32'h0;
    end 

    if (reset) begin
        cancel_r <= 1'b0;
    end
    else if (!inst_sram_data_ok  && !fs_inst_valid && br_taken_cancel && (to_fs_valid && !br_taken)) begin
        cancel_r <= 1'b1;
    end
    else if (!inst_sram_data_ok && !fs_inst_valid && (br_taken_cancel || fs_flush_pipe) && !fs_allowin && !fs_ready_go) begin
        cancel_r <= 1'b1;
    end
    else if (inst_sram_data_ok) begin
        cancel_r <= 1'b0;
    end
end

assign inst_sram_req    = fs_allowin; //TODO: more complicated solution
assign inst_sram_wr     = 1'b0;
assign inst_sram_wstrb  = 4'h0;
assign inst_sram_addr   = nextpc; 
assign inst_sram_wdata  = 32'b0;
assign inst_sram_size   = 2'h2;

assign fs_inst         = fs_inst_valid ? fs_inst_r : inst_sram_rdata;


endmodule
