`timescale 1ns / 1ps

`define DEF_MAC_ADDR	48
`define DEF_VLAN		32
`define DEF_ETHTYPE		16

`define TYPE_IPV4		16'h0008
`define TYPE_ARP		16'h0608

`define PROT_ICMP		8'h01
`define PROT_TCP		8'h06
`define PROT_UDP		8'h11

`define SUB_PARSE(idx) \
	case(sub_parse_val_out_type[idx]) \
		2'b01: val_2B[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][15:0]; \
		2'b10: val_4B[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][31:0]; \
		2'b11: val_6B[sub_parse_val_out_seq[idx]] = sub_parse_val_out[idx][47:0]; \
	endcase \

`define SWAP_BYTE_ORDER(idx) \
	assign val_6B_swapped[idx] = {	val_6B[idx][0+:8], \
									val_6B[idx][8+:8], \
									val_6B[idx][16+:8], \
									val_6B[idx][24+:8], \
									val_6B[idx][32+:8], \
									val_6B[idx][40+:8]}; \
	assign val_4B_swapped[idx] = {	val_4B[idx][0+:8], \
									val_4B[idx][8+:8], \
									val_4B[idx][16+:8], \
									val_4B[idx][24+:8]}; \
	assign val_2B_swapped[idx] = {	val_2B[idx][0+:8], \
									val_2B[idx][8+:8]}; \

module parser #(
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter PKT_HDR_LEN = (6+4+2)*8*8+20*5+256, // check with the doc
	parameter PARSE_ACT_RAM_WIDTH = 167,
	parameter PARSER_MOD_ID = 3'b0
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
	output reg [PKT_HDR_LEN-1:0]			pkt_hdr_vec,

	// ctrl path
	input [C_S_AXIS_DATA_WIDTH-1:0]			ctrl_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		ctrl_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		ctrl_s_axis_tkeep,
	input									ctrl_s_axis_tvalid,
	input									ctrl_s_axis_tlast,

	output reg [C_S_AXIS_DATA_WIDTH-1:0]	ctrl_m_axis_tdata,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]	ctrl_m_axis_tuser,
	output reg [C_S_AXIS_DATA_WIDTH/8-1:0]	ctrl_m_axis_tkeep,
	output reg								ctrl_m_axis_tvalid,
	output reg								ctrl_m_axis_tlast
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
// 
always @(posedge axis_clk) begin
	if (~aresetn) begin
		if_last_d1 <= 0;
	end
	else begin
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
	else if (pkt_cnt > C_VALID_NUM_HDR_PKTS) begin
		pkt_cnt <= pkt_cnt;
	end
	else if (s_axis_tvalid) begin
		pkt_cnt <= pkt_cnt+1;
	end
end

// hdr_window, #pkt_cnt 
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



localparam WAIT_FOR_PKTS=0, START_PARSING=1;
localparam WAIT_BRAM_OUT_1=2, BEGIN_SUB_PARSE=3, FINISH_SUB_PARSE=4;
wire [259:0] bram_out;
reg [3:0] state, state_next;

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

reg [9:0] sub_parse_act_valid;
reg [15:0] sub_parse_act [0:9];
wire [47:0] sub_parse_val_out [0:9];
wire [9:0] sub_parse_val_out_valid;
wire [1:0] sub_parse_val_out_type [0:9];
wire [2:0] sub_parse_val_out_seq [0:9];

reg [47:0] val_6B [0:7];
reg [31:0] val_4B [0:7];
reg [15:0] val_2B [0:7];

wire [47:0] val_6B_swapped [0:7];
wire [31:0] val_4B_swapped [0:7];
wire [15:0] val_2B_swapped [0:7];

`SWAP_BYTE_ORDER(0)
`SWAP_BYTE_ORDER(1)
`SWAP_BYTE_ORDER(2)
`SWAP_BYTE_ORDER(3)
`SWAP_BYTE_ORDER(4)
`SWAP_BYTE_ORDER(5)
`SWAP_BYTE_ORDER(6)
`SWAP_BYTE_ORDER(7)

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
	// 
	sub_parse_act_valid = 10'b0;

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
			//
			vlan_id = w_pkts[116+:12];
	
			state_next = WAIT_BRAM_OUT_1;
		end
		WAIT_BRAM_OUT_1: begin
			// empty cycle
			state_next = BEGIN_SUB_PARSE;
		end
		BEGIN_SUB_PARSE: begin

			sub_parse_act_valid = 10'b1111111111;

			sub_parse_act[0] = parse_action[0];
			sub_parse_act[1] = parse_action[1];
			sub_parse_act[2] = parse_action[2];
			sub_parse_act[3] = parse_action[3];
			sub_parse_act[4] = parse_action[4];
			sub_parse_act[5] = parse_action[5];
			sub_parse_act[6] = parse_action[6];
			sub_parse_act[7] = parse_action[7];
			sub_parse_act[8] = parse_action[8];
			sub_parse_act[9] = parse_action[9];

			state_next = FINISH_SUB_PARSE;
		end
		FINISH_SUB_PARSE: begin
			parser_valid_r = 1;
			state_next = WAIT_FOR_PKTS;

			`SUB_PARSE(0)
			`SUB_PARSE(1)
			`SUB_PARSE(2)
			`SUB_PARSE(3)
			`SUB_PARSE(4)
			`SUB_PARSE(5)
			`SUB_PARSE(6)
			`SUB_PARSE(7)
			`SUB_PARSE(8)
			`SUB_PARSE(9)

			// Tao: manually set output port to 1 for eazy test
			pkt_hdr_vec_r ={val_6B_swapped[7], val_6B_swapped[6], val_6B_swapped[5], val_6B_swapped[4], val_6B_swapped[3], val_6B_swapped[2], val_6B_swapped[1], val_6B_swapped[0],
							val_4B_swapped[7], val_4B_swapped[6], val_4B_swapped[5], val_4B_swapped[4], val_4B_swapped[3], val_4B_swapped[2], val_4B_swapped[1], val_4B_swapped[0],
							val_2B_swapped[7], val_2B_swapped[6], val_2B_swapped[5], val_2B_swapped[4], val_2B_swapped[3], val_2B_swapped[2], val_2B_swapped[1], val_2B_swapped[0],
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
generate
	genvar index;
	for (index=0; index<10; index=index+1) begin:
		sub_op
		sub_parser #(
			.PKTS_HDR_LEN(),
			.PARSE_ACT_LEN(),
			.VAL_OUT_LEN()
		)
		sub_parser (
			.clk				(axis_clk),
			.aresetn			(aresetn),

			.parse_act_valid	(sub_parse_act_valid[index]),
			.parse_act			(sub_parse_act[index]),

			.pkts_hdr			(w_pkts),
			.val_out_valid		(sub_parse_val_out_valid[index]),
			.val_out			(sub_parse_val_out[index]),
			.val_out_type		(sub_parse_val_out_type[index]),
			.val_out_seq		(sub_parse_val_out_seq[index])
		);
	end
endgenerate

/*================Control Path====================*/
reg [C_S_AXIS_DATA_WIDTH-1:0]	ctrl_m_axis_tdata_next;
reg [C_S_AXIS_TUSER_WIDTH-1:0]	ctrl_m_axis_tuser_next;
reg [C_S_AXIS_DATA_WIDTH/8-1:0]	ctrl_m_axis_tkeep_next;
reg								ctrl_m_axis_tlast_next;
reg								ctrl_m_axis_tvalid_next;

wire [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_swapped;

assign ctrl_s_axis_tdata_swapped = {	ctrl_s_axis_tdata[0+:8],
										ctrl_s_axis_tdata[8+:8],
										ctrl_s_axis_tdata[16+:8],
										ctrl_s_axis_tdata[24+:8],
										ctrl_s_axis_tdata[32+:8],
										ctrl_s_axis_tdata[40+:8],
										ctrl_s_axis_tdata[48+:8],
										ctrl_s_axis_tdata[56+:8],
										ctrl_s_axis_tdata[64+:8],
										ctrl_s_axis_tdata[72+:8],
										ctrl_s_axis_tdata[80+:8],
										ctrl_s_axis_tdata[88+:8],
										ctrl_s_axis_tdata[96+:8],
										ctrl_s_axis_tdata[104+:8],
										ctrl_s_axis_tdata[112+:8],
										ctrl_s_axis_tdata[120+:8],
										ctrl_s_axis_tdata[128+:8],
										ctrl_s_axis_tdata[136+:8],
										ctrl_s_axis_tdata[144+:8],
										ctrl_s_axis_tdata[152+:8],
										ctrl_s_axis_tdata[160+:8],
										ctrl_s_axis_tdata[168+:8],
										ctrl_s_axis_tdata[176+:8],
										ctrl_s_axis_tdata[184+:8],
										ctrl_s_axis_tdata[192+:8],
										ctrl_s_axis_tdata[200+:8],
										ctrl_s_axis_tdata[208+:8],
										ctrl_s_axis_tdata[216+:8],
										ctrl_s_axis_tdata[224+:8],
										ctrl_s_axis_tdata[232+:8],
										ctrl_s_axis_tdata[240+:8],
										ctrl_s_axis_tdata[248+:8]};


reg	[7:0]						ctrl_wr_ram_addr, ctrl_wr_ram_addr_next;
reg	[259:0]						ctrl_wr_ram_data, ctrl_wr_ram_data_next;
reg								ctrl_wr_ram_en;
wire [7:0]						ctrl_mod_id;

assign ctrl_mod_id = ctrl_s_axis_tdata[112+:8];

localparam	WAIT_FIRST_PKT = 0,
			WAIT_SECOND_PKT = 1,
			WAIT_THIRD_PKT = 2,
			WRITE_RAM = 3,
			FLUSH_REST_C = 4;

reg [2:0] ctrl_state, ctrl_state_next;

always @(*) begin
	ctrl_m_axis_tdata_next = ctrl_s_axis_tdata;
	ctrl_m_axis_tuser_next = ctrl_s_axis_tuser;
	ctrl_m_axis_tkeep_next = ctrl_s_axis_tkeep;
	ctrl_m_axis_tlast_next = ctrl_s_axis_tlast;
	ctrl_m_axis_tvalid_next = ctrl_s_axis_tvalid;

	ctrl_state_next = ctrl_state;
	ctrl_wr_ram_en = 0;

	case (ctrl_state)
		WAIT_FIRST_PKT: begin
			// 1st ctrl packet
			if (ctrl_s_axis_tvalid) begin
				ctrl_state_next = WAIT_SECOND_PKT;
			end
		end
		WAIT_SECOND_PKT: begin
			// 2nd ctrl packet, we can check module ID
			if (ctrl_s_axis_tvalid) begin
				if (ctrl_mod_id[2:0]==PARSER_MOD_ID) begin
					ctrl_state_next = WAIT_THIRD_PKT;

					ctrl_wr_ram_addr = ctrl_s_axis_tdata[128+:8];
				end
				else begin
					ctrl_state_next = FLUSH_REST_C;
				end
			end
		end
		WAIT_THIRD_PKT: begin // first half of ctrl_wr_ram_data
			if (ctrl_s_axis_tvalid) begin
				ctrl_state_next = WRITE_RAM;
				ctrl_wr_ram_data[259:4] = ctrl_s_axis_tdata_swapped[255:0];
			end
		end
		WRITE_RAM: begin // second half of ctrl_wr_ram_data
			if (ctrl_s_axis_tvalid) begin
				if (ctrl_s_axis_tlast) 
					ctrl_state_next = WAIT_FIRST_PKT;
				else
					ctrl_state_next = FLUSH_REST_C;
				ctrl_wr_ram_en = 1;
				ctrl_wr_ram_data[3:0] = ctrl_s_axis_tdata_swapped[255:252];
			end
		end
		FLUSH_REST_C: begin
			if (ctrl_s_axis_tvalid && ctrl_s_axis_tlast)
				ctrl_state_next = WAIT_FIRST_PKT;
		end
	endcase
end

always @(posedge axis_clk) begin
	if (~aresetn) begin
		//
		ctrl_state <= WAIT_FIRST_PKT;

		ctrl_m_axis_tdata <= 0;
		ctrl_m_axis_tuser <= 0;
		ctrl_m_axis_tkeep <= 0;
		ctrl_m_axis_tvalid <= 0;
		ctrl_m_axis_tlast <= 0;
	end
	else begin
		ctrl_state <= ctrl_state_next;

		ctrl_m_axis_tdata <= ctrl_m_axis_tdata_next;
		ctrl_m_axis_tuser <= ctrl_m_axis_tuser_next;
		ctrl_m_axis_tkeep <= ctrl_m_axis_tkeep_next;
		ctrl_m_axis_tlast <= ctrl_m_axis_tlast_next;
		ctrl_m_axis_tvalid <= ctrl_m_axis_tvalid_next;
	end
end

// =============================================================== //
// parse_act_ram_ip #(
// 	.C_INIT_FILE_NAME	("./parse_act_ram_init_file.mif"),
// 	.C_LOAD_INIT_FILE	(1)
// )
parse_act_ram_ip
parse_act_ram
(
	// write port
	.clka		(axis_clk),
	.addra		(ctrl_wr_ram_addr[3:0]),
	.dina		(ctrl_wr_ram_data),
	.ena		(1'b1),
	.wea		(ctrl_wr_ram_en),

	//
	.clkb		(axis_clk),
	.addrb		(vlan_id[7:4]), // TODO: note that we may change due to little or big endian
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);

endmodule
