`timescale 1 ns / 1 ps
`include "ds_define.vh"
module ds_bwd_frag #
	(
		parameter integer	DATA_WIDTH = 32,
		parameter integer 	FORM_WIDTH = 32,
		parameter integer   CODE_WIDTH = 5,
		parameter 			FRAG_TYPE  = `Y_TYPE
	)
	(
		input	wire		 			clk,
		input	wire		 			rst,
		input	wire		 			gen_en,    //gen_en = parent_mass_match & (|FRAG_TYPE[2:0])      
		input	wire		 			start,
		input	wire		 			ds_done, 

		/* register input */
		input 	wire  [31:0] 		    ds_ctrl,   		// slv_reg0
		input	wire  [31:0]			m_ct,			// slv_reg2
		input	wire  [31:0]			m_cleave_c,		// slv_reg4
		input	wire  [31:0] 			mod_right,		
		input	wire  [31:0]			fullmod_right, 	// slv_reg41
		input   wire  [3:0]             pep_judge,

		/* get data from ds_pepc_store bram */
		
		output  wire                        store_finish,
		output 	wire  [4:0]					pep_addr,
		input 	wire  [DATA_WIDTH*5-1:0] 	pep_data,       // pep data from bram
		input	wire  [15:0]			    pep_len, 		// pep_len

		/* ds_score interface */

    	input 	wire  [4:0]					xr_addr,
    	output 	wire  [DATA_WIDTH*40-1:0]	xr_data, 
    	output  wire  [DATA_WIDTH*8 -1:0]   yr_data,
    	output  reg	  [31 : 0] 				y_value_1_reg,
    	output  reg   [159 : 0]		        x_value_1_reg,


		/* coefficient register input */	

		output  reg   [159 : 0] 			para_addr,
		input   wire  [1023 : 0] 			para_data

	);

localparam 	pipline_delay = 5'h3;

/*------ State Machine Defination ------*/
	parameter	INIT 		= 3'b000, 
				GEN_PRE		= 3'b001, 
				GEN_WAIT	= 3'b011,
				FRAG_GEN	= 3'b111,
				STORING		= 3'b110,
				DONE_WAIT	= 3'b100;

	reg	[2:0]				current;
	reg [2:0]				next;
	wire					calc_done;

    wire	                temp_pre;
    reg                     frag_ready;
    
assign  temp_pre = gen_en & (current == INIT);

always @(posedge clk or posedge rst)
begin
	if(rst) 
		current <= INIT;
	else
		current <= next;
end

always @ (*)
begin
	next = current;
	case (current)
	INIT 		:	next = temp_pre ? GEN_PRE : INIT;                            //0
	GEN_PRE		:	next = start ? FRAG_GEN : GEN_PRE;                          //1
	FRAG_GEN	:	next = calc_done ? STORING : FRAG_GEN;                       //7
	STORING 	: 	next = frag_ready ? DONE_WAIT : STORING;    //6 store_finish is set after FRAG_GEN and its length is 3 clock.
	DONE_WAIT	:	next = ds_done ? INIT : DONE_WAIT;            //4
	default		:	next = current;
	endcase
end

/*------ frag generation temp value prepare ------*/
	reg 	[2 * FORM_WIDTH - 1 : 0]	m_temp;
	wire	[2 * FORM_WIDTH - 1 : 0]	m_temp_i;

	reg 	[FORM_WIDTH - 1 : 0] 		m_type;
	wire	[FORM_WIDTH - 1 : 0]		m_cleave_c_default;

always @ (*)
begin
	case (FRAG_TYPE)
	`X_TYPE: m_type = ds_ctrl[1] ? `M_X_1 : `M_X_0;
	`Y_TYPE: m_type = ds_ctrl[1] ? `M_Y_1 : `M_Y_0;
	`Z_TYPE: m_type = ds_ctrl[1] ? `M_Z_1 : `M_Z_0;
	default: m_type = {FORM_WIDTH{1'b0}};
	endcase
end

assign  m_cleave_c_default = ds_ctrl[1] ? `M_CLEAVE_C_DEFAULT_1 : `M_CLEAVE_C_DEFAULT_0;
assign 	m_temp_i = {{FORM_WIDTH{m_type[FORM_WIDTH-1]}}, m_type} + fullmod_right + m_cleave_c - m_cleave_c_default;

always @ (*)
begin
	case ({pep_judge[3], pep_judge[1]})
	2'b11:	m_temp = m_temp_i + {{FORM_WIDTH{mod_right[FORM_WIDTH-1]}}, mod_right} + m_ct;
	2'b10:	m_temp = m_temp_i + m_ct;
	2'b01: 	m_temp = m_temp_i + {{FORM_WIDTH{mod_right[FORM_WIDTH-1]}}, mod_right};
	2'b00:	m_temp = m_temp_i;
	default: m_temp = m_temp_i;
	endcase
end

/*------ End: frag generation temp value prepare ------*/
reg    			data_en;
reg [4 : 0]   	data_cnt;
wire [15:0]        store_deep;
wire [15:0]        store_remain;

assign  store_remain = (pep_len[4 : 0] == 5'h0) ? 15'h0 : 15'h1; 
assign  store_deep = (pep_len >> 5) + store_remain;
assign  calc_done = (current == FRAG_GEN) && (data_cnt == store_deep[4:0] + pipline_delay);

/*---------------- frag generate pip-line -------------*/



	reg [4:0] 		pep_addr_r;


always @ (posedge clk or posedge rst)
begin
	if(rst)
		pep_addr_r <= 5'b0;
	else if((next == FRAG_GEN) & (~store_finish))
		pep_addr_r <= pep_addr_r + 1;
	else 
		pep_addr_r <= 5'b0;
end



assign  pep_addr = store_deep[4:0] - 5'b1 - pep_addr_r;

wire  [DATA_WIDTH*5-1:0] 	pep_data_r;
ds_convert ds_convert_i(.data_in(pep_data), .data_out(pep_data_r));

always @(posedge clk or posedge rst) begin
	if (rst) 
		para_addr <= 160'h0;
	else if (current == FRAG_GEN)
		para_addr <= pep_data_r; 
end


// result
wire	[47 : 0]		vout[0:31];
reg 	[47 : 0]		cin_l;
wire    [47 : 0]		cin_h;

always @(posedge clk or posedge rst)
begin
	if(rst)
		cin_l <= {48{1'b0}};
	else if((current == FRAG_GEN) && (data_cnt <= pipline_delay))
		cin_l <= m_temp[47:0];
	else if((current == FRAG_GEN) && (data_cnt > pipline_delay))
		cin_l <= vout[31];
	else 
		cin_l <= cin_l;
end

reg    [CODE_WIDTH*16-1 : 0]   pep_data_l;
reg    [CODE_WIDTH*16-1 : 0]   pep_data_h;

always @(posedge clk or posedge rst) begin
 		if (rst) begin
 			pep_data_l <= {(CODE_WIDTH*16){1'h0}};
 			pep_data_h <= {(CODE_WIDTH*16){1'h0}};
 		end
 		else if (next == FRAG_GEN) begin
 			pep_data_l <= pep_data_r[CODE_WIDTH*16-1 : 0];
 			pep_data_h <= pep_data_r[CODE_WIDTH*32-1 : CODE_WIDTH*16];
 		end
 		else begin
 			pep_data_l <= {(CODE_WIDTH*16){1'h0}};
 			pep_data_h <= {(CODE_WIDTH*16){1'h0}};			
 		end
 	end 	
reg data_en_r;

ds_para_add_16  #(

	.DATA_WIDTH(DATA_WIDTH),   //32
	.CODE_WIDTH(5),
	.FORM_WIDTH(FORM_WIDTH),     //32
	.GEN_TYPE(FRAG_TYPE)

)ds_add_16_l(
	.clk 				(clk),
	.rst 				(rst),

	.para_chain         (para_data[511 : 0]),
	.vadd				(pep_data_l), 
	.mass_type			(ds_ctrl[1]),
	.add_en 			(data_en_r), 


/*------------accelerate interface-----------*/
	.carry_in			(cin_l),
	.prompt 			(ds_ctrl[12]),        		// ds_ctrl[12]
	.seq_mode			(ds_ctrl[13]), 			// ds_ctrl[13]

	.vout_0   			(vout[0]),
	.vout_1 			(vout[1]),
	.vout_2 			(vout[2]),
	.vout_3 			(vout[3]),
	.vout_4 			(vout[4]),
	.vout_5 			(vout[5]),
	.vout_6 			(vout[6]),
	.vout_7 			(vout[7]),
	.vout_8 			(vout[8]),
	.vout_9 			(vout[9]),
	.vout_10  			(vout[10]),
	.vout_11  			(vout[11]),
	.vout_12  			(vout[12]),
	.vout_13  			(vout[13]),
	.vout_14  			(vout[14]),
	.vout_15  			(vout[15])

);

assign cin_h = vout[15]; 

ds_para_add_16  #(

	.DATA_WIDTH(DATA_WIDTH),   //32
	.CODE_WIDTH(5),
	.FORM_WIDTH(FORM_WIDTH),     //32
	.GEN_TYPE(FRAG_TYPE)

) ds_add_16_h(
	.clk 				(clk),
	.rst 				(rst),

	.para_chain         (para_data[1023 : 512]),	
	.vadd				(pep_data_h),

	.mass_type			(ds_ctrl[1]),
	.add_en 			(data_en_r), 

/*------------accelerate interface-----------*/
	.carry_in			(cin_h),
	.prompt 			(ds_ctrl[12]),        		// ds_ctrl[12]
	.seq_mode			(ds_ctrl[13]), 				// ds_ctrl[13]

	.vout_0   			(vout[16]),
	.vout_1 			(vout[17]),
	.vout_2 			(vout[18]),
	.vout_3 			(vout[19]),
	.vout_4 			(vout[20]),
	.vout_5 			(vout[21]),
	.vout_6 			(vout[22]),
	.vout_7 			(vout[23]),
	.vout_8 			(vout[24]),
	.vout_9 			(vout[25]),
	.vout_10  			(vout[26]),
	.vout_11  			(vout[27]),
	.vout_12  			(vout[28]),
	.vout_13  			(vout[29]),
	.vout_14  			(vout[30]),
	.vout_15  			(vout[31])

);


always @(posedge clk or posedge rst) begin
	if (rst) begin
		data_en <= 1'b0;
		data_cnt <= 5'b0;
	end
	else if ((current == FRAG_GEN) & (~calc_done))begin
		data_en <= 1'b1; 
		data_cnt <= data_cnt + 5'b1;
	end
	else begin
		data_en <= 1'b0;
		data_cnt <= 5'b0;
	end
end

always @(posedge clk or posedge rst) begin
	if (rst) 
		data_en_r <= 1'b0;
	else if(data_en)
		data_en_r <= 1'b1;
	else
		data_en_r <= 1'b0;
end

reg 	[4 : 0] 	xw_addr;
reg                 xw_en;
wire	[32 * 40 - 1 : 0]	vout_cb;
assign vout_cb 	= 	{vout[31][39:0], vout[30][39:0], vout[29][39:0], vout[28][39:0], vout[27][39:0], vout[26][39:0], vout[25][39:0], vout[24][39:0],
					 vout[23][39:0], vout[22][39:0], vout[21][39:0], vout[20][39:0], vout[19][39:0], vout[18][39:0], vout[17][39:0], vout[16][39:0],
					 vout[15][39:0], vout[14][39:0], vout[13][39:0], vout[12][39:0], vout[11][39:0], vout[10][39:0],  vout[9][39:0],  vout[8][39:0],
				 	  vout[7][39:0],  vout[6][39:0],  vout[5][39:0],  vout[4][39:0],  vout[3][39:0],  vout[2][39:0],  vout[1][39:0],  vout[0][39:0]};

assign 	store_finish = (data_cnt == store_deep[4:0] + pipline_delay) & data_en;

always @(posedge clk or posedge rst) begin
	if (rst) 
		frag_ready = 1'b0;
	else if (store_finish & (current == FRAG_GEN)) 
		frag_ready = 1'b1;
	else if (ds_done & (current == DONE_WAIT))
		frag_ready = 1'b0;
end

always @(posedge clk or posedge rst)
begin
 	if(rst) 
		xw_en <= 1'b0; 
	else if(data_en && (data_cnt == pipline_delay)) 
		xw_en <= 1'b1;
	else if(store_finish) 
		xw_en <= 1'b0;
	else 
		xw_en <= xw_en;
end

always @(posedge clk or posedge rst)
begin
	if(rst)
		xw_addr <= 5'b0;
	else if(xw_en & (~store_finish))
		xw_addr <= xw_addr + 5'b1;
	else if(ds_done)
		xw_addr <= 5'b0;
	else 
		xw_addr <= xw_addr;
end

 x_bram_store x_value_store
  (
    .clka(clk),
    .ena(xw_en),
    .wea(xw_en),
    .addra(xw_addr),
    .dina(vout_cb),
    .clkb(clk),
    .enb(~xw_en),                      //input xr_en
    .addrb(xr_addr),                 //input xr_addr[4:0]
    .doutb(xr_data)       //output xr_data[1279:0] 
  );

/*---------------------------- y_value generate ---------------------------------*/
generate
	if (FRAG_TYPE == `Y_TYPE || FRAG_TYPE == `Z_TYPE) begin: y_value

		wire [3 : 0] COEF_B [0 : 26];
		wire [3 : 0] COEF_Y [0 : 26];
		
		assign COEF_B[0 ] = 4'h0;
		assign COEF_B[1 ] = 4'h1;
		assign COEF_B[2 ] = 4'h1;
		assign COEF_B[3 ] = 4'h1;
		assign COEF_B[4 ] = 4'h5;
		assign COEF_B[5 ] = 4'h3;
		assign COEF_B[6 ] = 4'h1;
		assign COEF_B[7 ] = 4'h1;
		assign COEF_B[8 ] = 4'h1;
		assign COEF_B[9 ] = 4'h3;
		assign COEF_B[10] = 4'h1;
		assign COEF_B[11] = 4'h1;
		assign COEF_B[12] = 4'h3;
		assign COEF_B[13] = 4'h1;
		assign COEF_B[14] = 4'h2;
		assign COEF_B[15] = 4'h1;
		assign COEF_B[16] = 4'h1;
		assign COEF_B[17] = 4'h2;
		assign COEF_B[18] = 4'h1;
		assign COEF_B[19] = 4'h1;
		assign COEF_B[20] = 4'h1;
		assign COEF_B[21] = 4'h1;
		assign COEF_B[22] = 4'h3;
		assign COEF_B[23] = 4'h1;
		assign COEF_B[24] = 4'h1;
		assign COEF_B[25] = 4'h1;
		assign COEF_B[26] = 4'h1;
		
		assign COEF_Y[0 ] = 4'h0;
		assign COEF_Y[1 ] = 4'h1;
		assign COEF_Y[2 ] = 4'h1;
		assign COEF_Y[3 ] = 4'h1;
		assign COEF_Y[4 ] = 4'h1;
		assign COEF_Y[5 ] = 4'h1;
		assign COEF_Y[6 ] = 4'h1;
		assign COEF_Y[7 ] = 4'h1;
		assign COEF_Y[8 ] = 4'h1;
		assign COEF_Y[9 ] = 4'h1;
		assign COEF_Y[10] = 4'h1;
		assign COEF_Y[11] = 4'h1;
		assign COEF_Y[12] = 4'h1;
		assign COEF_Y[13] = 4'h1;
		assign COEF_Y[14] = 4'h1;
		assign COEF_Y[15] = 4'h1;
		assign COEF_Y[16] = 4'h5;
		assign COEF_Y[17] = 4'h1;
		assign COEF_Y[18] = 4'h1;
		assign COEF_Y[19] = 4'h1;
		assign COEF_Y[20] = 4'h1;
		assign COEF_Y[21] = 4'h1;
		assign COEF_Y[22] = 4'h1;
		assign COEF_Y[23] = 4'h1;
		assign COEF_Y[24] = 4'h1;
		assign COEF_Y[25] = 4'h1;
		assign COEF_Y[26] = 4'h1;
		
		reg [4 : 0] pre_in;
		always @ (posedge clk or posedge rst)
		begin
			if(rst)
				pre_in <= 5'h0;
			else if(data_en)
				pre_in <= pep_data_r[FORM_WIDTH * 5 - 1 : FORM_WIDTH * 5 - 5];
			else 
				pre_in <= 5'h0;	
		end
		
		reg   			yw_en;
		reg   [4 : 0] 	yw_addr;
		
		
		wire [7 : 0] y_value[0 : 31];
		
		
		assign  y_value[0] = (current == FRAG_GEN) ? (COEF_Y[pre_in] * COEF_B[pep_data_r[4 : 0]]) : 8'h0; 
		/*generate
			genvar j;
				for(j = 1; j < 28; j = j + 1) begin
					assign y_value[j] = (current == FRAG_GEN) ? (COEF_Y[pep_data[(j-1) * 5 +: 5]] * COEF_B[pep_data[j * 5 +: 5]]) : 8'h0;
				end	
		endgenerate
		*/
		assign y_value[1]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[0 +: 5]]  * COEF_B[pep_data_r[5 +: 5]]) : 8'h0;
		assign y_value[2]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[5 +: 5]]  * COEF_B[pep_data_r[10 +: 5]]) : 8'h0;
		assign y_value[3]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[10 +: 5]] * COEF_B[pep_data_r[15 +: 5]]) : 8'h0;
		assign y_value[4]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[15 +: 5]] * COEF_B[pep_data_r[20 +: 5]]) : 8'h0;
		assign y_value[5]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[20 +: 5]] * COEF_B[pep_data_r[25 +: 5]]) : 8'h0;
		assign y_value[6]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[25 +: 5]] * COEF_B[pep_data_r[30 +: 5]]) : 8'h0;
		assign y_value[7]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[30 +: 5]] * COEF_B[pep_data_r[35 +: 5]]) : 8'h0;
		assign y_value[8]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[35 +: 5]] * COEF_B[pep_data_r[40 +: 5]]) : 8'h0;
		assign y_value[9]  = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[40 +: 5]] * COEF_B[pep_data_r[45 +: 5]]) : 8'h0;
		assign y_value[10] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[45 +: 5]] * COEF_B[pep_data_r[50 +: 5]]) : 8'h0;
		assign y_value[11] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[50 +: 5]] * COEF_B[pep_data_r[55 +: 5]]) : 8'h0;
		assign y_value[12] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[55 +: 5]] * COEF_B[pep_data_r[60 +: 5]]) : 8'h0;
		assign y_value[13] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[60 +: 5]] * COEF_B[pep_data_r[65 +: 5]]) : 8'h0;
		assign y_value[14] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[65 +: 5]] * COEF_B[pep_data_r[70 +: 5]]) : 8'h0;
		assign y_value[15] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[70 +: 5]] * COEF_B[pep_data_r[75 +: 5]]) : 8'h0;
		assign y_value[16] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[75 +: 5]] * COEF_B[pep_data_r[80 +: 5]]) : 8'h0;
		assign y_value[17] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[80 +: 5]] * COEF_B[pep_data_r[85 +: 5]]) : 8'h0;
		assign y_value[18] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[85 +: 5]] * COEF_B[pep_data_r[90 +: 5]]) : 8'h0;
		assign y_value[19] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[90 +: 5]] * COEF_B[pep_data_r[95 +: 5]]) : 8'h0;
		assign y_value[20] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[95 +: 5]] * COEF_B[pep_data_r[100 +: 5]]) : 8'h0;
		assign y_value[21] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[100 +: 5]] * COEF_B[pep_data_r[105 +: 5]]) : 8'h0;
		assign y_value[22] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[105 +: 5]] * COEF_B[pep_data_r[110 +: 5]]) : 8'h0;
		assign y_value[23] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[110 +: 5]] * COEF_B[pep_data_r[115 +: 5]]) : 8'h0;
		assign y_value[24] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[115 +: 5]] * COEF_B[pep_data_r[120 +: 5]]) : 8'h0;
		assign y_value[25] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[120 +: 5]] * COEF_B[pep_data_r[125 +: 5]]) : 8'h0;
		assign y_value[26] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[125 +: 5]] * COEF_B[pep_data_r[130 +: 5]]) : 8'h0;
		assign y_value[27] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[130 +: 5]] * COEF_B[pep_data_r[135 +: 5]]) : 8'h0;
		/* for Y_TYPE */
		wire [7 : 0] y_value_y[0 : 3];
		assign y_value_y[0] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? (COEF_B[pep_data_r[144: 140]] * COEF_Y[pep_data_r[139: 135]]) : (COEF_B[pep_data_r[144: 140]] * COEF_Y[pep_data_r[139: 135]])) : 8'h0;
		
		assign y_value_y[1] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? (COEF_B[pep_data_r[149: 145]] * COEF_Y[pep_data_r[144: 140]]) : (COEF_B[pep_data_r[149: 145]] * COEF_Y[pep_data_r[144: 140]])) : 8'h0;
		
		assign y_value_y[2] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ?  ((pep_data_r[154:150] == 5'h10) ? 10 * COEF_B[pep_data_r[154: 150]] * COEF_Y[pep_data_r[149: 145]] 
																								 								 : 3 * COEF_B[pep_data_r[154: 150]] * COEF_Y[pep_data_r[149: 145]] )
																		     	   : COEF_B[pep_data_r[154: 150]] * COEF_Y[pep_data_r[149: 145]]) : 8'h0;
		
		
		assign y_value_y[3] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? COEF_B[pep_data_r[159: 155]] * COEF_Y[pep_data_r[154: 150]] : COEF_B[pep_data_r[159: 155]] * COEF_Y[pep_data_r[154: 150]]) : 8'h0;
		
		/* for Z_TYPE */
		wire [7 : 0] y_value_z[0 : 3];
		assign y_value_z[0] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[135 +: 5]] * COEF_B[pep_data_r[140 +: 5]]) : 8'h0;
		assign y_value_z[1] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[140 +: 5]] * COEF_B[pep_data_r[145 +: 5]]) : 8'h0;
		assign y_value_z[2] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[145 +: 5]] * COEF_B[pep_data_r[150 +: 5]]) : 8'h0;
		assign y_value_z[3] = (current == FRAG_GEN) ? (COEF_Y[pep_data_r[150 +: 5]] * COEF_B[pep_data_r[155 +: 5]]) : 8'h0;


		/* combine the value */
		assign y_value[28] = (FRAG_TYPE == `Y_TYPE) ? y_value_y[0] : ((FRAG_TYPE == `Z_TYPE) ? y_value_z[0] : 8'h0);
		assign y_value[29] = (FRAG_TYPE == `Y_TYPE) ? y_value_y[1] : ((FRAG_TYPE == `Z_TYPE) ? y_value_z[1] : 8'h0);
		assign y_value[30] = (FRAG_TYPE == `Y_TYPE) ? y_value_y[2] : ((FRAG_TYPE == `Z_TYPE) ? y_value_z[2] : 8'h0);
		assign y_value[31] = (FRAG_TYPE == `Y_TYPE) ? y_value_y[3] : ((FRAG_TYPE == `Z_TYPE) ? y_value_z[3] : 8'h0);
		
		wire [8 * 32 - 1 : 0] y_value_cb;
		
		assign y_value_cb = { y_value[31], y_value[30], y_value[29], y_value[28], y_value[27], y_value[26], y_value[25], y_value[24], 
							  y_value[23], y_value[22], y_value[21], y_value[20], y_value[19], y_value[18], y_value[17], y_value[16],  
							  y_value[15], y_value[14], y_value[13], y_value[12], y_value[11], y_value[10], y_value[9],  y_value[8],
							  y_value[7],  y_value[6],  y_value[5],  y_value[4],  y_value[3],  y_value[2],  y_value[1],  y_value[0]}; 
		
		
		
		/*------------------ storing y_value ----------------*/
		
		always @(posedge clk or posedge rst)
		begin
		 	if(rst) 
				yw_en <= 1'b0; 
			else if(current == FRAG_GEN && (data_cnt < store_deep[4:0])) 
				yw_en <= 1'b1;
			else 
				yw_en <= 1'b0;
		end
		
		always @(posedge clk or posedge rst)
		begin
			if(rst)
				yw_addr <= 5'b0;
			else if(data_en & (data_cnt < store_deep[4:0]))
				yw_addr <= yw_addr + 5'b1;
			else if(ds_done)
				yw_addr <= 5'b0;
			else 
				yw_addr <= yw_addr;
		end
		
		y_bram_store y_value_store        //b_zero = 0
		  (
		    .clka 	(clk),
		    .ena 	(yw_en),
		    .wea 	(yw_en),
		    .addra 	(yw_addr),
		    .dina   (y_value_cb),
		    .clkb 	(clk), 
		    .enb 	(~yw_en),
		    .addrb  (xr_addr),
		    .doutb  (yr_data)
		  );	
