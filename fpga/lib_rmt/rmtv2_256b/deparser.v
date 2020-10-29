`timescale 1ns / 1ps

`define SUB_DEPARSE(idx) \
	if(parse_action[idx][0]) begin \
		case(sub_depar_val_out_type[idx]) \
			2'b01: pkts_tdata_stored_r[parse_action_ind[idx]<<3 +: 16] = sub_depar_val_out[idx][15:0]; \
			2'b10: pkts_tdata_stored_r[parse_action_ind[idx]<<3 +: 32] = sub_depar_val_out[idx][31:0]; \
			2'b11: pkts_tdata_stored_r[parse_action_ind[idx]<<3 +: 48] = sub_depar_val_out[idx][47:0]; \
		endcase \
	end \

module deparser #(
	//in corundum with 100g ports, data width is 512b
	parameter	C_AXIS_DATA_WIDTH = 256,
	parameter	C_AXIS_TUSER_WIDTH = 128,
	parameter	C_PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256
)
(
	input									clk,
	input									aresetn,

	input [C_AXIS_DATA_WIDTH-1:0]			pkt_fifo_tdata,
	input [C_AXIS_DATA_WIDTH/8-1:0]			pkt_fifo_tkeep,
	input [C_AXIS_TUSER_WIDTH-1:0]			pkt_fifo_tuser,
	// input									pkt_fifo_tvalid,
	input									pkt_fifo_tlast,
	input									pkt_fifo_empty,
	//TODO might want to change it back
	output reg							    pkt_fifo_rd_en,

	input [C_PKT_VEC_WIDTH-1:0]				phv_fifo_out,
	input									phv_fifo_empty,
	output reg								phv_fifo_rd_en,

	output reg [C_AXIS_DATA_WIDTH-1:0]		depar_out_tdata,
	output reg [C_AXIS_DATA_WIDTH/8-1:0]	depar_out_tkeep,
	output reg [C_AXIS_TUSER_WIDTH-1:0]		depar_out_tuser,
	output reg								depar_out_tvalid,
	output reg								depar_out_tlast,
	input									depar_out_tready
);


//=====================================deparser part
localparam WAIT_TILL_PARSE_DONE = 0; 
localparam WAIT_PKT_1 = 1;
localparam WAIT_PKT_2 = 2;
localparam WAIT_PKT_3 = 3;
localparam BEGIN_SUB_DEPARSER = 4;
localparam FINISH_SUB_DEPARSER = 5;

localparam FLUSH_PKT_0 = 44;
localparam FLUSH_PKT_1 = 45;
localparam FLUSH_PKT_2 = 46;
localparam FLUSH_PKT_3 = 47;
localparam FLUSH_PKT = 48;

