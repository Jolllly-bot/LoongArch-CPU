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

localparam IDLE = 4'b0001;
localparam REQ = 4'b0010;
localparam RESP = 4'b0100;
localparam END = 4'b1000;


reg  [ 3:0] r_state;
reg  [ 3:0] r_next_state;
reg         r_data_req;   // 0-inst 1-data
reg  [ 2:0] r_size;
reg  [31:0] r_addr;

reg  [ 3:0] w_state; 
reg  [ 3:0] w_next_state;
reg         w_data_req;   // 0-inst 1-data
reg  [ 2:0] w_size;
reg  [31:0] w_addr;
reg  [31:0] w_data;
reg  [ 3:0] w_strb;

reg  [31:0]	data_sram_rdata_r;
reg  [31:0]	inst_sram_rdata_r;

reg         r_wait_w;
reg         w_wait_r;
reg         arvalid_r;
reg         awvalid_r;
reg         wvalid_r;

always @(posedge aclk) begin
    if(!aresetn)begin
       r_state <= IDLE;
       w_state <= IDLE;
    end   
    else begin
       r_state <= r_next_state;
       w_state <= w_next_state;
    end
end

always@(*)begin
    case(r_state)
        IDLE:begin
            if((data_sram_req && !data_sram_wr) || (inst_sram_req && !inst_sram_wr))
                r_next_state = REQ;
            else
                r_next_state = IDLE;
        end 
        REQ:begin
            if(arvalid && arready)
                r_next_state = RESP;
            else
                r_next_state = REQ;
        end
        RESP:begin
            if (rvalid)
                r_next_state = END;
            else
                r_next_state = RESP;
        end
        END:begin
            if((r_data_req != w_data_req ) || (w_state != END))
                r_next_state = IDLE;
            else
                r_next_state = END;
        end
        default:
            r_next_state = IDLE;
    endcase
end


always @(posedge aclk) begin
    if(!aresetn) 
        r_data_req      <= 1'b0;
    else if((r_state == IDLE) && (data_sram_req && !data_sram_wr))
        r_data_req      <=  1'b1;
    else if((r_state == IDLE) && (inst_sram_req && !inst_sram_wr))
        r_data_req      <=  1'b0;   
end

always @(posedge aclk) begin
    if(!aresetn) 
        r_size      <= 3'd0;
    else if((r_state == REQ)&&(r_data_req && data_sram_addr_ok && !arvalid_r))
        r_size      <= data_sram_size;
    else if((r_state == REQ)&&(!r_data_req && inst_sram_addr_ok && !arvalid_r))
        r_size      <= inst_sram_size;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        r_addr      <= 32'd0;
    else if((r_state == REQ)&&(r_data_req && data_sram_addr_ok && !arvalid_r))
        r_addr      <= data_sram_addr;
    else if((r_state == REQ)&&(!r_data_req && inst_sram_addr_ok && !arvalid_r))
        r_addr      <= inst_sram_addr;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        arvalid_r  <= 1'd0;
    else if((r_state == REQ)&&((data_sram_req && !data_sram_wr)||(inst_sram_req && !inst_sram_wr))&& !arvalid_r)
        arvalid_r  <= 1'b1;
    else if((r_state == REQ)&&(arvalid && arready))
        arvalid_r  <= 1'b0;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        r_wait_w    <= 1'd0;
    else if((r_state == REQ)&&((data_sram_req && !data_sram_wr)||(inst_sram_req && !inst_sram_wr))&& !arvalid_r)
        r_wait_w    <= (w_state==REQ||w_state==RESP);
    else if((r_state == REQ)&& r_wait_w)
        r_wait_w    <= (w_state==REQ||w_state==RESP);
end 

always @(posedge aclk) begin
    if(!aresetn) 
        inst_sram_rdata_r   <= 32'd0;
    else if((r_state == RESP)&&(rvalid && !r_data_req))
        inst_sram_rdata_r   <= rdata;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        data_sram_rdata_r   <= 32'd0;
    else if((r_state == RESP)&&(rvalid && r_data_req))
        data_sram_rdata_r   <= rdata;
end 

assign inst_sram_rdata = inst_sram_rdata_r;
assign data_sram_rdata = data_sram_rdata_r;


