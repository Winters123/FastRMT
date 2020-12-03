/****************************************************/
//	Module name: lookup_engine.v
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/24
//	Function outline: perform match action with 197b key
/****************************************************/

`timescale 1ns / 1ps

module lookup_engine #(
    parameter C_S_AXIS_DATA_WIDTH = 512,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter STAGE_ID = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    parameter ACT_LEN = 625,
    parameter LOOKUP_ID = 2
)
(
    input clk,
    input rst_n,

    //output from key extractor
    //output from key extractor
    input [KEY_LEN-1:0]           extract_key,
    input [KEY_LEN-1:0]           extract_mask,
    input                         key_valid,
    input [PHV_LEN-1:0]           phv_in,

    //output to the action engine
    output reg [ACT_LEN-1:0]      action,
    output reg                    action_valid,
    output reg [PHV_LEN-1:0]      phv_out, 


    //control path
    input [C_S_AXIS_DATA_WIDTH-1:0]			    c_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		    c_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		    c_s_axis_tkeep,
	input									    c_s_axis_tvalid,
	input									    c_s_axis_tlast,

    output reg [C_S_AXIS_DATA_WIDTH-1:0]		c_m_axis_tdata,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]		c_m_axis_tuser,
	output reg [C_S_AXIS_DATA_WIDTH/8-1:0]		c_m_axis_tkeep,
	output reg 								    c_m_axis_tvalid,
	output reg 							    	c_m_axis_tlast

);

/********intermediate variables declared here********/
wire [3:0]  match_addr;
wire        match;

wire [ACT_LEN-1:0] action_wire;


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


/****control path*****/
wire [7:0]          mod_id; //module ID
//4'b0 for tcam entry;
//NOTE: we don't need tcam entry mask
//4'b2 for action table entry;
wire [3:0]          resv; //recog between tcam and action
wire [15:0]         control_flag; //dst udp port num


reg  [7:0]          c_index_cam; //table index(addr)

reg                 c_wr_en_cam; //enable table write(wena)

reg  [7:0]          c_index_act;
reg                 c_wr_en_act;
reg  [ACT_LEN-1:0]  act_entry_tmp;             
reg                 continous_flag;


reg [2:0]           c_state;


/****for 256b exclusively*****/
reg [C_S_AXIS_DATA_WIDTH-1:0]       c_m_axis_tdata_r;
reg [C_S_AXIS_TUSER_WIDTH-1:0]      c_m_axis_tuser_r;
reg [C_S_AXIS_DATA_WIDTH/8-1:0]     c_m_axis_tkeep_r;
reg                                 c_m_axis_tvalid_r;
reg                                 c_m_axis_tlast_r;


localparam IDLE_C = 0,
           PARSE_C = 1,
           CAM_TMP_ENTRY = 2,
           ACT_TMP_ENTRY_WAIT = 3,
           ACT_TMP_ENTRY_WAIT_2 = 4,
           ACT_TMP_ENTRY = 5,
		   FLUSH_REST_C = 6;

generate 
    if(C_S_AXIS_DATA_WIDTH == 512) begin
        assign mod_id = c_s_axis_tdata[368+:8];
        assign resv   = c_s_axis_tdata[380+:4];
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
        always @(posedge clk or negedge rst_n) begin
            if(~rst_n) begin
                c_index_cam <= 0;
                c_wr_en_cam <= 0;

                c_index_act <= 0;
                c_wr_en_act <= 0;

                act_entry_tmp <= 0;
                continous_flag <= 0;

                c_m_axis_tdata <= 0;
                c_m_axis_tuser <= 0;
                c_m_axis_tkeep <= 0;
                c_m_axis_tvalid <= 0;
                c_m_axis_tlast <= 0;

                c_state <= IDLE_C;

            end

            else begin
                case(c_state)
                    IDLE_C: begin
                        if(c_s_axis_tvalid) begin
                            if(mod_id[7:3] == STAGE_ID && mod_id[2:0] == LOOKUP_ID && control_flag == 16'hf2f1) begin
                                //TCAM entry
                                if(resv == 4'b0) begin
                                    c_wr_en_cam <= 1'b1;
                                    c_index_cam <= c_s_axis_tdata[384+:8];
                                    c_state <= CAM_TMP_ENTRY;
                                end
                                //ACTION entry
                                else begin
                                    continous_flag <= 1'b0;
                                    c_index_act <= c_s_axis_tdata[384+:8];
                                    c_state <= ACT_TMP_ENTRY_WAIT;
                                end
                            end
                            //not for lookup
                            else begin
                                c_index_cam <= 0;
                                c_wr_en_cam <= 0;

                                c_index_act <= 0;
                                c_wr_en_act <= 0;

                                act_entry_tmp <= 0;
                                continous_flag <= 0;

                                c_m_axis_tdata <= c_s_axis_tdata;
                                c_m_axis_tuser <= c_s_axis_tuser;
                                c_m_axis_tkeep <= c_s_axis_tkeep;
                                c_m_axis_tvalid <= c_s_axis_tvalid;
                                c_m_axis_tlast <= c_s_axis_tlast;

                                c_state <= IDLE_C;
                            end
                        end
                        //stay halt
                        else begin
                            c_index_cam <= 0;
                            c_wr_en_cam <= 0;

                            c_index_act <= 0;
                            c_wr_en_act <= 0;

                            act_entry_tmp <= 0;
                            continous_flag <= 0;

                            c_m_axis_tdata <= 0;
                            c_m_axis_tuser <= 0;
                            c_m_axis_tkeep <= 0;
                            c_m_axis_tvalid <= 0;
                            c_m_axis_tlast <= 0;

                            c_state <= IDLE_C;
                        end
                    end

                    CAM_TMP_ENTRY: begin
                        if(c_s_axis_tvalid && c_s_axis_tlast) begin
                            c_wr_en_cam <= 1'b0;
                            c_state <= IDLE_C;
                        end
                        else if (c_s_axis_tvalid) begin
                            c_wr_en_cam <= 1'b1;
                            c_index_cam <= c_index_cam + 8'b1;
                            c_state <= CAM_TMP_ENTRY;
                        end
                        else begin
                            c_wr_en_cam <= c_wr_en_cam;
                            c_index_cam <= c_index_cam;
                            c_state <= c_state;
                        end
                    end

                    ACT_TMP_ENTRY_WAIT: begin
                        c_m_axis_tvalid_r <= 1'b0;
                        c_m_axis_tlast_r <= 1'b0;
                        //flush the whole table
                        if(c_s_axis_tvalid && ~c_s_axis_tlast) begin
                            if (continous_flag)   c_index_act <= c_index_act + 8'b1;
                            else                  c_index_act <= c_index_act;
                            act_entry_tmp[624 -: 512] <= c_s_axis_tdata_swapped;
                            c_wr_en_act <= 1'b0;
                            c_state <= ACT_TMP_ENTRY;
                        end
                        else if(c_s_axis_tvalid && c_s_axis_tlast) begin
                            c_wr_en_act <= 1'b0;
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_wr_en_act <= 1'b0;
                            c_state <= c_state;
                        end
                    end

                    ACT_TMP_ENTRY: begin
                        if(c_s_axis_tvalid) begin
                            act_entry_tmp[112:0] <= c_s_axis_tdata_swapped[511-:113];
                            c_wr_en_act <= 1'b1;
                            if(c_s_axis_tlast)   c_state <= IDLE_C;
                            else begin
                                continous_flag <= 1'b1;
                                c_state <= ACT_TMP_ENTRY_WAIT;
                            end
                        end
                        else begin
                            c_state <= c_state;
                            act_entry_tmp <= act_entry_tmp;
                            c_wr_en_act <= c_wr_en_act;
                        end
                    end

                endcase
            end
        end
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
            .CMP_DIN			(extract_key),
            .CMP_DATA_MASK		(extract_mask),
            .BUSY				(),
            .MATCH				(match),
            .MATCH_ADDR			(match_addr),

            //.WE				(lookup_din_en),
            //.WR_ADDR			(lookup_din_addr),
            //.DATA_MASK		(lookup_din_mask),  
            //.DIN				(lookup_din),

            .WE                 (c_wr_en_cam),
            .WR_ADDR            (c_index_cam[3:0]),
            .DATA_MASK          (),  //TODO do we need ternary matching?
            .DIN                (c_s_axis_tdata_swapped[511-:197]),
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
            .addra(c_index_act[3:0]),
            .clka(clk),
            .dina(act_entry_tmp),
            .ena(1'b1),
            .wea(c_wr_en_act),

            .addrb(match_addr),
            .clkb(clk),
            .doutb(action_wire),
            .enb(match)
        );
    end
    //NOTE: data width is 256b
    else begin
        assign mod_id = c_s_axis_tdata[112+:8];
        assign resv = c_s_axis_tdata[120+:4];
        assign control_flag = c_s_axis_tdata[64+:16];
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
											c_s_axis_tdata[248+:8]};
        always @(posedge clk or negedge rst_n) begin
            if(~rst_n) begin
                c_index_cam <= 0;
                c_wr_en_cam <= 0;

                c_index_act <= 0;
                c_wr_en_act <= 0;

                act_entry_tmp <= 0;
                continous_flag <= 0;

                c_m_axis_tdata <= 0;
                c_m_axis_tuser <= 0;
                c_m_axis_tkeep <= 0;
                c_m_axis_tvalid <= 0;
                c_m_axis_tlast <= 0;

                c_m_axis_tdata_r <= 0;
                c_m_axis_tuser_r <= 0;
                c_m_axis_tkeep_r <= 0;
                c_m_axis_tvalid_r <= 0;
                c_m_axis_tlast_r <= 0;

                c_state <= IDLE_C;

            end
            else begin
                case(c_state)
                    IDLE_C: begin
                        c_m_axis_tdata <= c_m_axis_tdata_r;
                        c_m_axis_tuser <= c_m_axis_tuser_r;
                        c_m_axis_tkeep <= c_m_axis_tkeep_r;
                        c_m_axis_tvalid <= c_m_axis_tvalid_r;
                        c_m_axis_tlast <= c_m_axis_tlast_r;
                        if(c_s_axis_tvalid) begin
                            c_m_axis_tdata_r <= c_s_axis_tdata;
                            c_m_axis_tuser_r <= c_s_axis_tuser;
                            c_m_axis_tkeep_r <= c_s_axis_tkeep;
                            c_m_axis_tvalid_r <= c_s_axis_tvalid;
                            c_m_axis_tlast_r <= c_s_axis_tlast;

                            c_state <= PARSE_C;
                        end
                        else begin
                            c_wr_en_cam <= 1'b0;
                            c_wr_en_act <= 1'b0;
                            c_index_act <= 8'b0; 
                            c_index_cam <= 8'b0;
                            continous_flag <= 1'b0;

                            c_m_axis_tvalid_r <= 1'b0;
                            c_m_axis_tlast_r <= 1'b0;

                            c_state <= IDLE_C;
                        end
                    end
                    PARSE_C: begin
                        if(mod_id[7:3] == STAGE_ID && mod_id[2:0] == LOOKUP_ID && 
                        control_flag == 16'hf2f1 && c_s_axis_tvalid) begin
                            c_m_axis_tdata <= 0;
                            c_m_axis_tuser <= 0;
                            c_m_axis_tkeep <= 0;
                            c_m_axis_tvalid <= 0;
                            c_m_axis_tlast <= 0;

                            if(resv == 4'b0 && c_s_axis_tvalid) begin
                                c_index_cam <= c_s_axis_tdata[128+:8];
                                c_wr_en_cam <= 1'b1;
                                c_state <= CAM_TMP_ENTRY;
                            end
                            else if (c_s_axis_tvalid)begin
                                c_index_act <= c_s_axis_tdata[128+:8];
                                c_wr_en_act <= 1'b0;
                                c_state <= ACT_TMP_ENTRY_WAIT;
                            end
                            else begin
                                c_state <= PARSE_C;
                                c_wr_en_act <= c_wr_en_act;
                                c_index_act <= c_index_act;
                            end
                        end
                        //if I don't know if I should send it, then I should hold it.
                        else if(!c_s_axis_tvalid) begin
                            c_m_axis_tdata <= c_m_axis_tdata;
                            c_m_axis_tuser <= c_m_axis_tuser;
                            c_m_axis_tkeep <= c_m_axis_tkeep;
                            c_m_axis_tvalid <= 0;
                            c_m_axis_tlast <= 0;

                            c_m_axis_tdata_r <= c_m_axis_tdata_r;
                            c_m_axis_tuser_r <= c_m_axis_tuser_r;
                            c_m_axis_tkeep_r <= c_m_axis_tkeep_r;
                            c_m_axis_tvalid_r <= c_m_axis_tvalid_r;
                            c_m_axis_tlast_r <= c_m_axis_tlast_r;
                        end

                        else begin
                            c_m_axis_tdata <= c_m_axis_tdata_r;
                            c_m_axis_tuser <= c_m_axis_tuser_r;
                            c_m_axis_tkeep <= c_m_axis_tkeep_r;
                            c_m_axis_tvalid <= c_m_axis_tvalid_r;
                            c_m_axis_tlast <= c_m_axis_tlast_r;

                            c_m_axis_tdata_r <= c_s_axis_tdata;
                            c_m_axis_tuser_r <= c_s_axis_tuser;
                            c_m_axis_tkeep_r <= c_s_axis_tkeep;
                            c_m_axis_tvalid_r <= c_s_axis_tvalid;
                            c_m_axis_tlast_r <= c_s_axis_tlast;
                            
                            if(c_s_axis_tvalid && c_s_axis_tlast) c_state <= IDLE_C;
							else c_state <= FLUSH_REST_C;
                        end
                    end
					FLUSH_REST_C: begin
						c_m_axis_tdata <= c_m_axis_tdata_r;
						c_m_axis_tuser <= c_m_axis_tuser_r;
						c_m_axis_tkeep <= c_m_axis_tkeep_r; 
						c_m_axis_tvalid <= c_m_axis_tvalid_r; 
						c_m_axis_tlast <= c_m_axis_tlast_r;

                       	c_m_axis_tdata_r <= c_s_axis_tdata;
                       	c_m_axis_tuser_r <= c_s_axis_tuser;
                       	c_m_axis_tkeep_r <= c_s_axis_tkeep;
                       	c_m_axis_tvalid_r <= c_s_axis_tvalid;
                       	c_m_axis_tlast_r <= c_s_axis_tlast;
                            
                        if(c_s_axis_tvalid && c_s_axis_tlast) 
							c_state <= IDLE_C;
					end

                    CAM_TMP_ENTRY: begin
                        c_m_axis_tvalid_r <= 1'b0;
                        c_m_axis_tlast_r <= 1'b0;
                        if(c_s_axis_tlast && c_s_axis_tvalid) begin
                            c_wr_en_cam <= 1'b0;
                            c_index_cam <= 8'b0;
                            c_state <= IDLE_C;
                        end
                        else if(c_s_axis_tvalid) begin
                            c_wr_en_cam <= 1'b1;
                            c_index_cam <= c_index_cam + 8'b1;
                            c_state <= CAM_TMP_ENTRY;
                        end
                        else begin
                            c_wr_en_cam <= c_wr_en_cam;
                            c_index_cam <= c_index_cam;
                            c_state <= c_state;
                        end
                    end

                    ACT_TMP_ENTRY_WAIT: begin
                        c_m_axis_tvalid_r <= 1'b0;
                        c_m_axis_tlast_r <= 1'b0;
                        c_wr_en_act <= 1'b0;
                        if(c_s_axis_tvalid && ~c_s_axis_tlast) begin
                            act_entry_tmp[369+:256] <= c_s_axis_tdata_swapped;
                            if(continous_flag) c_index_act <= c_index_act + 8'b1;
                            c_state <= ACT_TMP_ENTRY_WAIT_2;
                        end
                        else if (c_s_axis_tvalid && c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= ACT_TMP_ENTRY_WAIT;
                        end
                    end

                    ACT_TMP_ENTRY_WAIT_2: begin
                        if(c_s_axis_tvalid && ~c_s_axis_tlast) begin
                            act_entry_tmp[113+:256] <= c_s_axis_tdata_swapped;
                            c_state <= ACT_TMP_ENTRY;
                        end
                        else if (c_s_axis_tvalid && c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            act_entry_tmp[113+:256] <= act_entry_tmp[113+:256];
                            c_state <= ACT_TMP_ENTRY_WAIT_2;
                        end
                    end

                    ACT_TMP_ENTRY: begin
                        if(c_s_axis_tvalid) begin
                            act_entry_tmp[0+:113] <= c_s_axis_tdata_swapped[143+:113];
                            c_wr_en_act <= 1'b1;
                            if(c_s_axis_tlast) begin
                                continous_flag <= 1'b0;
                                c_state <= IDLE_C;
                            end
                            else begin
                                c_state <= ACT_TMP_ENTRY_WAIT;
                                continous_flag <= 1'b1;
                            end
                        end
                        else begin
                            c_state <= ACT_TMP_ENTRY;
                        end

                    end

                endcase
            end
        end

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
            .CMP_DIN			(extract_key),
            .CMP_DATA_MASK		(extract_mask),
            .BUSY				(),
            .MATCH				(match),
            .MATCH_ADDR			(match_addr),

            //.WE				(lookup_din_en),
            //.WR_ADDR			(lookup_din_addr),
            //.DATA_MASK		(lookup_din_mask),  
            //.DIN				(lookup_din),

            .WE                 (c_wr_en_cam),
            .WR_ADDR            (c_index_cam[3:0]),
            .DATA_MASK          (),  //TODO do we need ternary matching?
            .DIN                (c_s_axis_tdata_swapped[59+:197]),
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
            .addra(c_index_act[3:0]),
            .clka(clk),
            .dina(act_entry_tmp),
            .ena(1'b1),
            .wea(c_wr_en_act),

            .addrb(match_addr),
            .clkb(clk),
            .doutb(action_wire),
            .enb(match)
        );
    end

endgenerate

endmodule
