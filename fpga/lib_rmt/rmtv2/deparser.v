`timescale 1ns / 1ps

module deparser #(
	//in corundum with 100g ports, data width is 512b
	parameter	C_S_AXIS_DATA_WIDTH = 512,
	parameter	C_S_AXIS_TUSER_WIDTH = 128,
	parameter	C_PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256,
    parameter   DEPARSER_ID = 3'b101
)
(
	input									clk,
	input									aresetn,

	input [C_S_AXIS_DATA_WIDTH-1:0]			pkt_fifo_tdata,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		pkt_fifo_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		pkt_fifo_tuser,
	// input								pkt_fifo_tvalid,
	input									pkt_fifo_tlast,
	input									pkt_fifo_empty,
	output reg							    pkt_fifo_rd_en,

	input [C_PKT_VEC_WIDTH-1:0]				phv_fifo_out,
	input									phv_fifo_empty,
	output reg								phv_fifo_rd_en,

	output reg [C_S_AXIS_DATA_WIDTH-1:0]	depar_out_tdata,
	output reg [C_S_AXIS_DATA_WIDTH/8-1:0]	depar_out_tkeep,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]	depar_out_tuser,
	output reg								depar_out_tvalid,
	output reg								depar_out_tlast,
	input									depar_out_tready,

    //control path
    input [C_S_AXIS_DATA_WIDTH-1:0]			c_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		c_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		c_s_axis_tkeep,
	input									c_s_axis_tvalid,
	input									c_s_axis_tlast

);

wire  [11:0]   vlan_id;

wire [259:0]  bram_out;

// wire [6:0]    parse_action_ind [0:9];
// wire [15:0]   parse_action [0:9];		// we have 10 parse action
reg  [15:0]   parse_action[0:9];
reg  [6:0]    parse_action_ind [0:9];

assign vlan_id = phv_fifo_out[129+:12];

always @(posedge clk) begin
    // vlan_id <= phv_fifo_out[129+:12];
    parse_action[9] <= bram_out[100+:16];
    parse_action[8] <= bram_out[116+:16];
    parse_action[7] <= bram_out[132+:16];
    parse_action[6] <= bram_out[148+:16];
    parse_action[5] <= bram_out[164+:16];
    parse_action[4] <= bram_out[180+:16];
    parse_action[3] <= bram_out[196+:16];
    parse_action[2] <= bram_out[212+:16];
    parse_action[1] <= bram_out[228+:16];
    parse_action[0] <= bram_out[244+:16];
    parse_action_ind[0] <= parse_action[0][12:6];
    parse_action_ind[1] <= parse_action[1][12:6];
    parse_action_ind[2] <= parse_action[2][12:6];
    parse_action_ind[3] <= parse_action[3][12:6];
    parse_action_ind[4] <= parse_action[4][12:6];
    parse_action_ind[5] <= parse_action[5][12:6];
    parse_action_ind[6] <= parse_action[6][12:6];
    parse_action_ind[7] <= parse_action[7][12:6];
    parse_action_ind[8] <= parse_action[8][12:6];
    parse_action_ind[9] <= parse_action[9][12:6];
end




/*********************************state***************************************/
localparam PHV_2B_START_POS = 20*5+256;
localparam PHV_4B_START_POS = 20*5+256+16*8;
localparam PHV_6B_START_POS = 20*5+256+16*8+32*8;

reg  [9:0]  deparse_state;

localparam  IDLE_S = 10'd0,
            BUF_HDR_0 = 10'd1,
            BUF_HDR_1 = 10'd2,
            WAIT_ONE = 10'd3,
            WAIT_SUB = 10'd4,
            REFORM_HDR = 10'd5,
            FLUSH_PKT_0 = 10'd6,
            FLUSH_PKT_1 = 10'd7,
            FLUSH_PKT = 10'd8;


reg [2*C_S_AXIS_DATA_WIDTH-1:0]		 deparse_tdata_stored_r;
reg [2*C_S_AXIS_TUSER_WIDTH-1:0]	 deparse_tuser_stored_r;
reg [2*(C_S_AXIS_DATA_WIDTH/8)-1:0]	 deparse_tkeep_stored_r;
reg [1:0]							 deparse_tlast_stored_r;
reg [C_PKT_VEC_WIDTH-1:0]            deparse_phv_stored_r;

integer i;

/**
divide and conquar (below)
*/

genvar index;

localparam C_PARSE_ACTION_LEN = 6;

reg [9:0]                    deparse_phv_reg_valid_in;
reg [9:0]                    sub_parse_action_valid_in;

//output from sub_deparser
wire [47:0]                  dp_val_BE[0:9];
wire [1:0]                   deparse_phv_select[0:9];
wire [9:0]                   valid_out;

//BE LE switching

wire [47:0]                 dp_val_LE[0:9];

assign dp_val_LE[0] = {dp_val_BE[0][7:0], dp_val_BE[0][15:8], dp_val_BE[0][23:16], dp_val_BE[0][31:24], dp_val_BE[0][39:32], dp_val_BE[0][47:40]};
assign dp_val_LE[1] = {dp_val_BE[1][7:0], dp_val_BE[1][15:8], dp_val_BE[1][23:16], dp_val_BE[1][31:24], dp_val_BE[1][39:32], dp_val_BE[1][47:40]};
assign dp_val_LE[2] = {dp_val_BE[2][7:0], dp_val_BE[2][15:8], dp_val_BE[2][23:16], dp_val_BE[2][31:24], dp_val_BE[2][39:32], dp_val_BE[2][47:40]};
assign dp_val_LE[3] = {dp_val_BE[3][7:0], dp_val_BE[3][15:8], dp_val_BE[3][23:16], dp_val_BE[3][31:24], dp_val_BE[3][39:32], dp_val_BE[3][47:40]};
assign dp_val_LE[4] = {dp_val_BE[4][7:0], dp_val_BE[4][15:8], dp_val_BE[4][23:16], dp_val_BE[4][31:24], dp_val_BE[4][39:32], dp_val_BE[4][47:40]};
assign dp_val_LE[5] = {dp_val_BE[5][7:0], dp_val_BE[5][15:8], dp_val_BE[5][23:16], dp_val_BE[5][31:24], dp_val_BE[5][39:32], dp_val_BE[5][47:40]};
assign dp_val_LE[6] = {dp_val_BE[6][7:0], dp_val_BE[6][15:8], dp_val_BE[6][23:16], dp_val_BE[6][31:24], dp_val_BE[6][39:32], dp_val_BE[6][47:40]};
assign dp_val_LE[7] = {dp_val_BE[7][7:0], dp_val_BE[7][15:8], dp_val_BE[7][23:16], dp_val_BE[7][31:24], dp_val_BE[7][39:32], dp_val_BE[7][47:40]};
assign dp_val_LE[8] = {dp_val_BE[8][7:0], dp_val_BE[8][15:8], dp_val_BE[8][23:16], dp_val_BE[8][31:24], dp_val_BE[8][39:32], dp_val_BE[8][47:40]};
assign dp_val_LE[9] = {dp_val_BE[9][7:0], dp_val_BE[9][15:8], dp_val_BE[9][23:16], dp_val_BE[9][31:24], dp_val_BE[9][39:32], dp_val_BE[9][47:40]};


always @(posedge clk or negedge aresetn) begin
    if(~aresetn) begin
        depar_out_tdata <= 0;
        depar_out_tkeep <= 0;
        depar_out_tuser <= 0;
        depar_out_tvalid <= 0;
        depar_out_tlast <= 0;

        pkt_fifo_rd_en <= 1'b0;
        phv_fifo_rd_en <= 1'b0;

        deparse_phv_reg_valid_in <= 10'b0;
        sub_parse_action_valid_in <= 10'b0;

        deparse_phv_stored_r <= 0;

        deparse_state <= IDLE_S;
    end

    else begin
        case(deparse_state)
            IDLE_S: begin
                //if there is work to do:
                if(!phv_fifo_empty && !pkt_fifo_empty) begin
                    // deparse_phv_stored_r <= phv_fifo_out;

                    // deparse_tdata_stored_r[C_S_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                    // deparse_tuser_stored_r[C_S_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                    // deparse_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
                    // deparse_tlast_stored_r[0] <= pkt_fifo_tlast;

                    pkt_fifo_rd_en <= 1'b1;
                    
                    // if(pkt_fifo_tlast) begin
                    //     //TODO needs to wait for the RAM
                    //     deparse_state <= WAIT_ONE;
                    // end

                    // else begin
                    //     deparse_state <= BUF_HDR_0;
                    // end
                    deparse_state <= BUF_HDR_0;

                end
                else begin
                    // depar_out_tdata <= 0;
                    depar_out_tkeep <= 0;
                    depar_out_tuser <= 0;
                    depar_out_tvalid <= 0;
                    depar_out_tlast <= 0;

                    pkt_fifo_rd_en <= 1'b0;
                    phv_fifo_rd_en <= 1'b0;

                    deparse_phv_reg_valid_in <= 10'b0;
                    sub_parse_action_valid_in <= 10'b0;

                    deparse_state <= IDLE_S;
                end
            end
            
            BUF_HDR_0: begin
                deparse_phv_stored_r <= phv_fifo_out;
                deparse_phv_reg_valid_in <= 10'b1111111111;
                

                deparse_tdata_stored_r[C_S_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                deparse_tuser_stored_r[C_S_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                deparse_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
                deparse_tlast_stored_r[0] <= pkt_fifo_tlast;

                pkt_fifo_rd_en <= 1'b1;
                    
                if(pkt_fifo_tlast) begin
                    deparse_state <= WAIT_ONE;
                end

                else begin
                    deparse_state <= BUF_HDR_1;
                end
            end

            BUF_HDR_1: begin
                deparse_tdata_stored_r[2*C_S_AXIS_DATA_WIDTH-1:C_S_AXIS_DATA_WIDTH] <= pkt_fifo_tdata;
                deparse_tuser_stored_r[2*C_S_AXIS_TUSER_WIDTH-1:C_S_AXIS_TUSER_WIDTH] <= pkt_fifo_tuser;
                deparse_tkeep_stored_r[2*(C_S_AXIS_DATA_WIDTH/8)-1:C_S_AXIS_DATA_WIDTH/8] <= pkt_fifo_tkeep;
                deparse_tlast_stored_r[1] <= pkt_fifo_tlast;

                pkt_fifo_rd_en <= 1'b0;
                //TODO push the inputs to sub_deparser
                deparse_phv_reg_valid_in <= 10'b0;
                sub_parse_action_valid_in <= 10'b1111111111;

                deparse_state <= WAIT_SUB;

            end

            //wait one more cycle for RAM read
            WAIT_ONE: begin
                pkt_fifo_rd_en <= 1'b0;
                //TODO push the inputs to sub_deparser
                deparse_phv_reg_valid_in <= 10'b0;
                sub_parse_action_valid_in <= 10'b1111111111;


                deparse_state <= WAIT_SUB;
            end

            WAIT_SUB: begin
                pkt_fifo_rd_en <= 1'b0;
                //TODO push the inputs to sub_deparser
                deparse_phv_reg_valid_in <= 10'b0;
                sub_parse_action_valid_in <= 10'b0;

                deparse_state <= REFORM_HDR;
            end

            //this is the slot when we get RAM output
            //the cycle when parse_action is enabled
            REFORM_HDR: begin
                pkt_fifo_rd_en <= 1'b0;
                phv_fifo_rd_en <= 1'b1;

                sub_parse_action_valid_in <= 10'b0;
                //retrieve the data
                if(parse_action[0][0]) begin
                        case(deparse_phv_select[0]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 16] <= dp_val_BE[0][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 32] <= dp_val_BE[0][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 48] <= dp_val_BE[0][47:0];
                        endcase
                end

                if(parse_action[1][0]) begin
                        case(deparse_phv_select[1]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 16] <= dp_val_BE[1][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 32] <= dp_val_BE[1][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 48] <= dp_val_BE[1][47:0];
                        endcase
                end

                if(parse_action[2][0]) begin
                        case(deparse_phv_select[2]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 16] <= dp_val_BE[2][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 32] <= dp_val_BE[2][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 48] <= dp_val_BE[2][47:0];
                        endcase
                end

                if(parse_action[3][0]) begin
                        case(deparse_phv_select[3]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 16] <= dp_val_BE[3][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 32] <= dp_val_BE[3][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 48] <= dp_val_BE[3][47:0];
                        endcase
                end

                if(parse_action[4][0]) begin
                        case(deparse_phv_select[4]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 16] <= dp_val_BE[4][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 32] <= dp_val_BE[4][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 48] <= dp_val_BE[4][47:0];
                        endcase
                end

                if(parse_action[5][0]) begin
                        case(deparse_phv_select[5]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 16] <= dp_val_BE[5][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 32] <= dp_val_BE[5][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 48] <= dp_val_BE[5][47:0];
                        endcase

                end

                if(parse_action[6][0]) begin
                        case(deparse_phv_select[6]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 16] <= dp_val_BE[6][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 32] <= dp_val_BE[6][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 48] <= dp_val_BE[6][47:0];
                        endcase
                end

                if(parse_action[7][0]) begin
                        case(deparse_phv_select[7]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 16] <= dp_val_BE[7][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 32] <= dp_val_BE[7][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 48] <= dp_val_BE[7][47:0];
                        endcase
                    
                end

                if(parse_action[8][0]) begin
                        case(deparse_phv_select[8]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 16] <= dp_val_BE[8][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 32] <= dp_val_BE[8][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 48] <= dp_val_BE[8][47:0];
                        endcase
                end

                if(parse_action[9][0]) begin
                        case(deparse_phv_select[9]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 16] <= dp_val_BE[9][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 32] <= dp_val_BE[9][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 48] <= dp_val_BE[9][47:0];
                        endcase
                end


                deparse_state <= FLUSH_PKT_0;
            end

            FLUSH_PKT_0: begin
                phv_fifo_rd_en <= 1'b0;

                depar_out_tdata <= deparse_tdata_stored_r[C_S_AXIS_DATA_WIDTH-1:0];
                depar_out_tuser <= deparse_tuser_stored_r[C_S_AXIS_TUSER_WIDTH-1:0];
                depar_out_tkeep <= deparse_tkeep_stored_r[C_S_AXIS_DATA_WIDTH/8-1:0];
			    depar_out_tlast <= deparse_tlast_stored_r[0];
			    depar_out_tvalid = 1'b1;

                if(depar_out_tready) begin
                    if(deparse_tlast_stored_r[0]) begin
                        deparse_state <= IDLE_S;
                    end
                    else begin
                        deparse_state <= FLUSH_PKT_1;
                    end
                end
            end

            FLUSH_PKT_1: begin
                depar_out_tdata <= deparse_tdata_stored_r[(C_S_AXIS_DATA_WIDTH*1)+:C_S_AXIS_DATA_WIDTH];
                depar_out_tuser <= deparse_tuser_stored_r[(C_S_AXIS_TUSER_WIDTH*1)+:C_S_AXIS_TUSER_WIDTH];
                depar_out_tkeep <= deparse_tkeep_stored_r[(C_S_AXIS_DATA_WIDTH/8*1)+:(C_S_AXIS_DATA_WIDTH/8)];
			    depar_out_tlast <= deparse_tlast_stored_r[1];
			    depar_out_tvalid = 1'b1;

                if(depar_out_tready) begin
                    if(deparse_tlast_stored_r[1]) begin
                        deparse_state <= IDLE_S;
                    end
                    else begin
                        pkt_fifo_rd_en <= 1'b1;
                        deparse_state <= FLUSH_PKT;
                    end
                end
            end

            FLUSH_PKT: begin
                depar_out_tdata <= pkt_fifo_tdata;
                depar_out_tuser <= pkt_fifo_tuser;
                depar_out_tkeep <= pkt_fifo_tkeep;
			    depar_out_tlast <= pkt_fifo_tlast;
			    depar_out_tvalid = 1;
                if(!pkt_fifo_empty && depar_out_tready) begin

                    if(pkt_fifo_tlast) begin
                        deparse_state <= IDLE_S;
                    end
                    else begin
                        deparse_state <= FLUSH_PKT;
                    end
                end

                else begin
                    deparse_state <= IDLE_S;
                end
            end

        endcase
    end
end




generate 
    for(index=0; index<10; index = index+1)
        begin: sub_op
            sub_deparser #(
            	//in corundum with 100g ports, data width is 512b
            	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
            	.C_S_AXIS_TUSER_WIDTH(),
            	.C_PKT_VEC_WIDTH(),
                .C_PARSE_ACTION_LEN(C_PARSE_ACTION_LEN)
            )sub_deparser
            (
            	.clk(clk),
            	.aresetn(aresetn),
                .deparse_phv_reg_in(deparse_phv_stored_r[1123:356]),
                .deparse_phv_reg_valid_in(deparse_phv_reg_valid_in[index]),
                .parse_action(parse_action[index]),
                .parse_action_valid_in(sub_parse_action_valid_in[index]),
                .deparse_phv_reg_out(dp_val_BE[index]),
                .deparse_phv_select(deparse_phv_select[index]),
                .valid_out(valid_out[index])
            );
        end
endgenerate



/****control path for 512b*****/
wire [7:0]          mod_id; //module ID
wire [15:0]         control_flag; //dst udp port num
reg  [7:0]          c_index; //table index(addr)
reg                 c_wr_en; //enable table write(wen)
reg  [259:0]        entry_reg;

reg [2:0]           c_state;

localparam IDLE_C = 1,
           WRITE_C = 2;

assign mod_id = c_s_axis_tdata[368+:8];
assign control_flag = c_s_axis_tdata[335:320];
//LE to BE switching
wire[C_S_AXIS_DATA_WIDTH-1:0] c_s_axis_tdata_swapped;
assign c_s_axis_tdata_swapped = {	c_s_axis_tdata[0+:8],
									c_s_axis_tdata[8+:8],
									c_s_axis_tdata[16+:8],
									c_s_axis_tdata[24+:8],
									c_s_axis_tdata[32+:8],
									c_s_axis_tdata[40+:8],
									c_s_axis_tdata[48+:8],
									c_s_axis_tdata[56+:8],
									c_s_axis_tdata[64+:8],
									c_s_axis_tdata[72+:8],
									c_s_axis_tdata[80+:8],
									c_s_axis_tdata[88+:8],
									c_s_axis_tdata[96+:8],
									c_s_axis_tdata[104+:8],
									c_s_axis_tdata[112+:8],
									c_s_axis_tdata[120+:8],
									c_s_axis_tdata[128+:8],
									c_s_axis_tdata[136+:8],
									c_s_axis_tdata[144+:8],
									c_s_axis_tdata[152+:8],
									c_s_axis_tdata[160+:8],
									c_s_axis_tdata[168+:8],
									c_s_axis_tdata[176+:8],
									c_s_axis_tdata[184+:8],
									c_s_axis_tdata[192+:8],
									c_s_axis_tdata[200+:8],
									c_s_axis_tdata[208+:8],
									c_s_axis_tdata[216+:8],
									c_s_axis_tdata[224+:8],
									c_s_axis_tdata[232+:8],
									c_s_axis_tdata[240+:8],
									c_s_axis_tdata[248+:8],
                                    c_s_axis_tdata[256+:8],
                                    c_s_axis_tdata[264+:8],
                                    c_s_axis_tdata[272+:8],
                                    c_s_axis_tdata[280+:8],
                                    c_s_axis_tdata[288+:8],
                                    c_s_axis_tdata[296+:8],
                                    c_s_axis_tdata[304+:8],
                                    c_s_axis_tdata[312+:8],
                                    c_s_axis_tdata[320+:8],
                                    c_s_axis_tdata[328+:8],
                                    c_s_axis_tdata[336+:8],
                                    c_s_axis_tdata[344+:8],
                                    c_s_axis_tdata[352+:8],
                                    c_s_axis_tdata[360+:8],
                                    c_s_axis_tdata[368+:8],
                                    c_s_axis_tdata[376+:8],
                                    c_s_axis_tdata[384+:8],
                                    c_s_axis_tdata[392+:8],
                                    c_s_axis_tdata[400+:8],
                                    c_s_axis_tdata[408+:8],
                                    c_s_axis_tdata[416+:8],
                                    c_s_axis_tdata[424+:8],
                                    c_s_axis_tdata[432+:8],
                                    c_s_axis_tdata[440+:8],
                                    c_s_axis_tdata[448+:8],
                                    c_s_axis_tdata[456+:8],
                                    c_s_axis_tdata[464+:8],
                                    c_s_axis_tdata[472+:8],
                                    c_s_axis_tdata[480+:8],
                                    c_s_axis_tdata[488+:8],
                                    c_s_axis_tdata[496+:8],
                                    c_s_axis_tdata[504+:8]
                                };

always @(posedge clk or negedge aresetn) begin
    if(~aresetn) begin
        c_wr_en <= 1'b0;
        c_index <= 4'b0;

        c_state <= IDLE_C;
    end
    else begin
        case(c_state)
            IDLE_C: begin
                if(c_s_axis_tvalid && mod_id[2:0] == DEPARSER_ID && control_flag == 16'hf2f1)begin
                    c_wr_en <= 1'b1;
                    c_index <= c_s_axis_tdata[384+:8];

                    c_state <= WRITE_C;

                end
                else begin
                    c_wr_en <= 1'b0;
                    c_index <= 4'b0; 

                    c_state <= IDLE_C;
                end
            end  
            //support full table flush
            WRITE_C: begin
                if(c_s_axis_tlast && c_s_axis_tvalid) begin
                    c_wr_en <= 1'b0;
                    c_index <= 4'b0;
                    c_state <= IDLE_C;
                end
                else begin
                    if(c_s_axis_tvalid) begin
                        c_wr_en <= 1'b1;
                        c_index <= c_index + 4'b1;
                    end
                    c_state <= WRITE_C;
                end
            end
        endcase

    end
end



parse_act_ram_ip
parse_act_ram
(
	// write port
	.clka		(clk),
	.addra		(c_index[3:0]),
	.dina		(c_s_axis_tdata_swapped[511 -: 260]),
	.ena		(1'b1),
	.wea		(c_wr_en),

	//
	.clkb		(clk),
	.addrb		(vlan_id[7:4]), // TODO: note that we may change due to little or big endian
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);


endmodule