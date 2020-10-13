`timescale 1ns / 1ps

module tb_action_engine #(
    parameter STAGE = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter ACT_LEN = 25
)();

reg         clk;
reg         rst_n;
//signals from lookup to ALUs
reg [PHV_LEN-1:0]       phv_in;
reg                     phv_valid_in;
reg [ACT_LEN*25-1:0]    action_in;
reg                     action_valid_in;
//signals output from ALUs
wire [PHV_LEN-1:0]      phv_out;
wire                    phv_valid_out;

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
    #(2*CYCLE); //after the rst_n, start the test
    #(5) //posedge of clk    
    /*
        setup new
    */
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;

    #(2*CYCLE)

    /*
        extract values from PHV
    */
    phv_in <= {48'h111111111111,48'h222222222222,172'b1,100'hfffffffffffffffffffffffff,400'b0,356'b0};
    phv_valid_in <= 1'b1;
    //switch the con_6B_7 with con_6B_6
    // action_in <= {4'b0001, 5'd6, 5'd7, 11'b0, 600'b0};
    action_in <= 625'b0;
    action_valid_in <= 1'b1;
    #(CYCLE)
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;
    #(2*CYCLE)
    /*
        extract values from imm
    */
    phv_in <= {48'hffffffffffff,48'heeeeeeeeeeee,672'b0,356'b0};
    phv_valid_in <= 1'b1;
    //switch the con_6B_7 with con_6B_6
    action_in <= {4'b1010, 5'd6, 16'hffff, 600'b0};
    action_valid_in <= 1'b1;
    #(CYCLE)
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;
    #(2*CYCLE)

    /*
        test store action
    */
    phv_in <= {384'b0,32'hffffffff,224'b0,128'b0,356'b0};
    phv_valid_in <= 1'b1;
    //switch the con_6B_7 with con_6B_6
    action_in <= {200'b0,4'b1000, 5'd7,16'd7,400'b0};
    action_valid_in <= 1'b1;
    #(CYCLE)
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;
    #(2*CYCLE)

    /*
        empty actions to take (return the original value)
    */
    phv_in <= {48'hffffffffffff,48'heeeeeeeeeeee,672'b0,356'b0};
    phv_valid_in <= 1'b1;
    //this is an invalid action
    action_in <= {4'b0000, 5'd6, 16'hffff, 600'b0};
    action_valid_in <= 1'b1;
    #(CYCLE)
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;
    #(2*CYCLE)

    //reset to zeros.
    phv_in <= 1124'b0;
    phv_valid_in <= 1'b0;
    action_in <= 625'b0;
    action_valid_in <= 1'b0;

    #(2*CYCLE);
end


action_engine #(
    .STAGE(STAGE),
    .PHV_LEN(),
    .ACT_LEN()
)action_engine(
    .clk(clk),
    .rst_n(rst_n),

    //signals from lookup to ALUs
    .phv_in(phv_in),
    .phv_valid_in(phv_valid_in),
    .action_in(action_in),
    .action_valid_in(action_valid_in),

    //signals output from ALUs
    .phv_out(phv_out),
    .phv_valid_out(phv_valid_out)
);
endmodule