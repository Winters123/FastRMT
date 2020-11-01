`timescale 1ns / 1ps

module deparser #(
	//in corundum with 100g ports, data width is 512b
	parameter	C_AXIS_DATA_WIDTH = 256,
	parameter	C_AXIS_TUSER_WIDTH = 128,
	parameter	C_PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256,
    parameter   DEPARSER_ID = 5
)
(
	input									clk,
	input									aresetn,

	input [C_AXIS_DATA_WIDTH-1:0]			pkt_fifo_tdata,
	input [C_AXIS_DATA_WIDTH/8-1:0]			pkt_fifo_tkeep,
	input [C_AXIS_TUSER_WIDTH-1:0]			pkt_fifo_tuser,
	// input								pkt_fifo_tvalid,
	input									pkt_fifo_tlast,
	input									pkt_fifo_empty,
	output reg							    pkt_fifo_rd_en,

	input [C_PKT_VEC_WIDTH-1:0]				phv_fifo_out,
	input									phv_fifo_empty,
	output reg								phv_fifo_rd_en,

	output reg [C_AXIS_DATA_WIDTH-1:0]		depar_out_tdata,
	output reg [C_AXIS_DATA_WIDTH/8-1:0]	depar_out_tkeep,
	output reg [C_AXIS_TUSER_WIDTH-1:0]		depar_out_tuser,
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


reg [2*C_AXIS_DATA_WIDTH-1:0]		 deparse_tdata_stored_r;
reg [2*C_AXIS_TUSER_WIDTH-1:0]	     deparse_tuser_stored_r;
reg [2*(C_AXIS_DATA_WIDTH/8)-1:0]	 deparse_tkeep_stored_r;
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

wire [47:0]                  deparse_phv_reg_out[0:9];
wire [1:0]                   deparse_phv_select[0:9];
wire [9:0]                   valid_out;


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

                    // deparse_tdata_stored_r[C_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                    // deparse_tuser_stored_r[C_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                    // deparse_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
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
                

                deparse_tdata_stored_r[C_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                deparse_tuser_stored_r[C_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                deparse_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
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
                deparse_tdata_stored_r[2*C_AXIS_DATA_WIDTH-1:C_AXIS_DATA_WIDTH] <= pkt_fifo_tdata;
                deparse_tuser_stored_r[2*C_AXIS_TUSER_WIDTH-1:C_AXIS_TUSER_WIDTH] <= pkt_fifo_tuser;
                deparse_tkeep_stored_r[2*(C_AXIS_DATA_WIDTH/8)-1:C_AXIS_DATA_WIDTH/8] <= pkt_fifo_tkeep;
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
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 16] <= deparse_phv_reg_out[0][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 32] <= deparse_phv_reg_out[0][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[0]<<3 +: 48] <= deparse_phv_reg_out[0][47:0];
                        endcase
                end

                if(parse_action[1][0]) begin
                        case(deparse_phv_select[1]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 16] <= deparse_phv_reg_out[1][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 32] <= deparse_phv_reg_out[1][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[1]<<3 +: 48] <= deparse_phv_reg_out[1][47:0];
                        endcase
                end

                if(parse_action[2][0]) begin
                        case(deparse_phv_select[2]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 16] <= deparse_phv_reg_out[2][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 32] <= deparse_phv_reg_out[2][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[2]<<3 +: 48] <= deparse_phv_reg_out[2][47:0];
                        endcase
                end

                if(parse_action[3][0]) begin
                        case(deparse_phv_select[3]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 16] <= deparse_phv_reg_out[3][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 32] <= deparse_phv_reg_out[3][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[3]<<3 +: 48] <= deparse_phv_reg_out[3][47:0];
                        endcase
                end

                if(parse_action[4][0]) begin
                        case(deparse_phv_select[4]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 16] <= deparse_phv_reg_out[4][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 32] <= deparse_phv_reg_out[4][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[4]<<3 +: 48] <= deparse_phv_reg_out[4][47:0];
                        endcase
                end

                if(parse_action[5][0]) begin
                        case(deparse_phv_select[5]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 16] <= deparse_phv_reg_out[5][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 32] <= deparse_phv_reg_out[5][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[5]<<3 +: 48] <= deparse_phv_reg_out[5][47:0];
                        endcase

                end

                if(parse_action[6][0]) begin
                        case(deparse_phv_select[6]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 16] <= deparse_phv_reg_out[6][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 32] <= deparse_phv_reg_out[6][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[6]<<3 +: 48] <= deparse_phv_reg_out[6][47:0];
                        endcase
                end

                if(parse_action[7][0]) begin
                        case(deparse_phv_select[7]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 16] <= deparse_phv_reg_out[7][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 32] <= deparse_phv_reg_out[7][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[7]<<3 +: 48] <= deparse_phv_reg_out[7][47:0];
                        endcase
                    
                end

                if(parse_action[8][0]) begin
                        case(deparse_phv_select[8]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 16] <= deparse_phv_reg_out[8][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 32] <= deparse_phv_reg_out[8][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[8]<<3 +: 48] <= deparse_phv_reg_out[8][47:0];
                        endcase
                end

                if(parse_action[9][0]) begin
                        case(deparse_phv_select[9]) 
                            
                            2'b01: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 16] <= deparse_phv_reg_out[9][15:0];
                            2'b10: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 32] <= deparse_phv_reg_out[9][31:0];
                            2'b11: deparse_tdata_stored_r[parse_action_ind[9]<<3 +: 48] <= deparse_phv_reg_out[9][47:0];
                        endcase
                end


                deparse_state <= FLUSH_PKT_0;
            end

            FLUSH_PKT_0: begin
                phv_fifo_rd_en <= 1'b0;

                depar_out_tdata <= deparse_tdata_stored_r[C_AXIS_DATA_WIDTH-1:0];
                depar_out_tuser <= deparse_tuser_stored_r[C_AXIS_TUSER_WIDTH-1:0];
                depar_out_tkeep <= deparse_tkeep_stored_r[C_AXIS_DATA_WIDTH/8-1:0];
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
                depar_out_tdata <= deparse_tdata_stored_r[(C_AXIS_DATA_WIDTH*1)+:C_AXIS_DATA_WIDTH];
                depar_out_tuser <= deparse_tuser_stored_r[(C_AXIS_TUSER_WIDTH*1)+:C_AXIS_TUSER_WIDTH];
                depar_out_tkeep <= deparse_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8*1)+:(C_AXIS_DATA_WIDTH/8)];
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
            	.C_AXIS_DATA_WIDTH(C_AXIS_DATA_WIDTH),
            	.C_AXIS_TUSER_WIDTH(),
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
                .deparse_phv_reg_out(deparse_phv_reg_out[index]),
                .deparse_phv_select(deparse_phv_select[index]),
                .valid_out(valid_out[index])
            );
        end
endgenerate



/****control path for 512b*****/
wire [7:0]          mod_id; //module ID
reg  [7:0]          c_index; //table index(addr)
reg                 c_wr_en; //enable table write(wen)
reg  [259:0]        entry_reg;

reg [2:0]           c_state;

localparam IDLE_C = 1,
           WRITE_C = 2;

assign mod_id = c_s_axis_tdata[368+:8];

always @(posedge clk or negedge aresetn) begin
    if(~aresetn) begin
        c_wr_en <= 1'b0;
        c_index <= 4'b0;

        c_state <= IDLE_C;
    end
    else begin
        case(c_state)
            IDLE_C: begin
                if(mod_id[2:0] == DEPARSER_ID)begin
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
                if(c_s_axis_tlast) begin
                    c_wr_en <= 1'b0;
                    c_index <= 4'b0;
                    c_state <= IDLE_C;
                end
                else begin
                    c_wr_en <= 1'b1;
                    c_index <= c_index + 4'b1;
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
	.dina		(c_s_axis_tdata[259:0]),
	.ena		(1'b1),
	.wea		(c_wr_en),

	//
	.clkb		(clk),
	.addrb		(vlan_id[7:4]), // TODO: note that we may change due to little or big endian
	.doutb		(bram_out),
	.enb		(1'b1) // always set to 1
);


endmodule