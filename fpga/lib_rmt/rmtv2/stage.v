`timescale 1ns / 1ps

module stage #(
    parameter C_S_AXIS_DATA_WIDTH = 512,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter STAGE_ID = 0,  //valid: 0-4
    parameter PHV_LEN = 48*8+32*8+16*8+256,
    parameter KEY_LEN = 48*2+32*2+16*2+1,
    parameter ACT_LEN = 25,
    parameter KEY_OFF = 6*3+20
)
(
    input                        axis_clk,
    input                        aresetn,

    input  [PHV_LEN-1:0]         phv_in,
    input                        phv_in_valid,
    output  					 stage_ready_out,

    output [PHV_LEN-1:0]         phv_out,
    output                       phv_out_valid,
	input                        stage_ready_in,

    //input for the key extractor RAM
    // input  [KEY_OFF-1:0]         key_offset_in,
    // input                        key_offset_valid_in

    //control path
    input [C_S_AXIS_DATA_WIDTH-1:0]			c_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		c_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		c_s_axis_tkeep,
	input									c_s_axis_tvalid,
	input									c_s_axis_tlast,

    output [C_S_AXIS_DATA_WIDTH-1:0]		c_m_axis_tdata,
	output [C_S_AXIS_TUSER_WIDTH-1:0]		c_m_axis_tuser,
	output [C_S_AXIS_DATA_WIDTH/8-1:0]		c_m_axis_tkeep,
	output									c_m_axis_tvalid,
	output									c_m_axis_tlast

);

//key_extract to lookup_engine
wire [KEY_LEN-1:0]           key2lookup_key;
wire                         key2lookup_key_valid;
wire                         key2lookup_phv_valid;
wire [PHV_LEN-1:0]           key2lookup_phv;
wire [KEY_LEN-1:0]           key2lookup_key_mask;
wire                         lookup2key_ready;

//control path 1 (key2lookup)
wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_1;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_1;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_1;
wire 										c_s_axis_tvalid_1;
wire 										c_s_axis_tlast_1;

//control path 2 (lkup2action)
wire [C_S_AXIS_DATA_WIDTH-1:0]				c_s_axis_tdata_2;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]		c_s_axis_tkeep_2;
wire [C_S_AXIS_TUSER_WIDTH-1:0]				c_s_axis_tuser_2;
wire 										c_s_axis_tvalid_2;
wire 										c_s_axis_tlast_2;


//lookup_engine to action_engine
wire [ACT_LEN*25-1:0]        lookup2action_action;
wire                         lookup2action_action_valid;
wire [PHV_LEN-1:0]           lookup2action_phv;
wire                         action2lookup_ready;



key_extract #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(STAGE_ID),
    .PHV_LEN(),
    .KEY_LEN(KEY_LEN),
    // format of KEY_OFF entry: |--3(6B)--|--3(6B)--|--3(4B)--|--3(4B)--|--3(2B)--|--3(2B)--|
    .KEY_OFF(KEY_OFF),
    .AXIL_WIDTH(),
    .KEY_OFF_ADDR_WIDTH(),
    .KEY_EX_ID()
)key_extract(
    .clk(axis_clk),
    .rst_n(aresetn),
    .phv_in(phv_in),
    .phv_valid_in(phv_in_valid),
    .ready_out(stage_ready_out),

    .phv_out(key2lookup_phv),
    .phv_valid_out(key2lookup_phv_valid),
    .key_out_masked(key2lookup_key),
    .key_valid_out(key2lookup_key_valid),
    .key_mask_out(key2lookup_key_mask),
    .ready_in(lookup2key_ready),

    //control path
    .c_s_axis_tdata(c_s_axis_tdata),
	.c_s_axis_tuser(c_s_axis_tuser),
	.c_s_axis_tkeep(c_s_axis_tkeep),
	.c_s_axis_tvalid(c_s_axis_tvalid),
	.c_s_axis_tlast(c_s_axis_tlast),

    .c_m_axis_tdata(c_s_axis_tdata_1),
	.c_m_axis_tuser(c_s_axis_tuser_1),
	.c_m_axis_tkeep(c_s_axis_tkeep_1),
	.c_m_axis_tvalid(c_s_axis_tvalid_1),
	.c_m_axis_tlast(c_s_axis_tlast_1)
);


lookup_engine #(
    .C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
    .STAGE_ID(STAGE_ID),
    .PHV_LEN(),
    .KEY_LEN(KEY_LEN),
    .ACT_LEN(),
    .LOOKUP_ID()
) lookup_engine(
    .clk(axis_clk),
    .rst_n(aresetn),

    //output from key extractor
    .extract_key(key2lookup_key),
    .extract_mask(key2lookup_key_mask),
    .key_valid(key2lookup_key_valid),
    .phv_valid(key2lookup_phv_valid),
    .phv_in(key2lookup_phv),
    .ready_out(lookup2key_ready),

    //output to the action engine
    .action(lookup2action_action),
    .action_valid(lookup2action_action_valid),
    .phv_out(lookup2action_phv),
    .ready_in(action2lookup_ready),

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

action_engine #(
    .STAGE_ID(STAGE_ID),
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
    .PHV_LEN(),
    .ACT_LEN(),
    .ACT_ID()
)action_engine(
    .clk(axis_clk),
    .rst_n(aresetn),

    //signals from lookup to ALUs
    .phv_in(lookup2action_phv),
    .phv_valid_in(lookup2action_action_valid),
    .action_in(lookup2action_action),
    .action_valid_in(lookup2action_action_valid),
    .ready_out(action2lookup_ready),

    //signals output from ALUs
    .phv_out(phv_out),
    .phv_valid_out(phv_out_valid),
    .ready_in(stage_ready_in),
    //control path
    .c_s_axis_tdata(c_s_axis_tdata_2),
	.c_s_axis_tuser(c_s_axis_tuser_2),
	.c_s_axis_tkeep(c_s_axis_tkeep_2),
	.c_s_axis_tvalid(c_s_axis_tvalid_2),
	.c_s_axis_tlast(c_s_axis_tlast_2),

    .c_m_axis_tdata(c_m_axis_tdata),
	.c_m_axis_tuser(c_m_axis_tuser),
	.c_m_axis_tkeep(c_m_axis_tkeep),
	.c_m_axis_tvalid(c_m_axis_tvalid),
	.c_m_axis_tlast(c_m_axis_tlast)
);

endmodule
