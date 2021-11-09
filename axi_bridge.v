module axi_bridge(
    input            aclk,
    input            aresetn,
    //master: read request
    output  [ 3:0]   arid,
    output  [31:0]   araddr,
    output  [ 7:0]   arlen,
    output  [ 2:0]   arsize,
    output  [ 1:0]   arburst,
    output  [ 1:0]   arlock,
    output  [ 3:0]   arcache,
    output  [ 2:0]   arprot,
    output           arvalid,
    input            arready,
    //master: read response
    input   [ 3:0]   rid,
    input   [31:0]   rdata,
    input   [ 1:0]   rresp,
    input            rlast,
    input            rvalid,
    output           rready,
    //master: write request
    output  [ 3:0]   awid,
    output  [31:0]   awaddr,
    output  [ 7:0]   awlen,
    output  [ 2:0]   awsize,
    output  [ 1:0]   awburst,
    output  [ 1:0]   awlock,
    output  [ 3:0]   awcache,
    output  [ 2:0]   awprot,
    output           awvalid,
    input            awready,
    //master: write data
    output  [ 3:0]   wid,
    output  [31:0]   wdata,
    output  [ 3:0]   wstrb,
    output           wlast,
    output           wvalid,
    input            wready,
    //master write response
    input   [ 3:0]   bid,
    input   [ 1:0]   bresp,
    input            bvalid,
    output           bready,
    //slave: inst sram
    input            inst_sram_req,
    input            inst_sram_wr,
    input   [ 1:0]   inst_sram_size,
    input   [31:0]   inst_sram_addr,
    input   [ 3:0]   inst_sram_wstrb,
    input   [31:0]   inst_sram_wdata,
    output           inst_sram_addr_ok,
    output           inst_sram_data_ok,
    output  [31:0]   inst_sram_rdata,
    //slave: data sram
    input            data_sram_req,
    input            data_sram_wr,
    input   [ 1:0]   data_sram_size,
    input   [31:0]   data_sram_addr,
    input   [31:0]   data_sram_wdata,
    input   [ 3:0]   data_sram_wstrb,
    output           data_sram_addr_ok,
    output           data_sram_data_ok,
    output  [31:0]   data_sram_rdata
);

parameter ARID_INST = 4'h0;
parameter ARID_DATA = 4'h1;

assign arlen   = 8'd0 ;
assign arburst = 2'b01;
assign arlock  = 2'd0 ;
assign arcache = 4'd0 ;
assign arprot  = 3'd0 ;

assign awid    = 4'd1 ;
assign awlen   = 8'd0 ;
assign awburst = 2'b01;
assign awlock  = 2'd0 ;
assign awcache = 4'd0 ;
assign awprot  = 3'd0 ;

assign wid     = 4'd1 ;
assign wlast   = 1'd1 ;

endmodule