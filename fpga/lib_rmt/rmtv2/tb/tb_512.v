
`timescale 1ns / 1ps

module tb_demo #(
    // parameters declared here.
	parameter C_S_AXI_DATA_WIDTH = 32,
	parameter C_S_AXI_ADDR_WIDTH = 12,
	parameter C_BASEADDR = 32'h80000000,
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 512,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	parameter C_M_AXIS_DATA_WIDTH = 512,
	// self-defined
	parameter PHV_ADDR_WIDTH = 4,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256
)();

//stimulates (regs) and oputputs(wires) declared here
reg                                 clk;
reg                                 aresetn;
reg [15:0]                          vlan_drop_flags;
wire [31:0]                         cookie_val;
wire [31:0]                         ctrl_token;

reg [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata;
reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]		s_axis_tkeep;
reg [C_S_AXIS_TUSER_WIDTH-1:0]			s_axis_tuser;
reg										s_axis_tvalid;
wire									s_axis_tready;
reg										s_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH-1:0]		    m_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]    m_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		    m_axis_tuser;
wire								    m_axis_tvalid;
reg										m_axis_tready;
wire									m_axis_tlast;


reg [PHV_LEN-1:0]        phv_in;
reg                      phv_in_valid;

wire [PHV_LEN-1:0]       phv_out;
wire						phv_out_valid;

//clk signal
localparam CYCLE = 10;

always begin
    #(CYCLE/2) clk = ~clk;
end

//reset signal
initial begin
    clk = 0;
    aresetn = 1;
    #(10);
    aresetn = 0; //reset all the values
    #(10);
    aresetn = 1;
end

initial begin
    m_axis_tready <= 1'b1;
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(2*CYCLE+CYCLE/2)
    /*
        here you give values to stimulates per CYCLE
    */

    // test for rmt_wrapper
    m_axis_tready <= 1'b1;
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
end
// initial begin
//     vlan_drop_flags <= 0;

//     m_axis_tready <= 1'b1;
//     s_axis_tdata <= 512'b0; 
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'h0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #(2*CYCLE+CYCLE/2)
//     /*
//         here you give values to stimulates per CYCLE
//     */

//     // test for rmt_wrapper
//     m_axis_tready <= 1'b1;
//     s_axis_tdata <= 512'b0; 
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'h0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;

// 	// configure stateful page table
// 	// stage 2, page table for vid 1 and 2
// 	// vid 1
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000001001355541c00f2f1d204dededede6f6f6f6f20de1140000001003000004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010042;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004; 
//     s_axis_tkeep <= 64'h0000000000000003;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
// 	// vid 2
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000002001351531c00f2f1d204dededede6f6f6f6f20de1140000001003000004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010042;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000404; 
//     s_axis_tkeep <= 64'h0000000000000003;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

//     // ctrl pkts for vid1
// 	// parser, vid 1 first 5 actions valid, 0031 0b91 0c21 0d23 0e25
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h0000000000000000000000000000000300134d521c00f2f1d204dededede6f6f6f6f20de1140000001003000004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010042;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h0; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000804; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     // checkme: start here............ last 
// 	// deparser
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000004001349511c00f2f1d204dededede6f6f6f6f20de1140000001003000004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010042;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c04; 
//     s_axis_tkeep <= 64'h0000000000000003;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     // 3
// 	// stage 0, key extract, vid 1
//      #(20*CYCLE)

//     //checkme: start t_vid1 ....... 1st
//     s_axis_tdata <= 512'h00000000000000000000000000000001000042cc3b00f2f1d204dededede6f6f6f6f01de1140000001004f00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010061;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000000000000000000000000000000000000000000000000000000300000030030000003003000000000000000000000270e250d230c910ba108; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     // 4
// 	// stage 0, key mask, vid 1
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000001000542c73b00f2f1d204dededede6f6f6f6f01de1140000001004f00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010061;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000000000000000000000000000000000000000000000000000000000000000000300000030030000003003000000000000000000000270e250d230c910ba108; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     // 5
// 	// stage 0, cam ind 0

//     //checkme: vlan-1 3rd 
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000010001536a1d00f2f1d204dededede6f6f6f6f1fde1140000001003100004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010043;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000; 
//     s_axis_tkeep <= 64'h0000000000000007;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
// 	#CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000800f00d002000000000000000000000000000000000000000010; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

//     //checkme: vlan-1 4th
// 	// stage 0, ram ind 0
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000010f0117723300f2f1d204dededede6f6f6f6f09de1140000001004700004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010059;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000f8ffff0000ffffffffffffffffffffffffffffffffffffffff; 
//     s_axis_tkeep <= 64'h0000000000000007;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000e00100c00300800700; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;

//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

//     // 7
// 	//checkme: vlan-1 5th
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000000000223ba3400f2f1d204dededede6f6f6f6f08de1140000001004800004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001005a;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000a001000000000000000000000000000000000000000010; 
//     s_axis_tkeep <= 64'h0000000003ffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
// 	#CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000800f009000000000000000000000000000000000000000000010; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

//     // 8
// 	//checkme: vlan-1 6th
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000000f02e83c6900f2f1d204dededede6f6f6f6fd3dd1140000001007d00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001008f;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000f00001e00003c0000780000f00000e00100c003008007808c0200001e00003c0000780000f00000e00100c00300800700000f00001e00003c0000780000f0; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000e00100c00300800700; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-1 7th
// 	// stage 1, key extract vid 1
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000001000953621d00f2f1d204dededede6f6f6f6f1fde1140000001003100004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h0; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-1 8th
// 	// stage 1, key mask vid 1
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000001000224893400f2f1d204dededede6f6f6f6f08de1140000001004800004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001005a;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000010; 
//     s_axis_tkeep <= 64'h0000000003ffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-1 9th
// 	// stage 1, cam ind 1
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000010f02e93b6900f2f1d204dededede6f6f6f6fd3dd1140000001007d00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001008f;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000f00001e00003c0000780000f00000e00100c003008007808c0100001e00003c0000780000f00000e00100c00300800700000f00001e00003c0000780000f0; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000e00100c00300800700; 
//     s_axis_tkeep <= 64'h0000000000007fff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-2 1th
// 	// stage 1, ram ind 1
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h0000000000000000000000000000000200005fd93b00f2f1d204dededede6f6f6f6f01de1140000001004f00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010061;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000030000003003000000300300000000000000000000000002f0d910ba108230c; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

//     //checkme: vlan-2 2th
// 	// stage 1, cam ind 1
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h0000000000000000000000000000000200055fd43b00f2f1d204dededede6f6f6f6f01de1140000001004f00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010061;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000030000003003000000300300000000000000000000000002f0d910ba108230c; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-2 3th
// 	// stage 1, ram ind 1
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000002001153591d00f2f1d204dededede6f6f6f6f1fde1140000001003100004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010043;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;



// 	//=====================================================================
//     //checkme: vlan-2 4th
//     // 1
// 	// parser
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000020f1117613300f2f1d204dededede6f6f6f6f09de1140000001004700004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000010059;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000000000000000000000000000000000000000000000000000000000000000000f8ffff0000ffffffffffffffffffffffffffffffffffffffff; 
//     s_axis_tkeep <= 64'h00000001ffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-2 5th
// 	// deparser
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000004001224663400f2f1d204dededede6f6f6f6f08de1140000001004800004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001005a;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000020; 
//     s_axis_tkeep <= 64'h0000000003ffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     //checkme: vlan-2 6th
// 	// stage 2, key extract vid 2
//      #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000040f128ff16900f2f1d204dededede6f6f6f6fd3dd1140000001007d00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001008f;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000f00001e00003c0000780000f00000e00100c00300800700000f00001e00003c00007800c4bb0000e00100c00300800700000f00001e00003c0000780000f0; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000e00100c00300800700; 
//     s_axis_tkeep <= 64'h0000000000007fff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

// 	//checkme: vlan-2 7th
// 	// stage 2, key mask vid 2
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h00000000000000000000000000000005001223953400f2f1d204dededede6f6f6f6f08de1140000001004800004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001005a;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000a001000000000000000000000000000000000000000020; 
//     s_axis_tkeep <= 64'h0000000003ffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;

// 	//checkme: vlan-2 8th
// 	// stage 2, cam ind 4
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000000000000000000050f12bff06900f2f1d204dededede6f6f6f6fd3dd1140000001007d00004500080f0000810504030201000b0a09080706; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h0000000000000000000000000001008f;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
// 	#CYCLE
//     s_axis_tdata <= 512'h000f00001e00003c0000780000f00000e00100c00300800700000f00001e00003c00007800c48b0000e00100c00300800700000f00001e00003c0000780000f0; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000e00100c00300800700; 
//     s_axis_tkeep <= 64'h0000000000007fff;
//     s_axis_tuser <= 128'h00000000000000000000000000000000;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


// 	// checkme: test 1
// 	// stage 2, ram ind 4
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     // checkme: test 2
//     s_axis_tdata <= 512'h000000000000000002000000040000001a008d201a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     #(20*CYCLE)
//     // checkme: test 3
//     s_axis_tdata <= 512'h0000000000000000aaaaaaaa000000000d004acb1a0013001300090000006f6f6f6fd79b1140000001002e000045000802000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;


//     #(20*CYCLE)

//     // stage 2, ram ind 4
//     #(20*CYCLE)
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a211a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a4013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b0;
//     #CYCLE
//     s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a4013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
//     s_axis_tkeep <= 64'hffffffffffffffff;
//     s_axis_tuser <= 128'h00000000000000000000000000000040;
//     s_axis_tvalid <= 1'b1;
//     s_axis_tlast <= 1'b1;
//     #CYCLE
// 	s_axis_tvalid <= 1'b0;
// 	s_axis_tlast <= 1'b0;
//     #(20*CYCLE)

//     s_axis_tdata <= 512'b0; 
//     s_axis_tkeep <= 64'h0;
//     s_axis_tuser <= 128'h0;
//     s_axis_tvalid <= 1'b0;
//     s_axis_tlast <= 1'b0;

// end

always @(posedge clk) begin
    #(20*CYCLE)
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a211a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    // #CYCLE
    // s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a4013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    // s_axis_tkeep <= 64'hffffffffffffffff;
    // s_axis_tuser <= 128'h00000000000000000000000000000040;
    // s_axis_tvalid <= 1'b0;
    // s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a221a0013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= 512'h000000000000000004000000020000000d009a201a4013001300090000006f6f6f6fd79b1140000001002e000045000801000081a401bdfefd3c050000000000; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h00000000000000000000000000000040;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b1;
    #CYCLE
	s_axis_tvalid <= 1'b0;
	s_axis_tlast <= 1'b0;
end

/*
stage #(
    .STAGE(0),  //valid: 0-4
    .PHV_LEN(),
    .KEY_LEN(),
    .ACT_LEN(),
    .KEY_OFF()
)
stage0
(
    .axis_clk			(clk),
    .aresetn			(aresetn),

    .phv_in				(phv_in),
    .phv_in_valid		(phv_in_valid),
    .phv_out			(phv_out),
    .phv_out_valid		(phv_out_valid),

	.stg_ready			()

    //input for the key extractor RAM
    // input  [KEY_OFF-1:0]         key_offset_in,
    // input                        key_offset_valid_in

    //TODO need control channel
);*/

rmt_wrapper #(
	.C_S_AXI_DATA_WIDTH(),
	.C_S_AXI_ADDR_WIDTH(),
	.C_BASEADDR(),
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(),
	.C_M_AXIS_DATA_WIDTH(C_M_AXIS_DATA_WIDTH),
	.PHV_ADDR_WIDTH()
)rmt_wrapper_ins
(
	.clk(clk),		// axis clk
	.aresetn(aresetn),
	// input Slave AXI Stream
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tkeep(s_axis_tkeep),
	.s_axis_tuser(s_axis_tuser),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tlast(s_axis_tlast),

	// output Master AXI Stream
	.m_axis_tdata(m_axis_tdata),
	.m_axis_tkeep(m_axis_tkeep),
	.m_axis_tuser(m_axis_tuser),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready),
	.m_axis_tlast(m_axis_tlast)
);

endmodule