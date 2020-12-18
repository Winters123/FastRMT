/****************************************************/
//	Module name: alu_3
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/25
//	Function outline: 3rd type ALU (metadata modification) in RMT
/****************************************************/
`timescale 1ns / 1ps
module alu_3 #(
    parameter STAGE_ID = 0,
    parameter ACTION_LEN = 25,
    parameter META_LEN = 256,
    parameter COMP_LEN = 100
)(
    input                               clk,
    input                               rst_n,
    //the input data shall be metadata & com_ins
    input [META_LEN+COMP_LEN-1:0]       comp_meta_data_in,
    input                               comp_meta_data_valid_in,
    input [ACTION_LEN-1:0]              action_in,
    input                               action_valid_in,

    //output is the modified metadata plus comp_ins
    output reg [META_LEN+COMP_LEN-1:0]  comp_meta_data_out,
    output reg                          comp_meta_data_valid_out     
);

//need delay for one cycle before the result pushed out
/*
action format:
    [24:20]: opcode;
    [19:12]: dst_port;
    [11]:    discard_flag;
    [10:5]:  next_table_id;
    [4:0]:   reserverd_bit;
*/
/*
metadata fields that are related:
    TODO: next table id is not supported yet.
    [255:250]: next_table_id;
    [249:129]: reservered for other use;
    [128]:     discard_field;
    [127:0]:   copied from NetFPGA's md;
    
*/

localparam IDLE_S=3'd0,
		   WAIT1_S=3'd1,
		   WAIT2_S=3'd2, 
		   WAIT3_S=3'd3, 
		   OUTPUT_S=3'd4;

reg [2:0]						state, state_next;
reg [META_LEN+COMP_LEN-1:0]		comp_meta_data_out_r;
reg								comp_meta_data_valid_next;

always @(*) begin
	state_next = state;
	comp_meta_data_out_r = comp_meta_data_out;
	comp_meta_data_valid_next = 0;

	case (state)
		IDLE_S: begin
			if (action_valid_in) begin
				state_next = WAIT1_S;
				case(action_in[24:21])
            	    4'b1100: begin
            	        comp_meta_data_out_r[355:32] = {action_in[10:5],comp_meta_data_in[349:32]};
            	        comp_meta_data_out_r[31:24]  = action_in[20:13];
            	        comp_meta_data_out_r[23:0]   = comp_meta_data_in[23:0];
            	    end
            	    4'b1101: begin
            	        comp_meta_data_out_r[355:129] = {action_in[10:5],comp_meta_data_in[349:129]};
            	        comp_meta_data_out_r[128] = action_in[12];
            	        comp_meta_data_out_r[127:0] = comp_meta_data_in[127:0];
            	    end
            	    default: begin
            	        comp_meta_data_out_r = comp_meta_data_in;
            	    end
            	endcase
			end
		end
		WAIT1_S: begin
			// empty cycle
			state_next = WAIT2_S;
		end
		WAIT2_S: begin
			state_next = WAIT3_S;
		end
		WAIT3_S: begin
			state_next = OUTPUT_S;
		end
		OUTPUT_S: begin
			comp_meta_data_valid_next = 1;
			state_next = IDLE_S;
		end
	endcase
end

always @(posedge clk) begin
	if (~rst_n) begin
		comp_meta_data_out <= 0;
		comp_meta_data_valid_out <= 0;
		state <= IDLE_S;
	end
	else begin
		state <= state_next;
		comp_meta_data_out <= comp_meta_data_out_r;
		comp_meta_data_valid_out <= comp_meta_data_valid_next;
	end
end

endmodule
