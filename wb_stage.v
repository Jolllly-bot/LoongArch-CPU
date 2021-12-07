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
    output        ws_flush_pipe,
    // write port
    output         we, //w(rite) e(nable)
    output  [ 3:0] w_index,
    output         w_e,
    output  [ 5:0] w_ps,
    output  [18:0] w_vppn,
    output  [ 9:0] w_asid,
    output         w_g,
    output  [19:0] w_ppn0,
    output  [ 1:0] w_plv0,
    output  [ 1:0] w_mat0,
    output         w_d0,
    output         w_v0,
    output  [19:0] w_ppn1,
    output  [ 1:0] w_plv1,
    output  [ 1:0] w_mat1,
    output         w_d1,
    output         w_v1,
    // read port
    output  [ 3:0] r_index,
    input          r_e,
    input   [18:0] r_vppn,
    input   [ 5:0] r_ps,
    input   [ 9:0] r_asid,
    input          r_g,
    input   [19:0] r_ppn0,
    input   [ 1:0] r_plv0,
    input   [ 1:0] r_mat0,
    input          r_d0,
    input          r_v0,
    input   [19:0] r_ppn1,
    input   [ 1:0] r_plv1,
    input   [ 1:0] r_mat1,
    input          r_d1,
    input          r_v1,
    output  [31:0] ws_asid_rvalue,
    output  [31:0] ws_ehi_rvalue,
    output  [31:0] ws_crmd_rvalue,
    output  [31:0] ws_dmw0_rvalue,
    output  [31:0] ws_dmw1_rvalue
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

wire         ms_to_ws_ex;
wire         ws_ex;
wire  [ 5:0] ws_csr_ecode;
wire  [ 8:0] wb_esubcode;
wire         eret_flush;
wire         ws_flush_pipe;

wire         ws_has_int;
wire  [ 7:0] ws_hw_int_in;
wire         ws_ipi_int_in;
wire  [31:0] ws_coreid_in;
wire  [31:0] wb_vaddr;
wire  [ 4:0] ws_tlb_op;
wire  [31:0] tlb_asid_rvalue;
wire  [31:0] tlb_ehi_rvalue;

wire         tlb_hit;
wire         tlb_re;
wire [31: 0] tlb_idx_wvalue;
wire [31: 0] tlb_ehi_wvalue;
wire [31: 0] tlb_elo0_wvalue;
wire [31: 0] tlb_elo1_wvalue;
wire [31: 0] tlb_asid_wvalue;
wire [31: 0] tlb_idx_rvalue;
wire [31: 0] tlb_elo0_rvalue;
wire [31: 0] tlb_elo1_rvalue;
wire [31: 0] tlb_dmw0_rvalue;
wire [31: 0] tlb_dmw1_rvalue;

wire [31: 0] csr_estat_rvalue;
wire [31: 0] csr_crmd_rvalue;

reg  [ 4:0]  tlb_fill_index;
wire         ws_refetch;
wire         ws_s1_found;
wire [ 3:0]  ws_s1_index;
wire         tlb_idx_ne;

