
`timescale 1ns / 1ps

module tb_rmt_wrapper #(
    // Slave AXI parameters
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
	parameter PHV_ADDR_WIDTH = 4
)();

reg                                 clk;
reg                                 aresetn;

reg [C_S_AXIS_DATA_WIDTH-1:0]		s_axis_tdata;
reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]	s_axis_tkeep;
reg [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser;
reg									s_axis_tvalid;
wire								s_axis_tready;
reg									s_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH-1:0]		    m_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH/8))-1:0]    m_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		    m_axis_tuser;
wire								    m_axis_tvalid;
reg										m_axis_tready;
wire									m_axis_tlast;

assign s_axis_tready = 1'b1;

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
    #(2*CYCLE+CYCLE/2)
    m_axis_tready <= 1'b1;
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hffffffffffffffff,64'hffffffffffffffff,256'b0,12'b0100000,116'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hefffffffffffffff,64'hffffffffffffffff,384'hfffffffffffffffffffff}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hdfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hcfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b1;
    #(CYCLE)
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;
    #(6*CYCLE)

    s_axis_tdata <= {64'hffffffffffffffff,64'hffffffffffffffff,159'b0, 8'h11, 72'b0, 16'h0008, 128'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hefffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hdfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hcfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b1;

    #(CYCLE)
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;

    #(10*CYCLE);
    s_axis_tdata <= {64'hffffffffffffffff,64'hffffffffffffffff,159'b0, 8'h11, 72'b0, 16'h0008, 128'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hefffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hdfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b0;
    #CYCLE
    s_axis_tdata <= {64'hcfffffffffffffff,64'hffffffffffffffff,384'b0}; 
    s_axis_tkeep <= 64'hffffffffffffffff;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b1;
    s_axis_tlast <= 1'b1;

    #(CYCLE)
    s_axis_tdata <= 512'b0; 
    s_axis_tkeep <= 64'h0;
    s_axis_tuser <= 128'h0;
    s_axis_tvalid <= 1'b0;
    s_axis_tlast <= 1'b0;

    #(10*CYCLE);
end


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