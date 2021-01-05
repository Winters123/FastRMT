`timescale 1ns / 1ps

module rmt_wrapper #(
	// AXI-Lite parameters
	// Width of AXI lite data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of AXI lite address bus in bits
    parameter AXIL_ADDR_WIDTH = 16,
    // Width of AXI lite wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 512,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	// self-defined
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    parameter ACT_LEN = 625,
    parameter KEY_OFF = 6*3

)
(
	input										clk,		// axis clk
	input										aresetn,	

	/*
     * input Slave AXI Stream
     */
	input [C_S_AXIS_DATA_WIDTH-1:0]				s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]		s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]			s_axis_tuser,
	input										s_axis_tvalid,
	output										s_axis_tready,
	input										s_axis_tlast,

	/*
     * output Master AXI Stream
     */
	output     [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output     [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output     [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output    									m_axis_tvalid,
	input										m_axis_tready,
	output  									m_axis_tlast,

	/*
     * AXI-Lite slave interface
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_awaddr,
    input  wire [2:0]                           s_axil_awprot,
    input  wire                                 s_axil_awvalid,
    output wire                                 s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]           s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]           s_axil_wstrb,
    input  wire                                 s_axil_wvalid,
    output wire                                 s_axil_wready,
    output wire [1:0]                           s_axil_bresp,
    output wire                                 s_axil_bvalid,
    input  wire                                 s_axil_bready,

    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_araddr,
    input  wire [2:0]                           s_axil_arprot,
    input  wire                                 s_axil_arvalid,
    output wire                                 s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]           s_axil_rdata,
    output wire [1:0]                           s_axil_rresp,
    output wire                                 s_axil_rvalid,
    input  wire                                 s_axil_rready
	
);

integer idx;

/*=================================================*/
localparam PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256;
//the number of cycles for a PHV
localparam SEG_NUM = 1024/C_S_AXIS_DATA_WIDTH;

// pkt fifo
wire								pkt_fifo_rd_en;
wire								pkt_fifo_nearly_full;
wire								pkt_fifo_empty;
wire [C_S_AXIS_DATA_WIDTH-1:0]		tdata_fifo;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		tuser_fifo;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]	tkeep_fifo;
wire								tlast_fifo;
// phv fifo
wire								phv_fifo_rd_en;
wire								phv_fifo_nearly_full;
wire								phv_fifo_empty;
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




//TODO for bug fix
wire [521:0] high_phv_out;
wire [511:0] low_phv_out;

assign phv_fifo_out_w = {high_phv_out, low_phv_out};
/*=================================================*/


//NOTE: to filter out packets other than UDP/IP.
wire [C_S_AXIS_DATA_WIDTH-1:0]				s_axis_tdata_f;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		s_axis_tkeep_f;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				s_axis_tuser_f;
wire										s_axis_tvalid_f;
wire										s_axis_tready_f;
wire										s_axis_tlast_f;

//NOTE: filter control packets from data packets.
wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_1;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_1;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_1;
wire										c_s_axis_tvalid_1;
wire										c_s_axis_tready_1;
wire										c_s_axis_tlast_1;

assign s_axis_tready_f = !pkt_fifo_nearly_full;

//set up a timer here
reg [95:0] fake_timer;
localparam FAKE_SEED = 96'hcecc666;

always @(posedge clk) begin
	fake_timer <= FAKE_SEED + 1'b1;
end

//two registers for AXI-Lite
reg [31:0] cookie_val;
reg [31:0] ctrl_token;

pkt_filter #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
)pkt_filter
(
	.clk(clk),
	.aresetn(aresetn),
	.time_stamp(fake_timer),
	.cookie_val(cookie_val),
	.ctrl_token(ctrl_token),

	// input Slave AXI Stream
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tkeep(s_axis_tkeep),
	.s_axis_tuser(s_axis_tuser),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tlast(s_axis_tlast),

	// output Master AXI Stream
	.m_axis_tdata(s_axis_tdata_f),
	.m_axis_tkeep(s_axis_tkeep_f),
	.m_axis_tuser(s_axis_tuser_f),
	.m_axis_tvalid(s_axis_tvalid_f),
	.m_axis_tready(s_axis_tready_f),
	.m_axis_tlast(s_axis_tlast_f),

	//control path
	.c_m_axis_tdata(c_s_axis_tdata_1),
	.c_m_axis_tkeep(c_s_axis_tkeep_1),
	.c_m_axis_tuser(c_s_axis_tuser_1),
	.c_m_axis_tvalid(c_s_axis_tvalid_1),
	.c_m_axis_tlast(c_s_axis_tlast_1)
);


fifo_generator_705b pkt_fifo (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din({s_axis_tdata_f, s_axis_tuser_f, s_axis_tkeep_f, s_axis_tlast_f}),                  // input wire [704 : 0] din
  .wr_en(s_axis_tvalid_f & ~pkt_fifo_nearly_full),              // input wire wr_en
  .rd_en(pkt_fifo_rd_en),              // input wire rd_en
  .dout({tdata_fifo, tuser_fifo, tkeep_fifo, tlast_fifo}),                // output wire [704 : 0] dout
  .full(pkt_fifo_nearly_full),                // output wire full
  .empty(pkt_fifo_empty),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);


fifo_generator_512b phv_fifo_1 (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din(stg4_phv_out[511:0]),                  // input wire [511 : 0] din
  .wr_en(stg4_phv_out_valid_w),              // input wire wr_en
  .rd_en(phv_fifo_rd_en),              // input wire rd_en
  .dout(low_phv_out),                // output wire [511 : 0] dout
  .full(),                // output wire full
  .empty(phv_fifo_empty),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);

fifo_generator_522b phv_fifo_2 (
  .clk(clk),                  // input wire clk
  .srst(~aresetn),                // input wire srst
  .din(stg4_phv_out[1123:512]),                  // input wire [521 : 0] din
  .wr_en(stg4_phv_out_valid_w),              // input wire wr_en
  .rd_en(phv_fifo_rd_en),              // input wire rd_en
  .dout(high_phv_out),                // output wire [521 : 0] dout
  .full(),                // output wire full
  .empty(),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()  // output wire rd_rst_busy
);

wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_2;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_2;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_2;
wire 										c_s_axis_tvalid_2;
wire 										c_s_axis_tlast_2;

wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_3;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_3;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_3;
wire 										c_s_axis_tvalid_3;
wire 										c_s_axis_tlast_3;


wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_4;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_4;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_4;
wire 										c_s_axis_tvalid_4;
wire 										c_s_axis_tlast_4;


wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_5;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_5;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_5;
wire 										c_s_axis_tvalid_5;
wire 										c_s_axis_tlast_5;

wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_6;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_6;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_6;
wire 										c_s_axis_tvalid_6;
wire 										c_s_axis_tlast_6;

wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_7;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_7;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_7;
wire 										c_s_axis_tvalid_7;
wire 										c_s_axis_tlast_7;

parser #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH), //for 100g mac exclusively
	.C_S_AXIS_TUSER_WIDTH(),
	.PKT_HDR_LEN(),
	.PARSE_ACT_RAM_WIDTH(),
	.PARSER_ID()
)
phv_parser
(
	.axis_clk		(clk),
	.aresetn		(aresetn),
	//data path
	.s_axis_tdata	(s_axis_tdata_f),
	.s_axis_tuser	(s_axis_tuser_f),
	.s_axis_tkeep	(s_axis_tkeep_f),
	.s_axis_tvalid	(s_axis_tvalid_f & s_axis_tready_f),
	.s_axis_tlast	(s_axis_tlast_f),

	.phv_valid_out	(stg0_phv_in_valid),
	.phv_out	    (stg0_phv_in),

	//control path
    .c_s_axis_tdata(c_s_axis_tdata_1),
	.c_s_axis_tuser(c_s_axis_tuser_1),
	.c_s_axis_tkeep(c_s_axis_tkeep_1),
	.c_s_axis_tvalid(c_s_axis_tvalid_1),
	.c_s_axis_tlast(c_s_axis_tlast_1),

    .c_m_axis_tdata(c_s_axis_tdata_2),
	.c_m_axis_tuser(c_s_axis_tuser_2),
	.c_m_axis_tkeep(c_s_axis_tkeep_2),
	.c_m_axis_tvalid(c_s_axis_tvalid_2),
	.c_m_axis_tlast(c_s_axis_tlast_2)

);


stage #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(0),  //valid: 0-4
    .PHV_LEN(PHV_LEN),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(ACT_LEN),
    .KEY_OFF(KEY_OFF)
)
stage0
(
	.axis_clk				(clk),
    .aresetn				(aresetn),

	// data path
    .phv_in					(stg0_phv_in),
    .phv_in_valid			(stg0_phv_in_valid_w),
    .phv_out				(stg0_phv_out),
    .phv_out_valid			(stg0_phv_out_valid),

	//control path
	.c_s_axis_tdata(c_s_axis_tdata_2),
	.c_s_axis_tuser(c_s_axis_tuser_2),
	.c_s_axis_tkeep(c_s_axis_tkeep_2),
	.c_s_axis_tvalid(c_s_axis_tvalid_2),
	.c_s_axis_tlast(c_s_axis_tlast_2),

	.c_m_axis_tdata(c_s_axis_tdata_3),
	.c_m_axis_tuser(c_s_axis_tuser_3),
	.c_m_axis_tkeep(c_s_axis_tkeep_3),
	.c_m_axis_tvalid(c_s_axis_tvalid_3),
	.c_m_axis_tlast(c_s_axis_tlast_3)
);

stage #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(1),  //valid: 0-4
    .PHV_LEN(PHV_LEN),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(ACT_LEN),
    .KEY_OFF(KEY_OFF)
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
    .phv_out_valid			(stg1_phv_out_valid),
	//control path
	.c_s_axis_tdata(c_s_axis_tdata_3),
	.c_s_axis_tuser(c_s_axis_tuser_3),
	.c_s_axis_tkeep(c_s_axis_tkeep_3),
	.c_s_axis_tvalid(c_s_axis_tvalid_3),
	.c_s_axis_tlast(c_s_axis_tlast_3),

	.c_m_axis_tdata(c_s_axis_tdata_4),
	.c_m_axis_tuser(c_s_axis_tuser_4),
	.c_m_axis_tkeep(c_s_axis_tkeep_4),
	.c_m_axis_tvalid(c_s_axis_tvalid_4),
	.c_m_axis_tlast(c_s_axis_tlast_4)
);

stage #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(2),  //valid: 0-4
    .PHV_LEN(PHV_LEN),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(ACT_LEN),
    .KEY_OFF(KEY_OFF)
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
    .phv_out_valid			(stg2_phv_out_valid),
	//control path
	.c_s_axis_tdata(c_s_axis_tdata_4),
	.c_s_axis_tuser(c_s_axis_tuser_4),
	.c_s_axis_tkeep(c_s_axis_tkeep_4),
	.c_s_axis_tvalid(c_s_axis_tvalid_4),
	.c_s_axis_tlast(c_s_axis_tlast_4),

	.c_m_axis_tdata(c_s_axis_tdata_5),
	.c_m_axis_tuser(c_s_axis_tuser_5),
	.c_m_axis_tkeep(c_s_axis_tkeep_5),
	.c_m_axis_tvalid(c_s_axis_tvalid_5),
	.c_m_axis_tlast(c_s_axis_tlast_5)
);

stage #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(3),  //valid: 0-4
    .PHV_LEN(PHV_LEN),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(ACT_LEN),
    .KEY_OFF(KEY_OFF)
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
    .phv_out_valid			(stg3_phv_out_valid),
	//control path
	.c_s_axis_tdata(c_s_axis_tdata_5),
	.c_s_axis_tuser(c_s_axis_tuser_5),
	.c_s_axis_tkeep(c_s_axis_tkeep_5),
	.c_s_axis_tvalid(c_s_axis_tvalid_5),
	.c_s_axis_tlast(c_s_axis_tlast_5),

	.c_m_axis_tdata(c_s_axis_tdata_6),
	.c_m_axis_tuser(c_s_axis_tuser_6),
	.c_m_axis_tkeep(c_s_axis_tkeep_6),
	.c_m_axis_tvalid(c_s_axis_tvalid_6),
	.c_m_axis_tlast(c_s_axis_tlast_6)
);

stage #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(4),  //valid: 0-4
    .PHV_LEN(PHV_LEN),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(ACT_LEN),
    .KEY_OFF(KEY_OFF)
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
    .phv_out_valid			(stg4_phv_out_valid),
	//control path
	.c_s_axis_tdata(c_s_axis_tdata_6),
	.c_s_axis_tuser(c_s_axis_tuser_6),
	.c_s_axis_tkeep(c_s_axis_tkeep_6),
	.c_s_axis_tvalid(c_s_axis_tvalid_6),
	.c_s_axis_tlast(c_s_axis_tlast_6),

	.c_m_axis_tdata(c_s_axis_tdata_7),
	.c_m_axis_tuser(c_s_axis_tuser_7),
	.c_m_axis_tkeep(c_s_axis_tkeep_7),
	.c_m_axis_tvalid(c_s_axis_tvalid_7),
	.c_m_axis_tlast(c_s_axis_tlast_7)
);


deparser #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
	.C_PKT_VEC_WIDTH(),
    .DEPARSER_ID()
)
phv_deparser (
	.clk					(clk),
	.aresetn				(aresetn),

	//data plane
	.pkt_fifo_tdata			(tdata_fifo),
	.pkt_fifo_tkeep			(tkeep_fifo),
	.pkt_fifo_tuser			(tuser_fifo),
	.pkt_fifo_tlast			(tlast_fifo),
	.pkt_fifo_empty			(pkt_fifo_empty),
	// output from STAGE
	.pkt_fifo_rd_en			(pkt_fifo_rd_en),

	.phv_fifo_out			(phv_fifo_out_w),
	.phv_fifo_empty			(phv_fifo_empty),
	.phv_fifo_rd_en			(phv_fifo_rd_en),
	// output
	.depar_out_tdata		(m_axis_tdata),
	.depar_out_tkeep		(m_axis_tkeep),
	.depar_out_tuser		(m_axis_tuser),
	.depar_out_tvalid		(m_axis_tvalid),
	.depar_out_tlast		(m_axis_tlast),
	// input
	.depar_out_tready		(m_axis_tready),

	//control path
	.c_s_axis_tdata(c_s_axis_tdata_7),
	.c_s_axis_tuser(c_s_axis_tuser_7),
	.c_s_axis_tkeep(c_s_axis_tkeep_7),
	.c_s_axis_tvalid(c_s_axis_tvalid_7),
	.c_s_axis_tlast(c_s_axis_tlast_7)
);

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

assign stg0_phv_in_valid_w = stg0_phv_in_valid ;  //& ~stg0_phv_in_valid_r;
assign stg0_phv_out_valid_w = stg0_phv_out_valid ;//& ~stg0_phv_out_valid_r;
assign stg1_phv_out_valid_w = stg1_phv_out_valid ;//& ~stg1_phv_out_valid_r;
assign stg2_phv_out_valid_w = stg2_phv_out_valid ;//& ~stg2_phv_out_valid_r;
assign stg3_phv_out_valid_w = stg3_phv_out_valid ;//& ~stg3_phv_out_valid_r;
assign stg4_phv_out_valid_w = stg4_phv_out_valid ;//& ~stg4_phv_out_valid_r;


// Port control registers
reg axil_rmt_awready_reg = 1'b0;
reg axil_rmt_wready_reg = 1'b0;
reg axil_rmt_bvalid_reg = 1'b0;
reg axil_rmt_arready_reg = 1'b0;
reg [AXIL_DATA_WIDTH-1:0] axil_rmt_rdata_reg = {AXIL_DATA_WIDTH{1'b0}};
reg axil_rmt_rvalid_reg = 1'b0;


// AXI lite connections
wire [AXIL_ADDR_WIDTH-1:0] axil_rmt_awaddr;
wire [2:0]                 axil_rmt_awprot;
wire                       axil_rmt_awvalid;
wire                       axil_rmt_awready;
wire [AXIL_DATA_WIDTH-1:0] axil_rmt_wdata;
wire [AXIL_STRB_WIDTH-1:0] axil_rmt_wstrb;
wire                       axil_rmt_wvalid;
wire                       axil_rmt_wready;
wire [1:0]                 axil_rmt_bresp;
wire                       axil_rmt_bvalid;
wire                       axil_rmt_bready;

wire [AXIL_ADDR_WIDTH-1:0] axil_rmt_araddr;
wire [2:0]                 axil_rmt_arprot;
wire                       axil_rmt_arvalid;
wire                       axil_rmt_arready;
wire [AXIL_DATA_WIDTH-1:0] axil_rmt_rdata;
wire [1:0]                 axil_rmt_rresp;
wire                       axil_rmt_rvalid;
wire                       axil_rmt_rready;

assign s_axil_awready = axil_rmt_awready_reg;
assign s_axil_wready = axil_rmt_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = axil_rmt_bvalid_reg;
assign s_axil_arready = axil_rmt_arready_reg;
assign s_axil_rdata = axil_rmt_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = axil_rmt_rvalid_reg;

/*
	*control path of AXI-Lite
*/
always @(posedge clk or negedge aresetn) begin
    
	axil_rmt_awready_reg <= 1'b0;
    axil_rmt_wready_reg <= 1'b0;
    axil_rmt_bvalid_reg <= axil_rmt_bvalid_reg && !s_axil_bready;
    axil_rmt_arready_reg <= 1'b0;
    axil_rmt_rvalid_reg <= axil_rmt_rvalid_reg && !s_axil_rready;

    if (~aresetn) begin
        axil_rmt_awready_reg <= 1'b0;
        axil_rmt_wready_reg <= 1'b0;
        axil_rmt_bvalid_reg <= 1'b0;
        axil_rmt_arready_reg <= 1'b0;
        axil_rmt_rvalid_reg <= 1'b0;
    end

    // if (axil_rmt_awvalid && axil_rmt_wvalid && !axil_rmt_bvalid) begin
    //     // write operation
    //     axil_rmt_awready_reg <= 1'b1;
    //     axil_rmt_wready_reg <= 1'b1;
    //     axil_rmt_bvalid_reg <= 1'b1;

    //     case ({axil_rmt_awaddr[15:2], 2'b00})
    //     endcase
    // end

    if (s_axil_arvalid && !s_axil_rvalid) begin
        // read operation
        axil_rmt_arready_reg <= 1'b1;
        axil_rmt_rvalid_reg <= 1'b1;
        axil_rmt_rdata_reg <= {AXIL_DATA_WIDTH{1'b0}};

        case ({s_axil_araddr[15:2], 2'b00})
            16'h2021: begin
                axil_rmt_rdata_reg <= cookie_val;
            end
            16'h2022: begin
                axil_rmt_rdata_reg <= ctrl_token;
            end
        endcase
    end

end


endmodule
