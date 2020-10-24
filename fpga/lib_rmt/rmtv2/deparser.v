`timescale 1ns / 1ps

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

reg  [11:0]   vlan_id;
wire [259:0]  bram_out;
wire [6:0]    parse_action_ind [0:9];
wire [15:0]   parse_action [0:9];		// we have 10 parse action

always @(posedge clk) begin
    vlan_id <= phv_fifo_out[129+:12];
end


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


/*********************************state***************************************/
localparam PHV_2B_START_POS = 20*5+256;
localparam PHV_4B_START_POS = 20*5+256+16*8;
localparam PHV_6B_START_POS = 20*5+256+16*8+32*8;

reg  [9:0]  deparse_state;

localparam  IDLE_S = 10'd0,
            BUF_HDR_0 = 10'd7,
            BUF_HDR_1 = 10'd1,
            WAIT_ONE = 10'd2,
            REFORM_HDR = 10'd3,
            FLUSH_PKT_0 = 10'd4,
            FLUSH_PKT_1 = 10'd5,
            FLUSH_PKT = 10'd6;


reg [2*C_AXIS_DATA_WIDTH-1:0]		deparse_tdata_stored_r;
reg [2*C_AXIS_TUSER_WIDTH-1:0]		deparse_tuser_stored_r;
reg [2*(C_AXIS_DATA_WIDTH/8)-1:0]	deparse_tkeep_stored_r;
reg [1:0]							deparse_tlast_stored_r;

reg [C_PKT_VEC_WIDTH-1:0]           deparse_phv_stored_r;
integer i;

always @(posedge clk or negedge aresetn) begin
    if(~aresetn) begin
        depar_out_tdata <= 0;
        depar_out_tkeep <= 0;
        depar_out_tuser <= 0;
        depar_out_tvalid <= 0;
        depar_out_tlast <= 0;

        pkt_fifo_rd_en <= 1'b0;
        phv_fifo_rd_en <= 1'b0;

        deparse_state <= IDLE_S;
    end

    else begin
        case(deparse_state)
            IDLE_S: begin
                //if there is work to do:
                if(!phv_fifo_empty && !pkt_fifo_empty) begin
                    deparse_phv_stored_r <= phv_fifo_out;

                    deparse_tdata_stored_r[C_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                    deparse_tuser_stored_r[C_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                    deparse_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
                    deparse_tlast_stored_r[0] <= pkt_fifo_tlast;

                    pkt_fifo_rd_en <= 1'b1;
                    
                    if(pkt_fifo_tlast) begin
                        //TODO needs to wait for the RAM
                        deparse_state <= WAIT_ONE;
                    end

                    else begin
                        deparse_state <= BUF_HDR_0;
                    end
                end
                else begin
                    depar_out_tdata <= 0;
                    depar_out_tkeep <= 0;
                    depar_out_tuser <= 0;
                    depar_out_tvalid <= 0;
                    depar_out_tlast <= 0;

                    pkt_fifo_rd_en <= 1'b0;
                    phv_fifo_rd_en <= 1'b0;

                    deparse_state <= IDLE_S;
                end
            end
            
            BUF_HDR_0: begin
                deparse_phv_stored_r <= phv_fifo_out;

                deparse_tdata_stored_r[C_AXIS_DATA_WIDTH-1:0] <= pkt_fifo_tdata;
                deparse_tuser_stored_r[C_AXIS_TUSER_WIDTH-1:0] <= pkt_fifo_tuser;
                deparse_tkeep_stored_r[(C_AXIS_DATA_WIDTH/8)-1:0] <= pkt_fifo_tkeep;
                deparse_tlast_stored_r[0] <= pkt_fifo_tlast;

                pkt_fifo_rd_en <= 1'b1;
                    
                if(pkt_fifo_tlast) begin
                    //TODO needs to wait for the RAM
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
                deparse_state <= REFORM_HDR;

            end

            //wait one more cycle for RAM read
            WAIT_ONE: begin
                pkt_fifo_rd_en <= 1'b0;
                deparse_state <= REFORM_HDR;
            end

            //this is the slot when we get RAM output
            REFORM_HDR: begin
                pkt_fifo_rd_en <= 1'b0;
                phv_fifo_rd_en <= 1'b1;
                for(i=0; i <= 9; i=i+1) begin
                    //check if its valid
                    if(parse_action[i][0]) begin
                        case(parse_action[i][5:4])
                            2'b01: begin
                                case(parse_action[i][3:1])
                                    3'd0:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*0+:16];
                                    3'd1:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*1+:16];
                                    3'd2:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*2+:16];
                                    3'd3:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*3+:16];
                                    3'd4:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*4+:16];
                                    3'd5:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*5+:16];
                                    3'd6:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*6+:16];
                                    3'd7:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 16] <= deparse_phv_stored_r[PHV_2B_START_POS+16*7+:16];
                                endcase
                            end
                            2'b10: begin
                                case(parse_action[i][3:1])
                                    3'd0:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*0+:32];
                                    3'd1:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*1+:32];
                                    3'd2:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*2+:32];
                                    3'd3:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*3+:32];
                                    3'd4:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*4+:32];
                                    3'd5:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*5+:32];
                                    3'd6:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*6+:32];
                                    3'd7:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 32] <= deparse_phv_stored_r[PHV_4B_START_POS+32*7+:32];
                                endcase
                            end
                            2'b11: begin
                                case(parse_action[i[3:1]])
                                    3'd0:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*0+:48];
                                    3'd1:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*1+:48];
                                    3'd2:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*2+:48];
                                    3'd3:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*3+:48];
                                    3'd4:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*4+:48];
                                    3'd5:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*5+:48];
                                    3'd6:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*6+:48];
                                    3'd7:  deparse_tdata_stored_r[(parse_action_ind[i])*8 +: 48] <= deparse_phv_stored_r[PHV_6B_START_POS+48*7+:48];
                                endcase
                            end
                        endcase
                    end
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