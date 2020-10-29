/****************************************************/
//	Module name: key_extract.v
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/10/01
//	Function outline: extract 256b+5b key out of PHV
//  Note: Used only for multi-tenants scenario
/****************************************************/

`timescale 1ns / 1ps
module key_extract_2 #(
    parameter STAGE = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    // format of KEY_OFF entry: |--3(6B)--|--3(6B)--|--3(4B)--|--3(4B)--|--3(2B)--|--3(2B)--|
    parameter KEY_OFF = (3+3)*3,
    parameter AXIL_WIDTH = 32,
    parameter KEY_OFF_ADDR_WIDTH = 4    
    )(
    input                               clk,
    input                               rst_n,
    input [PHV_LEN-1:0]                 phv_in,
    input                               phv_valid_in,

    //signals used to config key extract offset
    input [AXIL_WIDTH-1:0]              key_off_entry_in,
    input                               key_off_entry_in_valid,
    input [KEY_OFF_ADDR_WIDTH-1:0]      key_off_entry_addr,

    output reg [PHV_LEN-1:0]            phv_out,
    output reg                          phv_valid_out,
    output reg [KEY_LEN-1:0]            key_out,
    output reg                          key_valid_out
);


/********intermediate variables declared here********/
integer i;

localparam width_2B = 16;
localparam width_4B = 32;
localparam width_6B = 48;

//24 fields to be retrived from the pkt header
reg [width_2B-1:0]    cont_2B [0:7];
reg [width_4B-1:0]    cont_4B [0:7];
reg [width_6B-1:0]    cont_6B [0:7];

reg [PHV_LEN-1:0]     phv_out_delay[0:1];
reg                   phv_valid_out_delay[0:1];

reg  [19:0]            com_op[0:4];
reg  [7:0]             com_op_1;
reg  [7:0]             com_op_2;

//vlan_id extracted from metadata
wire  [11:0]             vlan_id; 

wire [KEY_OFF-1:0]      key_offset;

/********intermediate variables declared here********/

// assign cont_6B[7] = phv_in[PHV_LEN-1            -: width_6B];
// assign cont_6B[6] = phv_in[PHV_LEN-1-  width_6B -: width_6B];
// assign cont_6B[5] = phv_in[PHV_LEN-1-2*width_6B -: width_6B];
// assign cont_6B[4] = phv_in[PHV_LEN-1-3*width_6B -: width_6B];
// assign cont_6B[3] = phv_in[PHV_LEN-1-4*width_6B -: width_6B];
// assign cont_6B[2] = phv_in[PHV_LEN-1-5*width_6B -: width_6B];
// assign cont_6B[1] = phv_in[PHV_LEN-1-6*width_6B -: width_6B];
// assign cont_6B[0] = phv_in[PHV_LEN-1-7*width_6B -: width_6B];

// assign cont_4B[7] = phv_in[PHV_LEN-1-8*width_6B           -: width_4B];
// assign cont_4B[6] = phv_in[PHV_LEN-1-8*width_6B-  width_4B -: width_4B];
// assign cont_4B[5] = phv_in[PHV_LEN-1-8*width_6B-2*width_4B -: width_4B];
// assign cont_4B[4] = phv_in[PHV_LEN-1-8*width_6B-3*width_4B -: width_4B];
// assign cont_4B[3] = phv_in[PHV_LEN-1-8*width_6B-4*width_4B -: width_4B];
// assign cont_4B[2] = phv_in[PHV_LEN-1-8*width_6B-5*width_4B -: width_4B];
// assign cont_4B[1] = phv_in[PHV_LEN-1-8*width_6B-6*width_4B -: width_4B];
// assign cont_4B[0] = phv_in[PHV_LEN-1-8*width_6B-7*width_4B -: width_4B];


// assign cont_2B[7] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B            -: width_2B];
// assign cont_2B[6] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-  width_2B -: width_2B];
// assign cont_2B[5] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-2*width_2B -: width_2B];
// assign cont_2B[4] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-3*width_2B -: width_2B];
// assign cont_2B[3] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-4*width_2B -: width_2B];
// assign cont_2B[2] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-5*width_2B -: width_2B];
// assign cont_2B[1] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-6*width_2B -: width_2B];
// assign cont_2B[0] = phv_in[PHV_LEN-1-8*width_6B-8*width_4B-7*width_2B -: width_2B];

//retrive the operators here using wire
// assign com_op[0] = phv_in[255+100 -: 20];
// assign com_op[1] = phv_in[255+80  -: 20];
// assign com_op[2] = phv_in[255+60  -: 20];
// assign com_op[3] = phv_in[255+40  -: 20];
// assign com_op[4] = phv_in[255+20  -: 20];

assign vlan_id = phv_in[140:129];

//locate those containers
always @(posedge clk) begin
    cont_6B[7] <= phv_in[PHV_LEN-1            -: width_6B];
    cont_6B[6] <= phv_in[PHV_LEN-1-  width_6B -: width_6B];
    cont_6B[5] <= phv_in[PHV_LEN-1-2*width_6B -: width_6B];
    cont_6B[4] <= phv_in[PHV_LEN-1-3*width_6B -: width_6B];
    cont_6B[3] <= phv_in[PHV_LEN-1-4*width_6B -: width_6B];
    cont_6B[2] <= phv_in[PHV_LEN-1-5*width_6B -: width_6B];
    cont_6B[1] <= phv_in[PHV_LEN-1-6*width_6B -: width_6B];
    cont_6B[0] <= phv_in[PHV_LEN-1-7*width_6B -: width_6B];
    cont_4B[7] <= phv_in[PHV_LEN-1-8*width_6B           -: width_4B];
    cont_4B[6] <= phv_in[PHV_LEN-1-8*width_6B-  width_4B -: width_4B];
    cont_4B[5] <= phv_in[PHV_LEN-1-8*width_6B-2*width_4B -: width_4B];
    cont_4B[4] <= phv_in[PHV_LEN-1-8*width_6B-3*width_4B -: width_4B];
    cont_4B[3] <= phv_in[PHV_LEN-1-8*width_6B-4*width_4B -: width_4B];
    cont_4B[2] <= phv_in[PHV_LEN-1-8*width_6B-5*width_4B -: width_4B];
    cont_4B[1] <= phv_in[PHV_LEN-1-8*width_6B-6*width_4B -: width_4B];
    cont_4B[0] <= phv_in[PHV_LEN-1-8*width_6B-7*width_4B -: width_4B];
    cont_2B[7] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B            -: width_2B];
    cont_2B[6] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-  width_2B -: width_2B];
    cont_2B[5] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-2*width_2B -: width_2B];
    cont_2B[4] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-3*width_2B -: width_2B];
    cont_2B[3] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-4*width_2B -: width_2B];
    cont_2B[2] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-5*width_2B -: width_2B];
    cont_2B[1] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-6*width_2B -: width_2B];
    cont_2B[0] <= phv_in[PHV_LEN-1-8*width_6B-8*width_4B-7*width_2B -: width_2B];
    com_op[0]  <= phv_in[255+100 -: 20];
    com_op[1]  <= phv_in[255+80  -: 20];
    com_op[2]  <= phv_in[255+60  -: 20];
    com_op[3]  <= phv_in[255+40  -: 20];
    com_op[4]  <= phv_in[255+20  -: 20];
end



//have to extract comparators within 1 cycle
always @(*) begin
    if(com_op[STAGE][17] == 1'b1) begin
        com_op_1 = com_op[STAGE][16:9];
    end
    else begin
        case(com_op[STAGE][13:12])
            2'b10: begin
                com_op_1 = cont_6B[com_op[STAGE][11:9]][7:0];
            end
            2'b01: begin
                com_op_1 = cont_4B[com_op[STAGE][11:9]][7:0];
            end
            2'b00: begin
                com_op_1 = cont_2B[com_op[STAGE][11:9]][7:0];
            end
        endcase
    end
    if(com_op[STAGE][8] == 1'b1) begin
        com_op_2 = com_op[STAGE][7:0];
    end
    else begin
        case(com_op[STAGE][4:3])
            2'b10: begin
                com_op_2 = cont_6B[com_op[STAGE][2:0]][7:0];
            end
            2'b01: begin
                com_op_2 = cont_4B[com_op[STAGE][2:0]][7:0];
            end
            2'b00: begin
                com_op_2 = cont_2B[com_op[STAGE][2:0]][7:0];
            end
        endcase
    end

end

//extract keys from PHV
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        key_out <= 0;
        key_valid_out <= 1'b0;
        phv_out <= 0;
        phv_valid_out <= 1'b0;
        phv_out_delay[0] <= 0;
        phv_out_delay[1] <= 0;
        phv_valid_out_delay[0] <= 1'b0;
        phv_valid_out_delay[1] <= 1'b0;
    end
    else begin
        //output PHV
        phv_out_delay[0] <= phv_in;
        phv_out_delay[1] <= phv_out_delay[0];
        phv_out <= phv_out_delay[1];
        phv_valid_out_delay[0] <= phv_valid_in;
        phv_valid_out_delay[1] <= phv_valid_out_delay[0];
        phv_valid_out <= phv_valid_out_delay[1];

        //extract keys according to key_off
        if(phv_valid_out_delay[1]) begin
            key_out[KEY_LEN-1                                     -: width_6B] <= cont_6B[key_offset[KEY_OFF-1     -: 3]];
            key_out[KEY_LEN-1- 1*width_6B                         -: width_6B] <= cont_6B[key_offset[KEY_OFF-1-1*3 -: 3]];
            key_out[KEY_LEN-1- 2*width_6B                         -: width_4B] <= cont_4B[key_offset[KEY_OFF-1-2*3 -: 3]];
            key_out[KEY_LEN-1- 2*width_6B - 1*width_4B            -: width_4B] <= cont_4B[key_offset[KEY_OFF-1-3*3 -: 3]];
            key_out[KEY_LEN-1- 2*width_6B - 2*width_4B            -: width_2B] <= cont_2B[key_offset[KEY_OFF-1-4*3 -: 3]];
            key_out[KEY_LEN-1- 2*width_6B - 2*width_4B - width_2B -: width_2B] <= cont_2B[key_offset[KEY_OFF-1-5*3 -: 3]];
            //deal with comparators
            case(com_op[STAGE][19:18])
                2'b00: begin
                    key_out[4-STAGE] <= (com_op_1>com_op_2)?1'b1:1'b0;
                end
                2'b01: begin
                    key_out[4-STAGE] <= (com_op_1>=com_op_2)?1'b1:1'b0;
                end
                2'b10: begin
                    key_out[4-STAGE] <= (com_op_1==com_op_2)?1'b1:1'b0;
                end
                default: begin
                    key_out[4-STAGE] <= 1'b1;
                end
            endcase

        end
        
        if(phv_valid_out_delay[1]) begin
            key_valid_out <= 1'b1;    
        end
        else begin
            key_valid_out <= 1'b0;
        end
    end
end


//ram for key extract
//blk_mem_gen_2 act_ram_18w_16d
// blk_mem_gen_2 #(
// 	.C_INIT_FILE_NAME	("./key_extract.mif"),
// 	.C_LOAD_INIT_FILE	(1)
// )
blk_mem_gen_2
act_ram_18w_16d
(
    .addra(key_off_entry_addr),
    .clka(clk),
    .dina(key_off_entry_in[KEY_OFF-1:0]),
    .ena(1'b1),
    .wea(key_off_entry_in_valid),

    //only [3:0] is needed for addressing
	.addrb(vlan_id[7:4]), // TODO: we may need to change this logic due to big/little endian
    .clkb(clk),
    .doutb(key_offset),
    .enb(1'b1)
);

endmodule