/*	end
endgenerate		*/
		/*----------------- just for Y_TYPE for b_zero = 1  ---------------*/
/*
generate
	if (FRAG_TYPE == `Y_TYPE) begin: y_seg_value */
		wire [7 : 0] y_value_1[0 : 3];
		assign y_value_1[0] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? (COEF_B[pep_data_r[144: 140]] * COEF_Y[pep_data_r[139: 135]]) : 8'h0) : 8'h0;
		assign y_value_1[1] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? (COEF_B[pep_data_r[149: 145]] * COEF_Y[pep_data_r[144: 140]]) : 8'h0) : 8'h0;
		assign y_value_1[2] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? COEF_B[pep_data_r[154: 150]] * COEF_Y[pep_data_r[149: 145]] : 8'h0) : 8'h0;
		assign y_value_1[3] = (current == FRAG_GEN) ? ((yw_addr == store_deep[4:0] - 1) ? COEF_B[pep_data_r[159: 155]] * COEF_Y[pep_data_r[154: 150]] : 8'h0) : 8'h0;
		
		always @(posedge clk or posedge rst) begin
			if (rst) 
				x_value_1_reg <= 160'h0;
			else if (xw_en & (xw_addr == store_deep[4:0] - 1))
				x_value_1_reg <= { vout[30][39:0], vout[29][39:0], vout[28][39:0], vout[27][39:0]};
			else
				x_value_1_reg <= x_value_1_reg;
		end
		
		always @(posedge clk or posedge rst) begin
			if (rst)
				y_value_1_reg <= 32'h0;
			else if (yw_en & (yw_addr == store_deep[4:0] - 1))
				y_value_1_reg <= {y_value_1[3], y_value_1[2], y_value_1[1], y_value_1[0]};
			else
				y_value_1_reg <= y_value_1_reg; 
		end		
	end
endgenerate

endmodule