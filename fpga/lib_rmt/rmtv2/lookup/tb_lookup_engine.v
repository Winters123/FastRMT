`timescale 1ns / 1ps

module tb_lookup_engine #(    
    parameter STAGE = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    parameter ACT_LEN = 25
)();

reg clk;
reg rst_n;

//output from key extractor
//output from key extractor
reg [KEY_LEN-1:0]           extract_key;
reg                         key_valid;
reg [PHV_LEN-1:0]           phv_in;
    //output to the action engine
wire [ACT_LEN*25-1:0]       action;
wire                        action_valid;
wire [PHV_LEN-1:0]          phv_out;

//clk signal
localparam CYCLE = 10;

always begin
    #(CYCLE/2) clk = ~clk;
end

//reset signal
initial begin
    clk = 0;
    rst_n = 1;
    #(10);
    rst_n = 0; //reset all the values
    #(10);
    rst_n = 1;
end


initial begin
    /*
        first one is a miss
    */
    #(2*CYCLE); //after the rst_n, start the test
    #(5)
    extract_key <= 197'b0;
    key_valid <= 1'b1;
    phv_in <= {48'hffffffffffff, 1076'b0};
    #CYCLE 
    extract_key <= 197'b0;
    key_valid <= 1'b0;
    phv_in <= 1124'b0;
    #(3*CYCLE)

    /* 
        TODO hit
    */
    extract_key <= 197'b0;
    key_valid <= 1'b1;
    phv_in <= {48'hffffffffffff, 1076'b0};
    #CYCLE 
    extract_key <= 197'b0;
    key_valid <= 1'b0;
    phv_in <= 1124'b0;
    #(3*CYCLE)

    /* 
        TODO miss
    */
    extract_key <= 197'b0;
    key_valid <= 1'b1;
    phv_in <= {48'hffffffffffff, 1076'b0};
    #CYCLE 
    extract_key <= 197'b0;
    key_valid <= 1'b0;
    phv_in <= 1124'b0;
    #(3*CYCLE);


end

lookup_engine#(
    .STAGE(),
    .PHV_LEN(),
    .KEY_LEN(),
    .ACT_LEN()
)lookup_engine(
    .clk(clk),
    .rst_n(rst_n),

    //output from key extractor
    .extract_key(extract_key),
    .key_valid(key_valid),
    .phv_in(phv_in),

    //output to the action engine
    .action(action),
    .action_valid(action_valid),
    .phv_out(phv_out),

    //control channel
    .lookup_din(),
    .lookup_din_mask(),
    .lookup_din_addr(),
    .lookup_din_en(),

    //control channel (action ram)
    .action_data_in(),
    .action_en(),
    .action_addr()
);

endmodule