reg [4*C_AXIS_DATA_WIDTH-1:0]		pkts_tdata_stored_r;
reg [4*C_AXIS_DATA_WIDTH-1:0]		pkts_tdata_stored;
reg [4*C_AXIS_TUSER_WIDTH-1:0]		pkts_tuser_stored_r;
reg [4*C_AXIS_TUSER_WIDTH-1:0]		pkts_tuser_stored;
reg [4*(C_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored_r;
reg [4*(C_AXIS_DATA_WIDTH/8)-1:0]	pkts_tkeep_stored;
reg [4:0]							pkts_tlast_stored_r;
reg [4:0]							pkts_tlast_stored;

reg [7:0] state, state_next;

reg [11:0] vlan_id; // vlan id
wire [259:0] bram_out;
wire [6:0] parse_action_ind [0:9];

wire [15:0] parse_action [0:9];		// we have 10 parse action


assign parse_action[9] = bram_out[100+:16];
assign parse_action[8] = bram_out[116+:16];
assign parse_action[7] = bram_out[132+:16];
assign parse_action[6] = bram_out[148+:16];
assign parse_action[5] = bram_out[164+:16];
assign parse_action[4] = bram_out[180+:16];
assign parse_action[3] = bram_out[196+:16];
assign parse_action[2] = bram_out[212+:16];
assign parse_action[1] = bram_out[228+:16];
assign parse_action[0] = bram_out[244+:16];

assign parse_action_ind[0] = parse_action[0][12:6];
assign parse_action_ind[1] = parse_action[1][12:6];
assign parse_action_ind[2] = parse_action[2][12:6];
assign parse_action_ind[3] = parse_action[3][12:6];
assign parse_action_ind[4] = parse_action[4][12:6];
assign parse_action_ind[5] = parse_action[5][12:6];
assign parse_action_ind[6] = parse_action[6][12:6];
assign parse_action_ind[7] = parse_action[7][12:6];
assign parse_action_ind[8] = parse_action[8][12:6];
assign parse_action_ind[9] = parse_action[9][12:6];

localparam PHV_2B_START_POS = 20*5+256;
localparam PHV_4B_START_POS = 20*5+256+16*8;
localparam PHV_6B_START_POS = 20*5+256+16*8+32*8;

reg	[C_PKT_VEC_WIDTH-1:0]	sub_depar_phv_fifo_out_r;
reg	[9:0]					sub_depar_act_valid;
reg	[9:0]					sub_depar_act_valid_nxt;
reg [9:0]					sub_depar_phv_in_valid;
reg [9:0]					sub_depar_phv_in_valid_nxt;
reg [5:0]					sub_depar_act[0:9];

wire [47:0]					sub_depar_val_out [0:9];
wire [1:0]					sub_depar_val_out_type [0:9];
wire [9:0]					sub_depar_val_out_valid;

always @(*) begin

	// remember to set depar_out_tdata, tuser, tkeep, tlast, tvalid
	depar_out_tdata = pkt_fifo_tdata;
	depar_out_tuser = pkt_fifo_tuser;
	depar_out_tkeep = pkt_fifo_tkeep;
	depar_out_tlast = pkt_fifo_tlast;
	depar_out_tvalid = 0;
	// fifo rd signals
	pkt_fifo_rd_en = 0;
	phv_fifo_rd_en = 0;

	pkts_tdata_stored_r = pkts_tdata_stored;
	pkts_tuser_stored_r = pkts_tuser_stored;
	pkts_tkeep_stored_r = pkts_tkeep_stored;
	pkts_tlast_stored_r = pkts_tlast_stored;

	sub_depar_act_valid = 10'b0;
	sub_depar_phv_fifo_out_r = phv_fifo_out;

	state_next = state;
	//
	case (state)
		WAIT_TILL_PARSE_DONE: begin // later will be modifed to PROCESSING done
			if (!pkt_fifo_empty && !phv_fifo_empty) begin // both pkt and phv fifo are not empty
				pkts_tdata_stored_r[0+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
				pkts_tuser_stored_r[0+:C_AXIS_TUSER_WIDTH] = phv_fifo_out[0+:128]; // first 128b of PHV
				pkts_tkeep_stored_r[0+:(C_AXIS_DATA_WIDTH/8)] = pkt_fifo_tuser;
				pkts_tlast_stored_r[0] = pkt_fifo_tlast;
				
				pkt_fifo_rd_en = 1;

				vlan_id = phv_fifo_out[129+:12];
				state_next = WAIT_PKT_1;

			end
		end
		WAIT_PKT_1: begin
			pkts_tdata_stored_r[(C_AXIS_DATA_WIDTH*1)+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
			pkts_tuser_stored_r[(C_AXIS_TUSER_WIDTH*1)+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
			pkts_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8*1)+:(C_AXIS_DATA_WIDTH/8)] = pkt_fifo_tkeep;
			pkts_tlast_stored_r[1] = pkt_fifo_tlast;

			pkt_fifo_rd_en = 1;

			if (pkt_fifo_tlast) begin
				state_next = BEGIN_SUB_DEPARSER;
			end
			else begin
				state_next = WAIT_PKT_2;
			end

		end
		WAIT_PKT_2: begin
			pkts_tdata_stored_r[(C_AXIS_DATA_WIDTH*2)+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
			pkts_tuser_stored_r[(C_AXIS_TUSER_WIDTH*2)+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
			pkts_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8*2)+:(C_AXIS_DATA_WIDTH/8)] = pkt_fifo_tkeep;
			pkts_tlast_stored_r[2] = pkt_fifo_tlast;

			pkt_fifo_rd_en = 1;
			if (pkt_fifo_tlast) begin
				state_next = BEGIN_SUB_DEPARSER;
			end
			else begin
				state_next = WAIT_PKT_3;
			end
		end
		WAIT_PKT_3: begin
			pkts_tdata_stored_r[(C_AXIS_DATA_WIDTH*3)+:C_AXIS_DATA_WIDTH] = pkt_fifo_tdata;
			pkts_tuser_stored_r[(C_AXIS_TUSER_WIDTH*3)+:C_AXIS_TUSER_WIDTH] = pkt_fifo_tuser;
			pkts_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8*3)+:(C_AXIS_DATA_WIDTH/8)] = pkt_fifo_tkeep;
			pkts_tlast_stored_r[3] = pkt_fifo_tlast;

			pkt_fifo_rd_en = 1;
			state_next = BEGIN_SUB_DEPARSER;
		end

		BEGIN_SUB_DEPARSER: begin
			sub_depar_act_valid = 10'b1111111111;

			sub_depar_act[0] = parse_action[0][5:0];
			sub_depar_act[1] = parse_action[1][5:0];
			sub_depar_act[2] = parse_action[2][5:0];
			sub_depar_act[3] = parse_action[3][5:0];
			sub_depar_act[4] = parse_action[4][5:0];
			sub_depar_act[5] = parse_action[5][5:0];
			sub_depar_act[6] = parse_action[6][5:0];
			sub_depar_act[7] = parse_action[7][5:0];
			sub_depar_act[8] = parse_action[8][5:0];
			sub_depar_act[9] = parse_action[9][5:0];

			state_next = FINISH_SUB_DEPARSER;
		end

		FINISH_SUB_DEPARSER: begin
			`SUB_DEPARSE(0)
			`SUB_DEPARSE(1)
			`SUB_DEPARSE(2)
			`SUB_DEPARSE(3)
			`SUB_DEPARSE(4)
			`SUB_DEPARSE(5)
			`SUB_DEPARSE(6)
			`SUB_DEPARSE(7)
			`SUB_DEPARSE(8)
			`SUB_DEPARSE(9)

			state_next = FLUSH_PKT_0;
		end

		FLUSH_PKT_0: begin
			phv_fifo_rd_en = 1;
			depar_out_tdata = pkts_tdata_stored[(C_AXIS_DATA_WIDTH*0)+:C_AXIS_DATA_WIDTH];
			depar_out_tuser = pkts_tuser_stored[(C_AXIS_TUSER_WIDTH*0)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep = pkts_tkeep_stored[(C_AXIS_DATA_WIDTH/8*0)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast = pkts_tlast_stored[0];
			depar_out_tvalid = 1;

			if (depar_out_tready) begin
				if (pkts_tlast_stored[0]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_1;
				end
			end
		end

		FLUSH_PKT_1: begin
			depar_out_tdata = pkts_tdata_stored[(C_AXIS_DATA_WIDTH*1)+:C_AXIS_DATA_WIDTH];
			depar_out_tuser = pkts_tuser_stored[(C_AXIS_TUSER_WIDTH*1)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep = pkts_tkeep_stored[(C_AXIS_DATA_WIDTH/8*1)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast = pkts_tlast_stored[1];
			depar_out_tvalid = 1;

			if (depar_out_tready) begin
				if (pkts_tlast_stored[1]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_2;
				end
			end
		end
		FLUSH_PKT_2: begin
			depar_out_tdata = pkts_tdata_stored[(C_AXIS_DATA_WIDTH*2)+:C_AXIS_DATA_WIDTH];
			depar_out_tuser = pkts_tuser_stored[(C_AXIS_TUSER_WIDTH*2)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep = pkts_tkeep_stored[(C_AXIS_DATA_WIDTH/8*2)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast = pkts_tlast_stored[2];
			depar_out_tvalid = 1;

			if (depar_out_tready) begin
				if (pkts_tlast_stored[2]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT_3;
				end
			end
		end
		FLUSH_PKT_3: begin
			depar_out_tdata = pkts_tdata_stored[(C_AXIS_DATA_WIDTH*3)+:C_AXIS_DATA_WIDTH];
			depar_out_tuser = pkts_tuser_stored[(C_AXIS_TUSER_WIDTH*3)+:C_AXIS_TUSER_WIDTH];
			depar_out_tkeep = pkts_tkeep_stored[(C_AXIS_DATA_WIDTH/8*3)+:(C_AXIS_DATA_WIDTH/8)];
			depar_out_tlast = pkts_tlast_stored[3];
			depar_out_tvalid = 1;

			if (depar_out_tready) begin
				if (pkts_tlast_stored[3]) begin
					state_next = WAIT_TILL_PARSE_DONE;
				end
				else begin
					state_next = FLUSH_PKT;
				end
			end
		end
		FLUSH_PKT: begin
			if (!pkt_fifo_empty) begin
				depar_out_tvalid = pkt_fifo_tdata;
				depar_out_tuser =  pkt_fifo_tuser;
				depar_out_tkeep =  pkt_fifo_tkeep;
				depar_out_tlast =  pkt_fifo_tlast;
				depar_out_tvalid = 1;
				if(depar_out_tready) begin
					pkt_fifo_rd_en = 1;
					if (pkt_fifo_tlast) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = FLUSH_PKT;
					end
				end
			end
		end
	endcase
end

always @(posedge clk) begin
	if (~aresetn) begin
		state <= WAIT_TILL_PARSE_DONE;

		pkts_tdata_stored <= 0;
		pkts_tuser_stored <= 0;
		pkts_tkeep_stored <= 0;
		pkts_tlast_stored <= 0;

	end
	else begin
		state <= state_next;

		pkts_tdata_stored <= pkts_tdata_stored_r;
		pkts_tuser_stored <= pkts_tuser_stored_r;
		pkts_tkeep_stored <= pkts_tkeep_stored_r;
		pkts_tlast_stored <= pkts_tlast_stored_r;

	end
end

generate
	genvar index;
	for (index=0; index<10; index=index+1) 
	begin: sub_op
		sub_deparser #(
			.C_PKT_VEC_WIDTH(),
			.C_PARSE_ACT_LEN()
		)
		sub_deparser (
			.clk				(clk),
			.aresetn			(aresetn),
			.parse_act_valid	(sub_depar_act_valid[index]),
			.parse_act			(sub_depar_act[index]),
			.phv_in				(sub_depar_phv_fifo_out_r),
			.val_out_valid		(sub_depar_val_out_valid[index]),
			.val_out			(sub_depar_val_out[index]),
			.val_out_type		(sub_depar_val_out_type[index])
		);
	end
endgenerate


// parse_act_ram_ip #(
// 	.C_INIT_FILE_NAME	("./alu_2.mif"),
// 	.C_LOAD_INIT_FILE	(1)
// )
parse_act_ram_ip
parse_act_ram
(
	// write port
	.clka		(clk),
	.addra		(),
	.dina		(),
	.ena		(),
	.wea		(),

	//
	.clkb		(clk),
	.addrb		(vlan_id[7:4]),
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);

endmodule