/* write */
always@(*)begin
    case(w_state)
        IDLE:begin
            if((data_sram_req && data_sram_wr) || (inst_sram_req && inst_sram_wr))
                w_next_state = REQ;
            else
                w_next_state = IDLE;
        end 
        REQ:begin
            if((awvalid && awready && wvalid && wready) || (awvalid && awready && !wvalid) || (wvalid && wready && !awvalid))
                w_next_state = RESP;
            else
                w_next_state = REQ;
        end
        RESP:begin
            if (bvalid)
                w_next_state = END;
            else
                w_next_state = RESP;
        end
        END:begin
            w_next_state = IDLE;
        end
        default:
            w_next_state = IDLE;
    endcase
end


always @(posedge aclk) begin
    if(!aresetn) 
        w_data_req <= 1'b0;
    else if((w_state == IDLE) && (data_sram_req && data_sram_wr))
        w_data_req <= 1'b1;
    else if((w_state == IDLE) && (inst_sram_req && inst_sram_wr))
        w_data_req <= 1'b0;
end

always @(posedge aclk) begin
    if(!aresetn) 
        awvalid_r <= 1'd0;
    else if((w_state == REQ) && (!awvalid_r && !wvalid_r) && ((w_data_req && data_sram_addr_ok) || (!w_data_req && inst_sram_addr_ok)))
        awvalid_r <= 1'd1;
    else if((w_state == REQ) && (awvalid && awready))
        awvalid_r <= 1'd0;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        wvalid_r <= 1'd0;
    else if((w_state == REQ) && (!awvalid_r && !wvalid_r) && ((w_data_req && data_sram_addr_ok) || (!w_data_req && inst_sram_addr_ok)))
        wvalid_r <= 1'd1;
    else if((w_state == REQ) && (wvalid && wready))
        wvalid_r <= 1'd0;
end

always @(posedge aclk) begin
    if(!aresetn) 
        w_size <= 3'd0;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (w_data_req && data_sram_addr_ok))
        w_size <= data_sram_size;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (!w_data_req && inst_sram_addr_ok))
        w_size <= inst_sram_size;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        w_addr <= 32'd0;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (w_data_req && data_sram_addr_ok))
        w_addr <= data_sram_addr;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (!w_data_req && inst_sram_addr_ok))
        w_addr <= inst_sram_addr;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        w_strb <= 4'd0;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (w_data_req && data_sram_addr_ok))
        w_strb <= data_sram_wstrb;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (!w_data_req && inst_sram_addr_ok))
        w_strb <= inst_sram_wstrb;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        w_data <= 32'd0;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (w_data_req && data_sram_addr_ok))
        w_data <= data_sram_wdata;
    else if((w_state == REQ)&& (!awvalid_r && !wvalid_r) && (!w_data_req && inst_sram_addr_ok))
        w_data <= inst_sram_wdata;
end 

always @(posedge aclk) begin
    if(!aresetn) 
        w_wait_r <= 1'd0;
    else if((w_state == REQ) && (!awvalid_r && !wvalid_r) && ((w_data_req && data_sram_addr_ok)||(!w_data_req && inst_sram_addr_ok)))
        w_wait_r <= (r_state==REQ || r_state==RESP);
    else if((w_state == REQ) && w_wait_r)
        w_wait_r <= (r_state==REQ || r_state==RESP);
end 

assign inst_sram_addr_ok = (!r_wait_w) && (r_state == REQ && !r_data_req && !arvalid)
                        || (w_state == REQ && !w_data_req && !awvalid && !wvalid);

assign inst_sram_data_ok = (r_state == END && !r_data_req) 
                        || (w_state == END && !w_data_req);

assign data_sram_addr_ok = (!r_wait_w) && (r_state == REQ && r_data_req  && !arvalid)
                        || (w_state == REQ && w_data_req  && !awvalid && !wvalid);

assign data_sram_data_ok = (r_state == END && r_data_req)
                        || (w_state == END && w_data_req);

assign araddr  = r_addr;
assign arsize  = {1'b0, r_size[2] ? 2'b10 : r_size[1:0]};
assign arvalid = arvalid_r && !r_wait_w;
assign rready  = r_state == RESP;

assign awaddr  = w_addr;
assign awsize  = {1'b0, w_size[2] ? 2'b10 : w_size[1:0]};
assign wdata   = w_data;
assign awvalid = awvalid_r && !w_wait_r;
assign wvalid  = wvalid_r  && !w_wait_r;
assign bready  = w_state == RESP;

assign arid    = (r_state == REQ)&&(r_data_req==1'b1) ;
assign rid     = (r_state == REQ)&&(r_data_req==1'b1) ;
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
assign wlast   = 1'b1 ;
assign wstrb   = w_strb;


endmodule