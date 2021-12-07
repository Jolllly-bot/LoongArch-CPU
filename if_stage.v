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

    input  [31:0] ws_to_fs_bus,
    input         fs_flush_pipe,

    // search port 0 (for fetch)
    output [18:0] s0_vppn,
    output        s0_va_bit12,
    output [ 9:0] s0_asid,
    input         s0_found,
    input  [ 3:0] s0_index,
    input  [19:0] s0_ppn,
    input  [ 5:0] s0_ps,
    input  [ 1:0] s0_plv,
    input  [ 1:0] s0_mat,
    input         s0_d,
    input         s0_v,
    input  [31:0] tlb_asid_rvalue,
    input  [31:0] csr_crmd_rvalue,
    input  [31:0] csr_dmw0_rvalue,
    input  [31:0] csr_dmw1_rvalue

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
assign {br_stall,
        br_taken,
        br_taken_cancel,
        br_target} = br_bus;

reg          fs_inst_valid;
reg   [31:0] fs_inst_r;
wire  [31:0] fs_inst;
reg   [31:0] fs_pc;
wire  [31:0] tlb_pa;
wire  [31:0] fs_pa;



assign fs_to_ds_bus = {fs_csr_ecode,
                       fs_ex,
                       fs_inst ,
                       fs_pc   };

// pre-IF stage
wire         fs_ex;
wire         fs_ex_adef;
wire         fs_ex_tlbr;
wire         fs_ex_pif;
wire         fs_ex_ppi;
wire  [ 5:0] fs_csr_ecode;
wire         dmw0_hit;
wire         dmw1_hit;
wire  [31:0] dmw_pa;

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
    else if(!pre_fs_ready_go && br_stall)begin
        pc_buffer_valid <= 1'b0;
        pc_buffer <= 32'h0;
    end
    else if (pre_fs_ready_go) begin
        pc_buffer_valid <= 1'b0;
        pc_buffer <= 32'h0;
    end
end


assign fs_ex = fs_valid && (fs_ex_adef || fs_ex_tlbr || fs_ex_pif || fs_ex_ppi);
assign fs_ex_adef = (nextpc[1] || nextpc[0])
                ||  (nextpc[31] && csr_crmd_rvalue[`CSR_CRMD_PG]);


//------------TLB------------
assign s0_vppn = nextpc[31:13];
assign s0_va_bit12 = nextpc[12];
assign s0_asid = tlb_asid_rvalue[`CSR_ASID_ASID];

assign tlb_pa = (s0_ps == 6'd12) ? {s0_ppn, nextpc[11:0]} : {s0_ppn[9:0], nextpc[21:0]};
assign fs_ex_tlbr = !s0_found && csr_crmd_rvalue[`CSR_CRMD_PG] && !(dmw0_hit || dmw1_hit);
assign fs_ex_pif = s0_found && csr_crmd_rvalue[`CSR_CRMD_PG] && !s0_v && !(dmw0_hit || dmw1_hit);
assign fs_ex_ppi = s0_found && csr_crmd_rvalue[`CSR_CRMD_PG] && (csr_crmd_rvalue[`CSR_CRMD_PLV]==3'd3 && s0_plv==3'd0) && !(dmw0_hit || dmw1_hit);
assign fs_csr_ecode = fs_ex_adef? `ECODE_ADE
                    : fs_ex_tlbr? `ECODE_TLBR
                    : fs_ex_pif ? `ECODE_PIF
                    : fs_ex_ppi ? `ECODE_PPI
                    : 6'h0;

assign dmw0_hit = (csr_crmd_rvalue[`CSR_CRMD_PLV] == 2'd0 ? csr_dmw0_rvalue[`CSR_DMW_PLV0] : csr_dmw0_rvalue[`CSR_DMW_PLV3])
               && (nextpc[31:29] == csr_dmw0_rvalue[`CSR_DMW_VSEG]);

assign dmw1_hit = (csr_crmd_rvalue[`CSR_CRMD_PLV] == 2'd0 ? csr_dmw1_rvalue[`CSR_DMW_PLV0] : csr_dmw1_rvalue[`CSR_DMW_PLV3])
               && (nextpc[31:29] == csr_dmw1_rvalue[`CSR_DMW_VSEG]);

assign dmw_pa = {32{dmw0_hit}} && {csr_dmw0_rvalue[`CSR_DMW_PSEG], nextpc[28:0]}
             || {32{dmw1_hit}} && {csr_dmw1_rvalue[`CSR_DMW_PSEG], nextpc[28:0]};

assign fs_pa = csr_crmd_rvalue[`CSR_CRMD_DA] ? nextpc : (dmw0_hit || dmw1_hit) ? dmw_pa : tlb_pa;

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

assign inst_sram_req    = fs_allowin && !br_stall; //TODO: more complicated solution
assign inst_sram_wr     = 1'b0;
assign inst_sram_wstrb  = 4'h0;
assign inst_sram_addr   = fs_pa; 
assign inst_sram_wdata  = 32'b0;
assign inst_sram_size   = 2'h2;

assign fs_inst         = fs_inst_valid ? fs_inst_r : inst_sram_rdata;


endmodule
