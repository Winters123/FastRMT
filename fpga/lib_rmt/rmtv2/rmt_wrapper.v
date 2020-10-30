`timescale 1ns / 1ps

module rmt_wrapper #(
	// Slave AXI parameters
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 512,
	parameter C_S_AXIS_TUSER_WIDTH = 128
	// Master
	// self-defined
)
(
	input										clk,		// axis clk
	input										aresetn,	

	// input Slave AXI Stream
	input [C_S_AXIS_DATA_WIDTH-1:0]				s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]		s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]			s_axis_tuser,
	input										s_axis_tvalid,
	output										s_axis_tready,
	input										s_axis_tlast,

	// output Master AXI Stream
	output     [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output     [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output     [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output    									m_axis_tvalid,
	input										m_axis_tready,
	output  									m_axis_tlast
	
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

assign s_axis_tready_f = !pkt_fifo_nearly_full;

pkt_filter #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
)pkt_filter
(
	.clk(clk),
	.aresetn(aresetn),

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
	.m_axis_tlast(s_axis_tlast_f)
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
  .din(stg0_phv_out[511:0]),                  // input wire [511 : 0] din
  .wr_en(stg0_phv_out_valid_w),              // input wire wr_en
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
  .din(stg0_phv_out[1123:512]),                  // input wire [521 : 0] din
  .wr_en(stg0_phv_out_valid_w),              // input wire wr_en
  .rd_en(phv_fifo_rd_en),              // input wire rd_en
  .dout(high_phv_out),                // output wire [521 : 0] dout
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
	.s_axis_tdata	(s_axis_tdata_f),
	.s_axis_tuser	(s_axis_tuser_f),
	.s_axis_tkeep	(s_axis_tkeep_f),
	.s_axis_tvalid	(s_axis_tvalid_f & s_axis_tready_f),
	.s_axis_tlast	(s_axis_tlast_f),

	// output
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



deparser #(
	.C_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_AXIS_TUSER_WIDTH(),
	.C_PKT_VEC_WIDTH()
)
phv_deparser (
	.clk					(clk),
	.aresetn				(aresetn),

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
	.depar_out_tready		(m_axis_tready)
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

assign stg0_phv_in_valid_w = stg0_phv_in_valid ;//& ~stg0_phv_in_valid_r;
assign stg0_phv_out_valid_w = stg0_phv_out_valid ;//& ~stg0_phv_out_valid_r;
assign stg1_phv_out_valid_w = stg1_phv_out_valid ;//& ~stg1_phv_out_valid_r;
assign stg2_phv_out_valid_w = stg2_phv_out_valid ;//& ~stg2_phv_out_valid_r;
assign stg3_phv_out_valid_w = stg3_phv_out_valid ;//& ~stg3_phv_out_valid_r;
assign stg4_phv_out_valid_w = stg4_phv_out_valid ;//& ~stg4_phv_out_valid_r;


endmodule
