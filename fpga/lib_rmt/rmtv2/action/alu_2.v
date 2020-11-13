/****************************************************/
//	Module name: alu_2
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/23
//	Function outline: 2st type ALU (with load/store) module in RMT
/****************************************************/

`timescale 1ns / 1ps

module alu_2 #(
    parameter STAGE_ID = 0,
    parameter ACTION_LEN = 25,
    parameter DATA_WIDTH = 32,  //data width of the ALU

	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128
)
(
    input clk,
    input rst_n,

    //input from sub_action
    input [ACTION_LEN-1:0]            action_in,
    input                             action_valid,
    input [DATA_WIDTH-1:0]            operand_1_in,
    input [DATA_WIDTH-1:0]            operand_2_in,
    input [DATA_WIDTH-1:0]            operand_3_in,

    //output to form PHV
    output reg [DATA_WIDTH-1:0]       container_out,
    output reg                        container_out_valid

);

/********intermediate variables declared here********/
localparam width_6B = 48;
localparam width_4B = 32;
localparam width_2B = 16;


reg  [3:0]           action_type, action_type_r;

//regs for RAM access
reg                  store_en, store_en_r;
reg  [4:0]           store_addr, store_addr_r;
reg  [31:0]          store_din,	 store_din_r;

wire [31:0]          load_data;
wire [4:0]           load_addr;

reg  [2:0]           alu_state, alu_state_next;
reg [DATA_WIDTH-1:0]		container_out_r;
reg							container_out_valid_next;


/********intermediate variables declared here********/

assign load_addr = operand_2_in[4:0];

/*
6 operations to support:

1,2. add/sub:   0001/0010
              extract 2 operands from pkt header, add(sub) and write back.

3,4. addi/subi: 1001/1010
              extract op1 from pkt header, op2 from action, add(sub) and write back.

5: load:      0101
              load data from RAM, write to pkt header according to addr in action.

6. store:     0110
              read data from pkt header, write to ram according to addr in action.
*/

localparam  IDLE_S = 3'd0,
            EMPTY_S = 3'd1,
            OUTPUT_S = 3'd2;

always @(*) begin
	alu_state_next = alu_state;

	action_type_r = action_type;
	container_out_r = container_out;
	container_out_valid_next = 0;

	store_en_r = store_en;
	store_addr_r = store_addr;
	store_din_r = store_din;
	
	case (alu_state_next)
		IDLE_S: begin
			if (action_valid) begin
				action_type_r = action_in[24:21];
				alu_state_next = EMPTY_S;
                case(action_in[24:21])
                    //add/addi ops 
                    4'b0001, 4'b1001: begin
                        container_out_r = operand_1_in + operand_2_in;
                    end 
                    //sub/subi ops
                    4'b0010, 4'b1010: begin
                        container_out_r = operand_1_in - operand_2_in;
                    end
                    //store op (interact with RAM)
                    4'b1000: begin
                        container_out_r = operand_3_in;
                        store_en_r = 1;
                        store_addr_r = operand_2_in[4:0];
                        store_din_r = operand_1_in;
                    end
                    //load op (interact with RAM)
                    4'b1011: begin
						// do nothing now
                    end
                    //cannot go back to IDLE since this
                    //might be a legal action.
                    default: begin
                        container_out_r = operand_3_in;
                    end
				endcase
			end
		end
		EMPTY_S: begin
			// an empty cycle
            alu_state_next = OUTPUT_S;
        end
        OUTPUT_S: begin
			// load data is ready
            // output the value
			container_out_valid_next = 1;
            if(action_type == 4'b1011) begin
                container_out_r = load_data;
            end

            alu_state_next = IDLE_S;

			// clear out store signals
			store_en_r = 0;
			store_addr_r = 0;
			store_din_r = 0;
        end
	endcase
end

always @(posedge clk) begin
	if (~rst_n) begin
		alu_state <= IDLE_S;

		action_type <= 0;
		container_out <= 0;
		container_out_valid <= 0;

		store_en <= 0;
		store_addr <= 0;
		store_din <= 0;
	end
	else begin
		alu_state <= alu_state_next;
		action_type <= action_type_r;
		container_out <= container_out_r;
		container_out_valid <= container_out_r;

		store_en <= store_en_r;
		store_addr <= store_addr_r;
		store_din <= store_din_r;
	end
end


//ram for key-value
//2 cycles to get value
// blk_mem_gen_0 # (
// 	.C_INIT_FILE_NAME	("./alu_2.mif"),
// 	.C_LOAD_INIT_FILE	(1)
// )
blk_mem_gen_0
data_ram_32w_32d
(
    //store-related
    .addra(store_addr),
    .clka(clk),
    .dina(store_din),
    .ena(1'b1),
    .wea(store_en),

    //load-related
    .addrb(load_addr),
    .clkb(clk),
    .doutb(load_data),
    .enb(1'b1)
);

endmodule
