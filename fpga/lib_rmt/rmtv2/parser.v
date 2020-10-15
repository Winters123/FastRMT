
`timescale 1ns / 1ps
module parser #(
    //for 100g MAC, the AXIS width is 512b
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter PKT_HDR_LEN = (6+4+2)*8*8+20*5+256, // check with the doc
	parameter PARSE_ACT_RAM_WIDTH = 167
    )(
    input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		s_axis_tkeep,
	input									s_axis_tvalid,
	input									s_axis_tlast,

	// output
	output   								phv_valid_out,
	output      [PKT_HDR_LEN-1:0]			phv_out
);

// intermediate variables declared here

//phv_out signals before putting out.
reg phv_valid_out_reg;

assign phv_valid_out = phv_valid_out_reg;

wire [11:0] vlan_id;

//Parse Action RAM
wire [259:0] bram_out;

wire [15:0]  parse_action [0:9];
wire [19:0]  condi_action [0:4];

reg [47:0] val_6B [0:7];
reg [31:0] val_4B [0:7];
reg [15:0] val_2B [0:7];

integer idx;
localparam SEG_NUM = 1024/C_S_AXIS_DATA_WIDTH;
//reg [C_S_AXIS_DATA_WIDTH-1:0]  pkt_seg [0:(1024/C_S_AXIS_DATA_WIDTH-1)];

// reg [SEG_NUM-1:0] pkt_seg_cnt;
reg [3:0]    pkt_seg_cnt; //cnt is 4'd6 if its invalid
reg          s_axis_tvalid_before;
reg          phv_ready;

reg [1023:0] pkt_hdr_field;

//get vlan_id from 1st segment.
assign vlan_id = s_axis_tdata[116 +: 12];

assign parse_action[9] = bram_out[100+:16];
assign parse_action[8] = bram_out[116+:16];
assign parse_action[7] = bram_out[132+:16];
assign parse_action[6] = bram_out[148+:16];
assign parse_action[5] = bram_out[164+:16];
assign parse_action[4] = bram_out[180+:16];
assign parse_action[3] = bram_out[196+:16];
assign parse_action[2] = bram_out[212+:16];
assign parse_action[1] = bram_out[228+:16];
assign parse_action[0] = bram_out[244+:16];

assign condi_action[0] = bram_out[0+:20];
assign condi_action[1] = bram_out[20+:20];
assign condi_action[2] = bram_out[40+:20];
assign condi_action[3] = bram_out[60+:20];
assign condi_action[4] = bram_out[80+:20];

/**** here we parse everything (8 containers & 5 conditions) ****/

always @(posedge axis_clk) begin
    s_axis_tvalid_before <= s_axis_tvalid;
end

//a counter to determine if this value needs to be recorded
always @(posedge axis_clk) begin
    //1st segment
    if(s_axis_tvalid && ~s_axis_tvalid_before) begin
        pkt_seg_cnt <= 4'd0;
    end
    //left but not 1st segment (within SEG_NUM)
    else if(s_axis_tvalid) begin
        pkt_seg_cnt <= pkt_seg_cnt + 4'b1;
    end
    else begin
        pkt_seg_cnt <= pkt_seg_cnt;
    end
end

//record the pkts into pkt_hdr_field
always @(posedge axis_clk or negedge aresetn) begin
    if(~aresetn) begin
        pkt_hdr_field <= 1024'b0;
    end
    else begin
        //the 1st segment of the packet
        if(s_axis_tvalid && ~s_axis_tvalid_before) begin
            phv_ready <= 1'b0;
            pkt_hdr_field <= s_axis_tdata<<(1024-C_S_AXIS_DATA_WIDTH);     
        end
        else if(pkt_seg_cnt < SEG_NUM-1 && s_axis_tvalid) begin
            pkt_hdr_field[1024-1-C_S_AXIS_DATA_WIDTH*(pkt_seg_cnt+1) -: C_S_AXIS_DATA_WIDTH] <= s_axis_tdata;   
            //here we can start extract values from PHV
            if(pkt_seg_cnt == SEG_NUM-2 || s_axis_tlast) begin
                phv_ready <= 1'b1;
            end
        end
        else begin
            pkt_hdr_field <= pkt_hdr_field;
        end
    end
end


//here we extract the 1024b from packet (depend on data_width)
reg [2:0] parse_state;
localparam IDLE_S   = 3'd0,
           WAIT1_S  = 3'd1,
           WAIT2_S  = 3'd2,
           PHVGEN_S = 3'd3;

//fire up the FSM
always @(posedge axis_clk or negedge aresetn) begin
    if(~aresetn) begin
        phv_valid_out_reg <= 1'b0;
        //phv_out <= 1024'b0;
        parse_state <= IDLE_S;
    end
    else begin
        case(parse_state)
            IDLE_S: begin
                if(s_axis_tvalid && ~s_axis_tvalid_before) begin
                    parse_state <= WAIT1_S;
                end
                phv_valid_out_reg <= 1'b0;
                //phv_out<=1024'b0;
                for(idx = 0; idx < 8; idx = idx+1) begin
                    val_2B[idx] <= 16'b0;
                    val_4B[idx] <= 32'b0;
                    val_6B[idx] <= 48'b0;
                end
            end

            WAIT1_S: begin
                parse_state <= PHVGEN_S;
            end 

            WAIT2_S: begin
                parse_state <= PHVGEN_S;
            end

            PHVGEN_S: begin
                for (idx=0; idx<10; idx=idx+1) begin
				    if (parse_action[idx][0] == 1'b1) begin
				    	case(parse_action[idx][5:4])
				    		1 : begin
				    			case(parse_action[idx][3:1])
				    				0 : begin
				    					val_2B[0] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				1 : begin
				    					val_2B[1] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				2 : begin
				    					val_2B[2] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				3 : begin
				    					val_2B[3] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				4 : begin
				    					val_2B[4] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				5 : begin
				    					val_2B[5] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				6 : begin
				    					val_2B[6] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    				7 : begin
				    					val_2B[7] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:16];
				    				end
				    			endcase
				    		end
				    		2 : begin
				    			case(parse_action[idx][3:1])
				    				0 : begin
				    					val_4B[0] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				1 : begin
				    					val_4B[1] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				2 : begin
				    					val_4B[2] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				3 : begin
				    					val_4B[3] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				4 : begin
				    					val_4B[4] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				5 : begin
				    					val_4B[5] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				6 : begin
				    					val_4B[6] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    				7 : begin
				    					val_4B[7] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:32];
				    				end
				    			endcase
				    		end
				    		3 : begin
				    			case(parse_action[idx][3:1])
				    				0 : begin
				    					val_6B[0] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				1 : begin
				    					val_6B[1] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				2 : begin
				    					val_6B[2] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				3 : begin
				    					val_6B[3] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				4 : begin
				    					val_6B[4] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				5 : begin
				    					val_6B[5] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				6 : begin
				    					val_6B[6] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    				7 : begin
				    					val_6B[7] <= pkt_hdr_field[(parse_action[idx][12:6])*8 +:48];
				    				end
				    			endcase
				    		end
				    	endcase
				    end
			    end // end parsing actions
                phv_valid_out_reg <= 1'b1;
                // phv_out <= {val_6B[7], val_6B[6], val_6B[5], val_6B[4], val_6B[3], val_6B[2], val_6B[1], val_6B[0],
				// 			val_4B[7], val_4B[6], val_4B[5], val_4B[4], val_4B[3], val_4B[2], val_4B[1], val_4B[0],
				// 			val_2B[7], val_2B[6], val_2B[5], val_2B[4], val_2B[3], val_2B[2], val_2B[1], val_2B[0],
				// 			condi_action[0], condi_action[1], condi_action[2], condi_action[3], condi_action[4],
				// 			//{115{1'b0}}, vlan_id, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
                //             //corundum currently doesn't have metadata
                //             256'b0};
                parse_state <= IDLE_S;
            end
        endcase
    end
end

assign phv_out = {val_6B[7], val_6B[6], val_6B[5], val_6B[4], val_6B[3], val_6B[2], val_6B[1], val_6B[0],
				 val_4B[7], val_4B[6], val_4B[5], val_4B[4], val_4B[3], val_4B[2], val_4B[1], val_4B[0],
				 val_2B[7], val_2B[6], val_2B[5], val_2B[4], val_2B[3], val_2B[2], val_2B[1], val_2B[0],
				 condi_action[0], condi_action[1], condi_action[2], condi_action[3], condi_action[4],
                 256'b0};

// =============================================================== //
parse_act_ram_ip #(
	//.C_INIT_FILE_NAME	("./parse_act_ram_init_file.mif"),
	//.C_LOAD_INIT_FILE	(1)
)
parse_act_ram
(
	// write port
	.clka		(axis_clk),
	.addra		(),
	.dina		(),
	.ena		(),
	.wea		(),

	//
	.clkb		(axis_clk),
	.addrb		(vlan_id[7:4]), // TODO: note that we may change due to little or big endian
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);

endmodule
