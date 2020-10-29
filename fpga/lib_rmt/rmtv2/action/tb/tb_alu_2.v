`timescale 1ns / 1ps

module tb_alu_2 #(
    parameter STAGE = 0,
    parameter ACTION_LEN = 25,
    parameter DATA_WIDTH = 32
)();


reg                             clk;
reg                             rst_n;
//input from sub_action
reg [ACTION_LEN-1:0]            action_in;
reg                             action_valid;
reg [DATA_WIDTH-1:0]            operand_1_in;
reg [DATA_WIDTH-1:0]            operand_2_in;
reg [DATA_WIDTH-1:0]            operand_3_in;

//output to form PHV
wire [DATA_WIDTH-1:0]           container_out;
wire                            container_out_valid;


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
        ADD ---> 0001
    */
    action_in <= {4'b0001, 21'b0010001001};
    action_valid <= 1'b1;
    operand_1_in <= 32'b1;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(CYCLE)
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'b0;
    #(2*CYCLE)

    /*
        SUB ---> 0010
    */
    action_in <= {4'b0010, 21'b0010001001};
    action_valid <= 1'b1;
    operand_1_in <= 32'd20;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(CYCLE)
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(2*CYCLE)

    /*
        illegitimate action
    */
    action_in <= {4'b0011, 21'b0010001001};
    action_valid <= 1'b1;
    operand_1_in <= 32'd20;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(CYCLE)
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(2*CYCLE)

    /*
        store action
    */
    action_in <= {4'b1000, 5'b00100, 16'b11111111};
    action_valid <= 1'b1;
    operand_1_in <= 32'd20;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(CYCLE)
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(2*CYCLE)

    /*
        load action
    */
    action_in <= {4'b1011, 5'b00100, 16'b11111111};
    action_valid <= 1'b1;
    operand_1_in <= 32'd20;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(CYCLE)
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(2*CYCLE)

    /*
        reset to IDLE
    */
    action_in <= 25'b0;
    action_valid <= 1'b0;
    operand_1_in <= 32'b0;
    operand_2_in <= 32'd3;
    operand_3_in <= 32'd12;
    #(2*CYCLE);
end


alu_2 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH()  //data width of the ALU
)alu_2_0(
    .clk(clk),
    .rst_n(rst_n),
    //input from sub_action
    .action_in(action_in),
    .action_valid(action_valid),
    .operand_1_in(operand_1_in),
    .operand_2_in(operand_2_in),
    .operand_3_in(operand_3_in),
    //output to form PHV
    .container_out(container_out),
    .container_out_valid(container_out_valid)
);

endmodule