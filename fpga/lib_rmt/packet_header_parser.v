`timescale 1ns / 1ps

`define DEF_MAC_ADDR	48
`define DEF_VLAN		32
`define DEF_ETHTYPE		16

`define TYPE_IPV4		16'h0008
`define TYPE_ARP		16'h0608

`define PROT_ICMP		8'h01
`define PROT_TCP		8'h06
`define PROT_UDP		8'h11


module packet_header_parser #(
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter PKT_HDR_LEN = (6+4+2)*8*8+20*5+256, // check with the doc
	parameter PARSE_ACT_RAM_WIDTH = 167
)
(
	input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		s_axis_tkeep,
	input									s_axis_tvalid,
	input									s_axis_tlast,

	// output
	output reg								parser_valid,
	output reg [PKT_HDR_LEN-1:0]			pkt_hdr_vec
);

reg		parser_valid_r;
reg [PKT_HDR_LEN-1:0]	pkt_hdr_vec_r;

/*
*
*/
integer idx;
localparam TOT_HDR_LEN = 1024;
localparam C_VALID_NUM_HDR_PKTS = 4;		// 4*32B = 128B = 1024b
wire [TOT_HDR_LEN-1:0] w_pkts;
reg [3:0] pkt_cnt;
reg [C_S_AXIS_DATA_WIDTH-1:0] pkts[0:C_VALID_NUM_HDR_PKTS-1];
reg [C_S_AXIS_TUSER_WIDTH-1:0] tuser_1st;

/****** store all or at-most 4 pkt segments ******/
reg if_last_d1; // indicate whether the last valid packet 
always @(posedge axis_clk) begin
	if (~aresetn) begin
		if_last_d1 <= 0;
	end
	else begin
		//1 if it is the last of the pkt segment.
		if_last_d1 <= s_axis_tvalid & s_axis_tlast;
	end
end

// update pkt_cnt;
always @(posedge axis_clk) begin
	if (~aresetn) begin
		pkt_cnt <= 0;
	end
	else if (if_last_d1) begin
		pkt_cnt <= 0;
	end
	//pkt_cnt can equal to 5 at most.
	else if (pkt_cnt > C_VALID_NUM_HDR_PKTS) begin
		pkt_cnt <= pkt_cnt;
	end
	else if (s_axis_tvalid) begin
		pkt_cnt <= pkt_cnt+1;
	end
end

// hdr_window, #pkt_cnt 
//window is zero if the current segment is above 4.
wire hdr_window = s_axis_tvalid && pkt_cnt<=C_VALID_NUM_HDR_PKTS;
// store into pkts
always @(posedge axis_clk) begin
	if (~aresetn) begin
		for (idx=0; idx<-C_VALID_NUM_HDR_PKTS; idx=idx+1) begin
			pkts[idx] <= 0;
		end

		tuser_1st <= 0;
	end
	else if (hdr_window && pkt_cnt==0) begin
		for (idx=0; idx<C_VALID_NUM_HDR_PKTS; idx=idx+1) begin
			pkts[idx] <= 0;
		end
		pkts[pkt_cnt] <= s_axis_tdata;
		tuser_1st <= s_axis_tuser;
	end
	else if (hdr_window) begin
		pkts[pkt_cnt] <= s_axis_tdata;
	end
end
/****** store all or at-most 4 pkt segments ******/

/****** parse ******/
// all the Ether, VLAN, IP, UDP headers are static
assign w_pkts = {pkts[3], pkts[2], pkts[1], pkts[0]};



localparam WAIT_FOR_PKTS=0, START_PARSING=1, WAIT_BRAM_OUT_1=2;
localparam STATE_PARSE_0=3, STATE_PARSE_0_16=4, STATE_PARSE_0_32=5, STATE_PARSE_0_48=6;
localparam STATE_PARSE_1=7, STATE_PARSE_1_16=8, STATE_PARSE_1_32=9, STATE_PARSE_1_48=10;
localparam STATE_PARSE_2=11, STATE_PARSE_2_16=12, STATE_PARSE_2_32=13, STATE_PARSE_2_48=14;
localparam STATE_PARSE_3=15, STATE_PARSE_3_16=16, STATE_PARSE_3_32=17, STATE_PARSE_3_48=18;
localparam STATE_PARSE_4=19, STATE_PARSE_4_16=20, STATE_PARSE_4_32=21, STATE_PARSE_4_48=22;
localparam STATE_PARSE_5=23, STATE_PARSE_5_16=24, STATE_PARSE_5_32=25, STATE_PARSE_5_48=26;
localparam STATE_PARSE_6=27, STATE_PARSE_6_16=28, STATE_PARSE_6_32=29, STATE_PARSE_6_48=30;
localparam STATE_PARSE_7=31, STATE_PARSE_7_16=32, STATE_PARSE_7_32=33, STATE_PARSE_7_48=34;
localparam STATE_PARSE_8=35, STATE_PARSE_8_16=36, STATE_PARSE_8_32=37, STATE_PARSE_8_48=38;
localparam STATE_PARSE_9=39, STATE_PARSE_9_16=40, STATE_PARSE_9_32=41, STATE_PARSE_9_48=42;
localparam WAIT_BRAM_OUT_2=43;
wire [259:0] bram_out;
reg [5:0] state, state_next;

// common headers
reg [11:0] vlan_id; // vlan id
reg [15:0] eth_type_r;
reg [7:0] ip_prot_r;
reg [15:0] eth_type;
reg [7:0] ip_prot;

// parsing actions
wire [15:0] parse_action [0:9];		// we have 10 parse action
wire [19:0] cond_action [0:4];		// we have 5 conditonal 

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

assign cond_action[0] = bram_out[0+:20];
assign cond_action[1] = bram_out[20+:20];
assign cond_action[2] = bram_out[40+:20];
assign cond_action[3] = bram_out[60+:20];
assign cond_action[4] = bram_out[80+:20];

reg [47:0] val_6B [0:7];
reg [31:0] val_4B [0:7];
reg [15:0] val_2B [0:7];

always@(*) begin
	state_next = state;
	parser_valid_r = 0;

	eth_type_r = eth_type;
	ip_prot_r = ip_prot;

	pkt_hdr_vec_r = pkt_hdr_vec;
	// zero out
	val_2B[0]=0;val_2B[1]=0;val_2B[2]=0;val_2B[3]=0;val_2B[4]=0;val_2B[5]=0;val_2B[6]=0;val_2B[7]=0;
	val_4B[0]=0;val_4B[1]=0;val_4B[2]=0;val_4B[3]=0;val_4B[4]=0;val_4B[5]=0;val_4B[6]=0;val_4B[7]=0;
	val_6B[0]=0;val_6B[1]=0;val_6B[2]=0;val_6B[3]=0;val_6B[4]=0;val_6B[5]=0;val_6B[6]=0;val_6B[7]=0;

	case (state) 
		WAIT_FOR_PKTS: begin
			if (if_last_d1||pkt_cnt>=C_VALID_NUM_HDR_PKTS) begin
				state_next = START_PARSING;
			end
		end
		START_PARSING: begin
			eth_type_r = w_pkts[128+:16]; // 144
			// 
			ip_prot_r = w_pkts[216+:8]; // 240
			
			//the time when addr is feeded
			vlan_id = w_pkts[116+:12];
	
			state_next = WAIT_BRAM_OUT_1;
		end
		WAIT_BRAM_OUT_1: begin
			// empty cycle
			state_next = WAIT_BRAM_OUT_2;
		end
		WAIT_BRAM_OUT_2: begin
			for (idx=0; idx<10; idx=idx+1) begin
				if (parse_action[idx][0] == 1'b1) begin
					case(parse_action[idx][5:4])
						1 : begin
							case(parse_action[idx][3:1])
								0 : begin
									val_2B[0] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								1 : begin
									val_2B[1] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								2 : begin
									val_2B[2] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								3 : begin
									val_2B[3] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								4 : begin
									val_2B[4] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								5 : begin
									val_2B[5] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								6 : begin
									val_2B[6] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
								7 : begin
									val_2B[7] = w_pkts[(parse_action[idx][12:6])*8 +:16];
								end
							endcase
						end
						2 : begin
							case(parse_action[idx][3:1])
								0 : begin
									val_4B[0] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								1 : begin
									val_4B[1] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								2 : begin
									val_4B[2] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								3 : begin
									val_4B[3] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								4 : begin
									val_4B[4] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								5 : begin
									val_4B[5] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								6 : begin
									val_4B[6] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
								7 : begin
									val_4B[7] = w_pkts[(parse_action[idx][12:6])*8 +:32];
								end
							endcase
						end
						3 : begin
							case(parse_action[idx][3:1])
								0 : begin
									val_6B[0] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								1 : begin
									val_6B[1] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								2 : begin
									val_6B[2] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								3 : begin
									val_6B[3] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								4 : begin
									val_6B[4] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								5 : begin
									val_6B[5] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								6 : begin
									val_6B[6] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
								7 : begin
									val_6B[7] = w_pkts[(parse_action[idx][12:6])*8 +:48];
								end
							endcase
						end
					endcase
				end
			end // end parsing actions


			state_next = WAIT_FOR_PKTS;
			parser_valid_r = 1;
			pkt_hdr_vec_r ={val_6B[7], val_6B[6], val_6B[5], val_6B[4], val_6B[3], val_6B[2], val_6B[1], val_6B[0],
							val_4B[7], val_4B[6], val_4B[5], val_4B[4], val_4B[3], val_4B[2], val_4B[1], val_4B[0],
							val_2B[7], val_2B[6], val_2B[5], val_2B[4], val_2B[3], val_2B[2], val_2B[1], val_2B[0],
							cond_action[0], cond_action[1], cond_action[2], cond_action[3], cond_action[4],
							{115{1'b0}}, vlan_id, 1'b0, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
							// {115{1'b0}}, vlan_id, 1'b0, tuser_1st};
							// {128{1'b0}}, tuser_1st[127:32], 8'h04, tuser_1st[23:0]};
		end
	endcase
end

always@(posedge axis_clk) begin
	if (~aresetn) begin
		state <= WAIT_FOR_PKTS;

		//
		eth_type <= 0;
		ip_prot <= 0;
		pkt_hdr_vec <= 0;
		parser_valid <= 0;
	end
	else begin
		state <= state_next;

		eth_type <= eth_type_r;
		ip_prot <= ip_prot_r;
		pkt_hdr_vec <= pkt_hdr_vec_r;
		// pkt_hdr_vec <= {1124{1'b0}};
		parser_valid <= parser_valid_r;
	end
end

// =============================================================== //
parse_act_ram_ip #(
	.C_INIT_FILE_NAME	("./parse_act_ram_init_file.mif"),
	.C_LOAD_INIT_FILE	(1)
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