assign {ws_s1_found,
        ws_s1_index,
        ws_refetch,
        ws_tlb_op,
        wb_vaddr,
        wb_esubcode,
        ms_to_ws_ex ,
        ws_ertn     ,
        ws_csr_wvalue,
        ws_csr_ecode,
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


assign ws_to_rf_bus = {ws_has_int,
                       ws_csr_re && ws_valid,
                       rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_ex || eret_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_wdata = ws_csr_re ? ws_csr_rvalue : ws_final_result;
assign rf_waddr = ws_dest;
assign rf_we    = (ws_gr_we || ws_csr_re) && ws_valid && ~ws_ex && ~ws_refetch;

//--------------Exception----------------
assign ws_ex = ms_to_ws_ex && ws_valid;
assign eret_flush = ws_ertn && ws_valid;

assign ws_hw_int_in = 8'b0;
assign ws_ipi_int_in = 1'b0;
assign ws_coreid_in = 32'b0;


assign ws_flush_pipe = (ws_ex || eret_flush || ws_refetch) && ws_valid;
assign ws_to_fs_bus = ws_refetch ? ws_pc : ws_csr_rvalue;


//---------------TLB-------------------
assign tlb_hit         = (ws_tlb_op == `TLB_SRCH) && ws_s1_found; 
assign tlb_re          = r_e && ws_valid;
assign tlb_idx_wvalue  = {~r_e, 1'b0, r_ps, 20'b0, ws_s1_index};
assign tlb_ehi_wvalue  = {r_vppn,13'b0};
assign tlb_elo0_wvalue = {r_ppn0, 1'b0, r_g, r_mat0, r_plv0, r_d0, r_v0};
assign tlb_elo1_wvalue = {r_ppn1, 1'b0, r_g, r_mat1, r_plv1, r_d1, r_v1};
assign tlb_asid_wvalue = {22'b0,r_asid};

assign r_index = tlb_idx_rvalue[3:0];
 
assign we = (ws_tlb_op == `TLB_WR) || (ws_tlb_op == `TLB_FILL);
assign w_index = (ws_tlb_op == `TLB_WR) ? tlb_idx_rvalue[4:0]
                :(ws_tlb_op == `TLB_FILL) ? tlb_fill_index[4:0]
                :5'b0;
assign w_e    = (csr_estat_rvalue[21:16]==6'h3f) || ~tlb_idx_rvalue[31];
assign w_ps   = tlb_idx_rvalue[29:24];
assign w_vppn = tlb_ehi_rvalue[31:13];
assign w_asid = tlb_asid_rvalue[9:0];
assign w_g    = tlb_elo1_rvalue[6] &  tlb_elo0_rvalue [6]; 
assign w_ppn0 = tlb_elo0_rvalue [31:8];
assign w_plv0 = tlb_elo0_rvalue [3:2];
assign w_mat0 = tlb_elo0_rvalue [5:4];
assign w_d0   = tlb_elo0_rvalue [1];
assign w_v0   = tlb_elo0_rvalue [0];
assign w_ppn1 = tlb_elo1_rvalue [31:8];
assign w_plv1 = tlb_elo1_rvalue [3:2];
assign w_mat1 = tlb_elo1_rvalue [5:4];
assign w_d1   = tlb_elo1_rvalue [1];
assign w_v1   = tlb_elo1_rvalue [0];

assign ws_asid_rvalue = tlb_asid_rvalue;
assign ws_ehi_rvalue = tlb_ehi_rvalue;
assign ws_crmd_rvalue = csr_crmd_rvalue;
assign ws_dmw0_rvalue = tlb_dmw0_rvalue;
assign ws_dmw1_rvalue = tlb_dmw1_rvalue;
 
always @(posedge clk)begin
    if(reset)begin
        tlb_fill_index <= 5'b0;
    end
    else if((ws_tlb_op == `TLB_FILL) && ws_valid) begin
        if(tlb_fill_index == 5'd31) begin
            tlb_fill_index <= 5'b0;
        end
        else begin
            tlb_fill_index <= tlb_fill_index + 5'b1;
        end
    end
end

csr u_csr(
    .clk         (clk      ),
    .reset       (reset    ),
    .csr_re      (ws_csr_re | ws_ertn),
    .csr_num     (ws_csr_num),
    .csr_rvalue  (ws_csr_rvalue),
    .csr_we      (ws_csr_we),
    .csr_wmask   (ws_csr_wmask),
    .csr_wvalue  (ws_csr_wvalue),
    .wb_ex       (ws_ex),
    .wb_ecode    (ws_csr_ecode),
    .wb_esubcode (wb_esubcode),
    .eret_flush  (eret_flush),
    .wb_pc       (ws_pc),
    .has_int     (ws_has_int),
    .hw_int_in   (ws_hw_int_in),
    .ipi_int_in  (ws_ipi_int_in),
    .coreid_in   (ws_coreid_in),
    .wb_vaddr    (wb_vaddr),

    .tlb_op           (ws_tlb_op), 
    .tlb_hit          (tlb_hit),
    .tlb_re           (tlb_re),
    .tlb_idx_wvalue   (tlb_idx_wvalue),
    .tlb_ehi_wvalue   (tlb_ehi_wvalue),
    .tlb_elo0_wvalue  (tlb_elo0_wvalue),
    .tlb_elo1_wvalue  (tlb_elo1_wvalue),
    .tlb_asid_wvalue  (tlb_asid_wvalue),
    .tlb_idx_rvalue   (tlb_idx_rvalue),
    .tlb_ehi_rvalue   (tlb_ehi_rvalue),
    .tlb_elo0_rvalue  (tlb_elo0_rvalue),
    .tlb_elo1_rvalue  (tlb_elo1_rvalue),
    .tlb_asid_rvalue  (tlb_asid_rvalue),
    .tlb_dmw0_rvalue  (tlb_dmw0_rvalue),
    .tlb_dmw1_rvalue  (tlb_dmw1_rvalue),
    .csr_estat_rvalue (csr_estat_rvalue),
    .csr_crmd_rvalue  (csr_crmd_rvalue)
    
);

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_csr_re ? ws_csr_rvalue : ws_final_result;

endmodule
