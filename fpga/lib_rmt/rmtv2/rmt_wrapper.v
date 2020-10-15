`timescale 1ns / 1ps

`define STATE_REASS_IDX_BITSIZE(idx, bit_size, ed_state, bytes) \
	STATE_REASS_``idx``_``bit_size: begin \
		case(parse_action[idx][3:1]) \
			0 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*0)+:(bit_size)]; \
			end \
			1 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*1)+:(bit_size)]; \
			end \
			2 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*2)+:(bit_size)]; \
			end \
			3 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*3)+:(bit_size)]; \
			end \
			4 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*4)+:(bit_size)]; \
			end \
			5 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*5)+:(bit_size)]; \
			end \
			6 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*6)+:(bit_size)]; \
			end \
			7 : begin \
				pkts_tdata_stored_r[(parse_action_ind[(idx)])*8 +:(bit_size)] = phv_fifo_out_w[(PHV_``bytes``B_START_POS+(bit_size)*7)+:(bit_size)]; \
			end \
			default : begin \
			end \
		endcase \
		state_next = (ed_state); \
	end \

`define STATE_REASSEMBLE_DATA(idx, ed_state) \
	REASSEMBLE_DATA_``idx: begin \
		if (parse_action[(idx)][0] == 1'b1) begin \
			case(parse_action[(idx)][5:4]) \
				1 : begin \
					state_next = STATE_REASS_``idx``_16; \
				end \
				2 : begin \
					state_next = STATE_REASS_``idx``_32; \
				end \
				3 : begin \
					state_next = STATE_REASS_``idx``_48; \
				end \
				default : begin \
				end \
			endcase \
		end \
		else begin \
			state_next = (ed_state); \
		end \
	end \

module rmt_wrapper #(
	// Slave AXI parameters
	parameter C_S_AXI_DATA_WIDTH = 32,
	parameter C_S_AXI_ADDR_WIDTH = 12,
	parameter C_BASEADDR = 32'h80000000,
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	parameter C_M_AXIS_DATA_WIDTH = 256,
	// self-defined
	parameter PHV_ADDR_WIDTH = 4
)
(
	input									clk,		// axis clk
	input									aresetn,	

	// input Slave AXI Stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]	s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input									s_axis_tvalid,
	output									s_axis_tready,
	input									s_axis_tlast,

	// output Master AXI Stream
	output reg [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output reg									m_axis_tvalid,
	input										m_axis_tready,
	output reg									m_axis_tlast
	
);

integer idx;

/*=================================================*/
localparam PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256;
//the number of cycles for a PHV
localparam SEG_NUM = 1024/C_S_AXIS_DATA_WIDTH;
// pkt fifo
reg									pkt_fifo_rd_en;
wire								pkt_fifo_nearly_full;
wire								pkt_fifo_empty;
wire [C_S_AXIS_DATA_WIDTH-1:0]		tdata_fifo;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		tuser_fifo;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]	tkeep_fifo;
wire								tlast_fifo;
// phv fifo
reg									phv_fifo_rd_en;
wire								phv_fifo_nearly_full;
wire								phv_fifo_empty;
wire [PKT_VEC_WIDTH-1:0]			phv_fifo_in;
wire [PKT_VEC_WIDTH-1:0]			phv_fifo_out_w;
wire								phv_valid;
// 
wire								stg0_phv_in_valid;
wire								stg0_phv_in_valid_w;
reg									stg0_phv_in_valid_r;
wire [PKT_VEC_WIDTH-1:0]			stg0_phv_in;
// stage-related
wire [PKT_VEC_WIDTH-1:0]			stg0_phv_out;
wire								stg0_phv_out_valid;
wire								stg0_phv_out_valid_w;
reg									stg0_phv_out_valid_r;
wire [PKT_VEC_WIDTH-1:0]			stg1_phv_out;
wire								stg1_phv_out_valid;
wire								stg1_phv_out_valid_w;
reg									stg1_phv_out_valid_r;
wire [PKT_VEC_WIDTH-1:0]			stg2_phv_out;
wire								stg2_phv_out_valid;
wire								stg2_phv_out_valid_w;
reg									stg2_phv_out_valid_r;
wire [PKT_VEC_WIDTH-1:0]			stg3_phv_out;
wire								stg3_phv_out_valid;
wire								stg3_phv_out_valid_w;
reg									stg3_phv_out_valid_r;
wire [PKT_VEC_WIDTH-1:0]			stg4_phv_out;
wire								stg4_phv_out_valid;
wire								stg4_phv_out_valid_w;
reg									stg4_phv_out_valid_r;
/*=================================================*/
assign s_axis_tready = !pkt_fifo_nearly_full;

// fallthrough_small_fifo #(
// 	.WIDTH(C_S_AXIS_DATA_WIDTH + C_S_AXIS_TUSER_WIDTH + C_S_AXIS_DATA_WIDTH/8 + 1),
// 	.MAX_DEPTH_BITS(8)
// )
// pkt_fifo
// (
// 	.din									({s_axis_tdata, s_axis_tuser, s_axis_tkeep, s_axis_tlast}),
// 	.wr_en									(s_axis_tvalid & ~pkt_fifo_nearly_full),
// 	.rd_en									(pkt_fifo_rd_en),
// 	.dout									({tdata_fifo, tuser_fifo, tkeep_fifo, tlast_fifo}),
// 	.full									(),
// 	.prog_full								(),
// 	.nearly_full							(pkt_fifo_nearly_full),
// 	.empty									(pkt_fifo_empty),
// 	.reset									(~aresetn),
// 	.clk									(clk)
// );

fifo_generator_705b pkt_fifo (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din({s_axis_tdata, s_axis_tuser, s_axis_tkeep, s_axis_tlast}),                  // input wire [704 : 0] din
  .wr_en(s_axis_tvalid & ~pkt_fifo_nearly_full),              // input wire wr_en
  .rd_en(pkt_fifo_rd_en),              // input wire rd_en
  .dout({tdata_fifo, tuser_fifo, tkeep_fifo, tlast_fifo}),                // output wire [704 : 0] dout
  .full(pkt_fifo_nearly_full),                // output wire full
  .empty(pkt_fifo_empty),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);

// fallthrough_small_fifo #(
// 	.WIDTH(PKT_VEC_WIDTH),
// 	.MAX_DEPTH_BITS(8)
// )
// phv_fifo
// (
// 	// .din			(phv_fifo_in),
// 	// .wr_en			(phv_valid),
// 	// .din			(stg4_phv_out),
// 	// .wr_en			(stg4_phv_out_valid_w),
// 	.din			(stg0_phv_out),
// 	.wr_en			(stg0_phv_out_valid_w),
// 	.rd_en			(phv_fifo_rd_en),
// 	.dout			(phv_fifo_out_w),

// 	.full			(),
// 	.prog_full		(),
// 	.nearly_full	(phv_fifo_nearly_full),
// 	.empty			(phv_fifo_empty),
// 	.reset			(~aresetn),
// 	.clk			(clk)
// );

fifo_generator_512b phv_fifo_1 (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din(stg0_phv_out[511:0]),                  // input wire [511 : 0] din
  .wr_en(stg0_phv_out_valid_w),              // input wire wr_en
  .rd_en(phv_fifo_rd_en),              // input wire rd_en
  .dout(phv_fifo_out_w[511:0]),                // output wire [511 : 0] dout
  .full(),                // output wire full
  .empty(phv_fifo_empty),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);

fifo_generator_522b phv_fifo_2 (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din(stg0_phv_out[1123:512]),                  // input wire [521 : 0] din
  .wr_en(stg0_phv_out_valid_w),              // input wire wr_en
  .rd_en(phv_fifo_rd_en),              // input wire rd_en
  .dout(phv_fifo_out_w[1123:512]),                // output wire [521 : 0] dout
  .full(),                // output wire full
  .empty(),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);

parser #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH), //for 100g mac exclusively
	.C_S_AXIS_TUSER_WIDTH(),
	.PKT_HDR_LEN(),
	.PARSE_ACT_RAM_WIDTH()
)
phv_parser
(
	.axis_clk		(clk),
	.aresetn		(aresetn),
	// input slvae axi stream
	.s_axis_tdata	(s_axis_tdata),
	.s_axis_tuser	(s_axis_tuser),
	.s_axis_tkeep	(s_axis_tkeep),
	.s_axis_tvalid	(s_axis_tvalid & s_axis_tready),
	.s_axis_tlast	(s_axis_tlast),

	// output
	// .parser_valid	(phv_valid),
	// .pkt_hdr_vec	(phv_fifo_in)
	.phv_valid_out	(stg0_phv_in_valid),
	.phv_out	(stg0_phv_in)
);

stage #(
	.STAGE(0)
)
stage0
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// input
    .phv_in					(stg0_phv_in),
    .phv_in_valid			(stg0_phv_in_valid_w),
	// output
    .phv_out				(stg0_phv_out),
    .phv_out_valid			(stg0_phv_out_valid)
);

/*
stage #(
	.STAGE(1)
)
stage1
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// input
    .phv_in					(stg0_phv_out),
    .phv_in_valid			(stg0_phv_out_valid_w),
	// output
    .phv_out				(stg1_phv_out),
    .phv_out_valid			(stg1_phv_out_valid)
);

stage #(
	.STAGE(2)
)
stage2
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// input
    .phv_in					(stg1_phv_out),
    .phv_in_valid			(stg1_phv_out_valid_w),
	// output
    .phv_out				(stg2_phv_out),
    .phv_out_valid			(stg2_phv_out_valid)
);

stage #(
	.STAGE(3)
)
stage3
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// input
    .phv_in					(stg2_phv_out),
    .phv_in_valid			(stg2_phv_out_valid_w),
	// output
    .phv_out				(stg3_phv_out),
    .phv_out_valid			(stg3_phv_out_valid)
);

stage #(
	.STAGE(4)
)
stage4
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// input
    .phv_in					(stg3_phv_out),
    .phv_in_valid			(stg3_phv_out_valid_w),
	// output
    .phv_out				(stg4_phv_out),
    .phv_out_valid			(stg4_phv_out_valid)
);*/

always @(posedge clk) begin
	if (~aresetn) begin
		stg0_phv_in_valid_r <= 0;
		stg0_phv_out_valid_r <= 0;
		stg1_phv_out_valid_r <= 0;
		stg2_phv_out_valid_r <= 0;
		stg3_phv_out_valid_r <= 0;
		stg4_phv_out_valid_r <= 0;
	end
	else begin
		stg0_phv_in_valid_r <= stg0_phv_in_valid;
		stg0_phv_out_valid_r <= stg0_phv_out_valid;
		stg1_phv_out_valid_r <= stg1_phv_out_valid;
		stg2_phv_out_valid_r <= stg2_phv_out_valid;
		stg3_phv_out_valid_r <= stg3_phv_out_valid;
		stg4_phv_out_valid_r <= stg4_phv_out_valid;
	end
end

assign stg0_phv_in_valid_w = stg0_phv_in_valid & ~stg0_phv_in_valid_r;
assign stg0_phv_out_valid_w = stg0_phv_out_valid & ~stg0_phv_out_valid_r;
assign stg1_phv_out_valid_w = stg1_phv_out_valid & ~stg1_phv_out_valid_r;
assign stg2_phv_out_valid_w = stg2_phv_out_valid & ~stg2_phv_out_valid_r;
assign stg3_phv_out_valid_w = stg3_phv_out_valid & ~stg3_phv_out_valid_r;
assign stg4_phv_out_valid_w = stg4_phv_out_valid & ~stg4_phv_out_valid_r;

//=====================================deparser part
localparam WAIT_TILL_PARSE_DONE = 0; 
localparam WAIT_PKT_1 = 1;
localparam WAIT_PKT_2 = 2;
localparam WAIT_PKT_3 = 3;
localparam REASSEMBLE_DATA_0 = 4;
localparam REASSEMBLE_DATA_1 = 5;
localparam REASSEMBLE_DATA_2 = 6;
localparam STATE_REASS_0_16 = 7;
localparam STATE_REASS_0_32 = 8;
localparam STATE_REASS_0_48 = 9;
localparam STATE_REASS_1_16 = 10;
localparam STATE_REASS_1_32 = 11;
localparam STATE_REASS_1_48 = 12;
localparam STATE_REASS_2_16 = 13;
localparam STATE_REASS_2_32 = 14;
localparam STATE_REASS_2_48 = 15;
localparam FLUSH_PKT_0 = 16;
localparam FLUSH_PKT_1 = 17;
localparam FLUSH_PKT_2 = 18;
localparam FLUSH_PKT_3 = 19;
localparam FLUSH_PKT = 20;

reg [SEG_NUM*C_S_AXIS_DATA_WIDTH-1:0]		pkts_tdata_stored_r;
reg [SEG_NUM*C_S_AXIS_DATA_WIDTH-1:0]		pkts_tdata_stored;
reg [SEG_NUM*C_S_AXIS_TUSER_WIDTH-1:0]	pkts_tuser_stored_r;
reg [SEG_NUM*C_S_AXIS_TUSER_WIDTH-1:0]	pkts_tuser_stored;
reg [SEG_NUM*(C_S_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored_r;
reg [SEG_NUM*(C_S_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored;
reg [SEG_NUM-1:0]							pkts_tlast_stored_r;
reg [SEG_NUM-1:0]							pkts_tlast_stored;

reg [4:0] state, state_next;

reg [11:0] vlan_id; // vlan id
wire [259:0] bram_out;
wire [6:0] parse_action_ind [0:9];

wire [15:0] parse_action [0:9];		// we have 10 parse action

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

assign parse_action_ind[0] = parse_action[0][12:6];
assign parse_action_ind[1] = parse_action[1][12:6];
assign parse_action_ind[2] = parse_action[2][12:6];
assign parse_action_ind[3] = parse_action[3][12:6];
assign parse_action_ind[4] = parse_action[4][12:6];
assign parse_action_ind[5] = parse_action[5][12:6];
assign parse_action_ind[6] = parse_action[6][12:6];
assign parse_action_ind[7] = parse_action[7][12:6];
assign parse_action_ind[8] = parse_action[8][12:6];
assign parse_action_ind[9] = parse_action[9][12:6];

localparam PHV_2B_START_POS = 20*5+256;
localparam PHV_4B_START_POS = 20*5+256+16*8;
localparam PHV_6B_START_POS = 20*5+256+16*8+32*8;

always @(*) begin

	// remember to set m_axis_tdata, tuser, tkeep, tlast, tvalid
	m_axis_tdata = 0;
	m_axis_tuser = 0;
	m_axis_tkeep = 0;
	m_axis_tlast = 0;
	m_axis_tvalid = 0;
	// fifo rd signals
	pkt_fifo_rd_en = 0;
	phv_fifo_rd_en = 0;

	pkts_tdata_stored_r = pkts_tdata_stored;
	pkts_tuser_stored_r = pkts_tuser_stored;
	pkts_tkeep_stored_r = pkts_tkeep_stored;
	pkts_tlast_stored_r = pkts_tlast_stored;

	state_next = state;
	//
	case (state)
		WAIT_TILL_PARSE_DONE: begin // later will be modifed to PROCESSING done
			if (!pkt_fifo_empty && !phv_fifo_empty) begin // both pkt and phv fifo are not empty
				pkts_tdata_stored_r[0+:C_S_AXIS_DATA_WIDTH] = tdata_fifo;
				// pkts_tuser_stored_r[0+:C_S_AXIS_TUSER_WIDTH] = tuser_fifo;
				pkts_tuser_stored_r[0+:C_S_AXIS_TUSER_WIDTH] = phv_fifo_out_w[0+:128];
				pkts_tkeep_stored_r[0+:(C_S_AXIS_DATA_WIDTH/8)] = tkeep_fifo;
				pkts_tlast_stored_r[0] = tlast_fifo;
				
				pkt_fifo_rd_en = 1;
				// vlan_id = tdata_fifo[120+:4];
				vlan_id = phv_fifo_out_w[129+:12];

				state_next = WAIT_PKT_1;
			end
		end
		WAIT_PKT_1: begin
			pkts_tdata_stored_r[(C_S_AXIS_DATA_WIDTH*1)+:C_S_AXIS_DATA_WIDTH] = tdata_fifo;
			pkts_tuser_stored_r[(C_S_AXIS_TUSER_WIDTH*1)+:C_S_AXIS_TUSER_WIDTH] = tuser_fifo;
			pkts_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8*1)+:(C_S_AXIS_DATA_WIDTH/8)] = tkeep_fifo;
			pkts_tlast_stored_r[1] = tlast_fifo;

			pkt_fifo_rd_en = 1;
			if (tlast_fifo || SEG_NUM == 2) begin
				state_next = REASSEMBLE_DATA_0;
			end
			else begin
				state_next = WAIT_PKT_2;
			end
		end
		WAIT_PKT_2: begin
			pkts_tdata_stored_r[(C_S_AXIS_DATA_WIDTH*2)+:C_S_AXIS_DATA_WIDTH] = tdata_fifo;
			pkts_tuser_stored_r[(C_S_AXIS_TUSER_WIDTH*2)+:C_S_AXIS_TUSER_WIDTH] = tuser_fifo;
			pkts_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8*2)+:(C_S_AXIS_DATA_WIDTH/8)] = tkeep_fifo;
			pkts_tlast_stored_r[2] = tlast_fifo;

			pkt_fifo_rd_en = 1;
			if (tlast_fifo) begin
				state_next = REASSEMBLE_DATA_0;
			end
			else begin
				state_next = WAIT_PKT_3;
			end
		end
		WAIT_PKT_3: begin
			pkts_tdata_stored_r[(C_S_AXIS_DATA_WIDTH*3)+:C_S_AXIS_DATA_WIDTH] = tdata_fifo;
			pkts_tuser_stored_r[(C_S_AXIS_TUSER_WIDTH*3)+:C_S_AXIS_TUSER_WIDTH] = tuser_fifo;
			pkts_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8*3)+:(C_S_AXIS_DATA_WIDTH/8)] = tkeep_fifo;
			pkts_tlast_stored_r[3] = tlast_fifo;

			pkt_fifo_rd_en = 1;
			state_next = REASSEMBLE_DATA_0;
		end

		`STATE_REASSEMBLE_DATA(0, REASSEMBLE_DATA_1)
		`STATE_REASS_IDX_BITSIZE(0, 16, REASSEMBLE_DATA_1, 2)
		`STATE_REASS_IDX_BITSIZE(0, 32, REASSEMBLE_DATA_1, 4)
		`STATE_REASS_IDX_BITSIZE(0, 48, REASSEMBLE_DATA_1, 6)
		`STATE_REASSEMBLE_DATA(1, REASSEMBLE_DATA_2)
		`STATE_REASS_IDX_BITSIZE(1, 16, REASSEMBLE_DATA_2, 2)
		`STATE_REASS_IDX_BITSIZE(1, 32, REASSEMBLE_DATA_2, 4)
		`STATE_REASS_IDX_BITSIZE(1, 48, REASSEMBLE_DATA_2, 6)
		`STATE_REASSEMBLE_DATA(2, FLUSH_PKT_0)
		`STATE_REASS_IDX_BITSIZE(2, 16, FLUSH_PKT_0, 2)
		`STATE_REASS_IDX_BITSIZE(2, 32, FLUSH_PKT_0, 4)
		`STATE_REASS_IDX_BITSIZE(2, 48, FLUSH_PKT_0, 6)


		FLUSH_PKT_0: begin
			phv_fifo_rd_en = 1;
			m_axis_tdata = pkts_tdata_stored[(C_S_AXIS_DATA_WIDTH*0)+:C_S_AXIS_DATA_WIDTH];
			m_axis_tuser = pkts_tuser_stored[(C_S_AXIS_TUSER_WIDTH*0)+:C_S_AXIS_TUSER_WIDTH];
			m_axis_tkeep = pkts_tkeep_stored[(C_S_AXIS_DATA_WIDTH/8*0)+:(C_S_AXIS_DATA_WIDTH/8)];
			m_axis_tlast = pkts_tlast_stored[0];
			m_axis_tvalid = 1;

			if (m_axis_tready) begin
				if (pkts_tlast_stored[0]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_1;
				end
			end
		end
		FLUSH_PKT_1: begin
			m_axis_tdata = pkts_tdata_stored[(C_S_AXIS_DATA_WIDTH*1)+:C_S_AXIS_DATA_WIDTH];
			m_axis_tuser = pkts_tuser_stored[(C_S_AXIS_TUSER_WIDTH*1)+:C_S_AXIS_TUSER_WIDTH];
			m_axis_tkeep = pkts_tkeep_stored[(C_S_AXIS_DATA_WIDTH/8*1)+:(C_S_AXIS_DATA_WIDTH/8)];
			m_axis_tlast = pkts_tlast_stored[1];
			m_axis_tvalid = 1;

			if (m_axis_tready) begin
				if (pkts_tlast_stored[1]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_2;
				end
			end
		end
		FLUSH_PKT_2: begin
			m_axis_tdata = pkts_tdata_stored[(C_S_AXIS_DATA_WIDTH*2)+:C_S_AXIS_DATA_WIDTH];
			m_axis_tuser = pkts_tuser_stored[(C_S_AXIS_TUSER_WIDTH*2)+:C_S_AXIS_TUSER_WIDTH];
			m_axis_tkeep = pkts_tkeep_stored[(C_S_AXIS_DATA_WIDTH/8*2)+:(C_S_AXIS_DATA_WIDTH/8)];
			m_axis_tlast = pkts_tlast_stored[2];
			m_axis_tvalid = 1;

			if (m_axis_tready) begin
				if (pkts_tlast_stored[2]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_3;
				end
			end
		end
		FLUSH_PKT_3: begin
			m_axis_tdata = pkts_tdata_stored[(C_S_AXIS_DATA_WIDTH*3)+:C_S_AXIS_DATA_WIDTH];
			m_axis_tuser = pkts_tuser_stored[(C_S_AXIS_TUSER_WIDTH*3)+:C_S_AXIS_TUSER_WIDTH];
			m_axis_tkeep = pkts_tkeep_stored[(C_S_AXIS_DATA_WIDTH/8*3)+:(C_S_AXIS_DATA_WIDTH/8)];
			m_axis_tlast = pkts_tlast_stored[3];
			m_axis_tvalid = 1;

			if (m_axis_tready) begin
				if (pkts_tlast_stored[3]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT;
				end
			end
		end
		FLUSH_PKT: begin
			if (!pkt_fifo_empty) begin
				m_axis_tvalid = tdata_fifo;
				m_axis_tuser = tuser_fifo;
				m_axis_tkeep = tkeep_fifo;
				m_axis_tlast = tlast_fifo;
				m_axis_tvalid = 1;
				if(m_axis_tready) begin
					pkt_fifo_rd_en = 1;
					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = FLUSH_PKT;
					end
				end
			end
		end
	endcase
end

always @(posedge clk) begin
	if (~aresetn) begin
		state <= WAIT_TILL_PARSE_DONE;

		pkts_tdata_stored <= 0;
		pkts_tuser_stored <= 0;
		pkts_tkeep_stored <= 0;
		pkts_tlast_stored <= 0;
	end
	else begin
		state <= state_next;

		pkts_tdata_stored <= pkts_tdata_stored_r;
		pkts_tuser_stored <= pkts_tuser_stored_r;
		pkts_tkeep_stored <= pkts_tkeep_stored_r;
		pkts_tlast_stored <= pkts_tlast_stored_r;
	end
end

parse_act_ram_ip #(
	//.C_INIT_FILE_NAME	("./parse_act_ram_init_file.mif"),
	//.C_LOAD_INIT_FILE	(1)
)
parse_act_ram
(
	// write port
	.clka		(clk),
	.addra		(),
	.dina		(),
	.ena		(),
	.wea		(),

	//
	.clkb		(clk),
	.addrb		(vlan_id[7:4]),
	// .addrb		(4'b10),
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);

// debug
/*
ila_0 
debug(
	.clk		(clk),


	.probe0		(stg0_phv_in_valid_w),
	.probe1		(stg0_phv_out_valid),
	.probe2		(state),
	.probe3		(stg0_phv_out[(PKT_VEC_WIDTH-1)-:96]),
	.probe4		(stg0_phv_out[0+:32])
);
*/
endmodule
