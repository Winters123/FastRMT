/****************************************************/
//	Module name: lookup_engine.v
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/24
//	Function outline: perform match action with 197b key
/****************************************************/

`timescale 1ns / 1ps

module lookup_engine #(
    parameter STAGE = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    parameter ACT_LEN = 25
)
(
    input clk,
    input rst_n,

    //output from key extractor
    //output from key extractor
    input [KEY_LEN-1:0]           extract_key,
    input                         key_valid,
    input [PHV_LEN-1:0]           phv_in,

    //output to the action engine
    output reg [ACT_LEN*25-1:0]   action,
    output reg                    action_valid,
    output reg [PHV_LEN-1:0]      phv_out, 

    //control channel
    input [1023:0]                lookup_din,
    input [1023:0]                lookup_din_mask,
    input [3:0]                   lookup_din_addr,
    input                         lookup_din_en,

    //control channel (action ram)
    input [ACT_LEN*25-1:0]        action_data_in,
    input                         action_en,
    input [3:0]                   action_addr

);

/********intermediate variables declared here********/
wire [3:0]  match_addr;
wire        match;

wire [ACT_LEN*25-1:0] action_wire;


reg [PHV_LEN-1:0] phv_reg;
reg [1:0] lookup_state;

/********intermediate variables declared here********/

//here, the output should be controlled.
localparam IDLE_S = 2'd0,
           WAIT1_S = 2'd1,
           WAIT2_S = 2'd2,
           TRANS_S = 2'd3;

always @(posedge clk or negedge rst_n) begin

    if (~rst_n) begin
        phv_reg <= 0;
        action_valid <= 1'b0;
        lookup_state <= IDLE_S;
        action <= 0;
        phv_out <= 0;
    end

    else begin
        case(lookup_state)
            IDLE_S: begin
                //wait 3 cycles
                action_valid <= 1'b0;
                if(key_valid == 1'b1) begin
                    phv_reg <= phv_in;
                    lookup_state <= WAIT1_S;
                end
                else begin
                    lookup_state <= IDLE_S;
                end
            end

            WAIT1_S: begin
                //TCAM missed
                if(match == 1'b0) begin

                    action <= 625'h3f; //0x3f represents default action
                    action_valid <= 1'b1;
                    phv_out <= phv_reg;
                    lookup_state <= IDLE_S;
                end
                //TCAM hit
                else begin
                    lookup_state <= WAIT2_S;
                end
            end

            //wait a cycle for action to come out;
            WAIT2_S: begin
                lookup_state <= TRANS_S;
            end

            TRANS_S: begin
                action <= action_wire;
                action_valid <= 1'b1;
                phv_out <= phv_reg;

                lookup_state <= IDLE_S;
            end
            
        endcase
        if(key_valid == 1'b1) begin
            phv_reg <= phv_in;
        end
    end
end


//TODO control channel (maybe future?)



// tcam1 for lookup

cam_top # ( 
	.C_DEPTH			(16),
	// .C_WIDTH			(256),
	.C_WIDTH			(197),
	.C_MEM_INIT			(1),
	.C_MEM_INIT_FILE	("./cam_init_file.mif")
)
//TODO remember to change it back.
cam_0
(
	.CLK				(clk),
	// .CMP_DIN			({59'b0,extract_key}),
	.CMP_DIN			(extract_key),
	// .CMP_DATA_MASK		(256'h0),
	//.CMP_DATA_MASK		({256'b0}),
	.CMP_DATA_MASK		(),
	// .BUSY				(busy),
	.BUSY				(),
	.MATCH				(match),
	.MATCH_ADDR			(match_addr),

	//.WE				(lookup_din_en),
	//.WR_ADDR			(lookup_din_addr),
	//.DATA_MASK		(lookup_din_mask),  
	//.DIN				(lookup_din),

    .WE                 (),
    .WR_ADDR            (),
    .DATA_MASK          (),  //TODO du we need ternary matching?
    .DIN                (),
	.EN					(1'b1)
);


//ram for action
// blk_mem_gen_1 #(
// 	.C_INIT_FILE_NAME	("./llup.mif"),
// 	.C_LOAD_INIT_FILE	(1)
// )
blk_mem_gen_1
act_ram_625w_16d
(
    .addra(action_addr),
    .clka(clk),
    .dina(action_data_in),
    .ena(1'b1),
    .wea(action_en),

    .addrb(match_addr),
    .clkb(clk),
    .doutb(action_wire),
    .enb(match)
);

endmodule
