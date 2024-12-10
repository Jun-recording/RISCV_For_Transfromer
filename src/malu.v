module malu
#(
    parameter INT_BIT = 5,
    parameter FRAC_BIT = 11,
    parameter DWIDTH = 16,
    parameter REG_DWIDTH = 32,
    parameter RAM_DWIDTH = 32,
    parameter RAM0_SIZE = 65536,    //256*256
    parameter RAM1_SIZE = 65536
)
(
    //From system
    input   clk, arst_n,

    //From controller
    input   i_en,
    input  [2:0] i_command,

    //From reg file
    input [REG_DWIDTH-1:0] i_m1_size, i_m2_size,        //Softmax, relu only use m1
    input [REG_DWIDTH-1:0] i_m1_address, i_m2_address,  //Softmax, relu only use m1
    input [REG_DWIDTH-1:0] i_dest_address,      

    output [2:0] o_status,   //{done, busy(run), idle}

    //Memory I/F MRAM0
    // output [REG_DWIDTH-1:0] addr0_cnt_mram0,    
    // output ce0_mram0,
    // output we0_mram0,
    // output [RAM_DWIDTH-1:0] d0_mram0,
    // input [RAM_DWIDTH-1:0] q0_mram0,

    input [REG_DWIDTH-1:0] i_addr1_cnt_mram0,    
    input i_ce1_mram0,
    input i_we1_mram0,
    input [RAM_DWIDTH-1:0] i_d1_mram0,
    output [RAM_DWIDTH-1:0] o_q1_mram0,

    //Memory I/F MRAM1
    // output [REG_DWIDTH-1:0] addr0_cnt_mram1, 
    // output ce0_mram1,
    // output we0_mram1,
    // output [RAM_DWIDTH-1:0] d0_mram1,
    // input [RAM_DWIDTH-1:0] q0_mram1,

    input [REG_DWIDTH-1:0] i_addr1_cnt_mram1, 
    input i_ce1_mram1,
    input i_we1_mram1,
    input [RAM_DWIDTH-1:0] i_d1_mram1,
    output [RAM_DWIDTH-1:0] o_q1_mram1
);

    wire w_finish; //Module operate complete

    /////////////////////////////State machine///////////////////////////////////
    localparam S_IDLE    = 3'b001;
    localparam S_RUN     = 3'b010;
    localparam S_DONE    = 3'b100;

    reg [2:0] p_state; 
    reg [2:0] n_state;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            p_state <= S_IDLE;
        else
            p_state <= n_state;
    end
    
    always @ (*) begin
        case (p_state)
            S_IDLE : n_state = i_en ? S_RUN : S_IDLE;
            S_RUN : n_state = w_finish==1'b1 ? S_DONE : S_RUN;
            S_DONE : n_state = S_IDLE;
            default : n_state = S_IDLE;
        endcase
    end

    assign o_status = p_state;  //{done, busy(run), idle}


    /////////////////////////////Command Check///////////////////////////////////
    //Command define
    localparam C_IDLE = 3'b000;
    localparam C_MMUL = 3'b001;
    localparam C_MADD = 3'b010;
    localparam C_SFMX = 3'b011;
    localparam C_RELU = 3'b100;
    localparam C_LOAD = 3'b101;
    localparam C_STRE = 3'b110;

    reg [2:0] r_command;
    reg [(REG_DWIDTH)/2-1:0] r_m1_length, r_m2_length, r_m1_width, r_m2_width;
    reg [REG_DWIDTH-1:0] r_m1_address, r_m2_address;
    reg [REG_DWIDTH-1:0] r_dest_address;
    reg [REG_DWIDTH-1:0] r_out_size;

    //Latching command
    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            r_command <= C_IDLE;
            r_m1_length <= 0;
            r_m2_length <= 0;
            r_m1_width <= 0;
            r_m2_width <= 0;
            //r_out_size <= 0;
            r_m1_address <= 0;
            r_m2_address <= 0;
            r_dest_address <= 0;
        end
        else if ((p_state==S_IDLE) && i_en) begin
            r_command <= i_command;
            r_m1_length <= i_m1_size[REG_DWIDTH-1:(REG_DWIDTH)/2];
            r_m2_length <= i_m2_size[REG_DWIDTH-1:(REG_DWIDTH)/2];
            r_m1_width  <= i_m1_size[(REG_DWIDTH)/2-1:0];
            r_m2_width  <= i_m2_size[(REG_DWIDTH)/2-1:0];
            //r_out_size <= i_m1_size[REG_DWIDTH-1:(REG_DWIDTH)/2] * i_m2_size[(REG_DWIDTH)/2-1:0];
            r_m1_address <= i_m1_address;
            r_m2_address <= i_m2_address;
            r_dest_address <= i_dest_address;
        end
    end

    wire mmul_en;
    wire madd_en;
    wire sfmx_en;
    wire relu_en;
    assign mmul_en = (r_command==C_MMUL) && (p_state==S_RUN);
    assign madd_en = (r_command==C_MADD) && (p_state==S_RUN);
    assign sfmx_en = (r_command==C_SFMX) && (p_state==S_RUN);
    assign relu_en = (r_command==C_RELU) && (p_state==S_RUN);

    /////////////////////////////Double Buffered Memory I/F///////////////////////////////////
    //Memory I/F for read port (core)
    reg [REG_DWIDTH-1:0] addr0_cnt;   
    wire ce0;
    wire we0;
    wire [RAM_DWIDTH-1:0] d0;
    reg [RAM_DWIDTH-1:0] q0;
    
    //Memory I/F for write port (core)
    reg [REG_DWIDTH-1:0] addr1_cnt;   
    wire ce1;
    wire we1;
    reg [RAM_DWIDTH-1:0] d1;
    reg [RAM_DWIDTH-1:0] q1;

    //Memory I/F MRAM0
    reg [REG_DWIDTH-1:0] addr0_cnt_mram0;   
    reg ce0_mram0;
    reg we0_mram0;
    reg [RAM_DWIDTH-1:0] d0_mram0;
    wire [RAM_DWIDTH-1:0] q0_mram0;

    reg [REG_DWIDTH-1:0] addr1_cnt_mram0;    
    reg ce1_mram0;
    reg we1_mram0;
    reg [RAM_DWIDTH-1:0] d1_mram0;
    wire [RAM_DWIDTH-1:0] q1_mram0;

    //Memory I/F MRAM1
    reg [REG_DWIDTH-1:0] addr0_cnt_mram1;
    reg ce0_mram1;
    reg we0_mram1;
    reg [RAM_DWIDTH-1:0] d0_mram1;
    wire [RAM_DWIDTH-1:0] q0_mram1;

    reg [REG_DWIDTH-1:0] addr1_cnt_mram1; 
    reg ce1_mram1;
    reg we1_mram1;
    reg [RAM_DWIDTH-1:0] d1_mram1;
    wire [RAM_DWIDTH-1:0] q1_mram1;

    //for mmul address control
    wire [RAM_DWIDTH-1:0] w_mem_a_d0;
    wire [REG_DWIDTH-1:0] w_mem_a_addr0;
    wire w_mem_a_ce0;
    wire w_mem_a_we0;

    wire [RAM_DWIDTH-1:0] w_mem_a_d1;
    wire [REG_DWIDTH-1:0] w_mem_a_addr1;
    wire w_mem_a_ce1;
    wire w_mem_a_we1;
    reg [RAM_DWIDTH-1:0] w_mem_a_q1;

    wire [RAM_DWIDTH-1:0] w_mem_b_d0;
    wire [REG_DWIDTH-1:0] w_mem_b_addr0;
    wire w_mem_b_ce0;
    wire w_mem_b_we0;
    reg [RAM_DWIDTH-1:0] w_mem_b_q0;

    wire [RAM_DWIDTH-1:0] w_mem_b_d1;
    wire [REG_DWIDTH-1:0] w_mem_b_addr1;
    wire w_mem_b_ce1;
    wire w_mem_b_we1;

    wire w_mmul_idle;
    wire w_mmul_busy;
    wire w_mmul_done;

    //Ram select signal
    reg ram_ptr;
    reg ptr_cvt_flag;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            ptr_cvt_flag <= 0;
        else if (p_state[1] && i_command==C_LOAD && i_en)
            ptr_cvt_flag <= 1;
        else if (p_state[2])
            ptr_cvt_flag <= 0;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            ram_ptr <= 0;
        else if (ptr_cvt_flag && p_state[2])
            ram_ptr <= ~ram_ptr;
    end

    //Read port select
    always @ (*) begin
        if (mmul_en) begin
            addr0_cnt_mram0 = addr0_cnt;
            ce0_mram0 = ce0;
            we0_mram0 = we0;
            d0_mram0 = d0;
            addr1_cnt_mram0 = w_mem_a_addr1;
            ce1_mram0 = w_mem_a_ce1;
            we1_mram0 = w_mem_a_we1;
            d1_mram0 = w_mem_a_d1;
            
            addr0_cnt_mram1 = w_mem_b_addr1;
            ce0_mram1 = w_mem_b_we1;
            we0_mram1 = w_mem_b_we1;
            d0_mram1 = w_mem_b_d1;
            addr1_cnt_mram1 = addr1_cnt;
            ce1_mram1 = ce1;
            we1_mram1 = we1;
            d1_mram1 = d1;
            
            q0 = q0_mram0;
            w_mem_a_q1 = q1_mram0;
            w_mem_b_q0 = q0_mram1;
            q1 = q1_mram1;
        end
        else if (!ram_ptr) begin
            addr0_cnt_mram0 = addr0_cnt;
            ce0_mram0 = ce0;
            we0_mram0 = we0;
            d0_mram0 = d0;
            addr1_cnt_mram0 = addr1_cnt;
            ce1_mram0 = ce1;
            we1_mram0 = we1;
            d1_mram0 = d1;
            
            addr0_cnt_mram1 = 0;
            ce0_mram1 = 0;
            we0_mram1 = 0;
            d0_mram1 = 0;
            addr1_cnt_mram1 = 0;
            ce1_mram1 = 0;
            we1_mram1 = 0;
            d1_mram1 = 0;

            q0 = q0_mram0;
            q1 = q1_mram0; 
        end
        else if (ram_ptr) begin
            addr0_cnt_mram0 = 0;
            ce0_mram0 = 0;
            we0_mram0 = 0;
            d0_mram0 = 0;
            addr1_cnt_mram0 = 0;
            ce1_mram0 = 0;
            we1_mram0 = 0;
            d1_mram0 = 0;

            addr0_cnt_mram1 = addr0_cnt;
            ce0_mram1 = ce0;
            we0_mram1 = we0;
            d0_mram1 = d0;
            addr1_cnt_mram1 = addr1_cnt;
            ce1_mram1 = ce1;
            we1_mram1 = we1;
            d1_mram1 = d1;

            q0 = q0_mram1;
            q1 = q1_mram1;  
        end
    end

    /////////////////////////////Operation Controll///////////////////////////////////
    wire w_valid;
    //wire w_valid_mm;
    wire w_valid_ma;
    wire w_valid_sm;
    wire w_valid_rl;
    wire w_exp_valid;
    wire w_recip_valid;

    assign w_valid = w_valid_ma || w_valid_sm || w_valid_rl;

    //r_recip_valid for 1 tick for softmax address control
	reg r_recip_valid;
    wire w_recip_valid_t_p;
    wire w_recip_valid_t_n;

	always @ (posedge clk, negedge arst_n) begin 
    	if(!arst_n) begin
    	    r_recip_valid <= 1'b0;  
    	end 
        else if (p_state[1]) begin
            r_recip_valid <= w_recip_valid;
		end 
	end
	
	assign w_recip_valid_t_p = (r_recip_valid == 1'b0) && (w_recip_valid == 1'b1) ; // Posedge 1 tick
    assign w_recip_valid_t_n = (r_recip_valid == 1'b1) && (w_recip_valid == 1'b0) ; // negedge 1 tick


    //for madd address control
    reg madd_sel;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            madd_sel <= 0;
        else if (madd_en)
            madd_sel <= ~madd_sel;
        else
            madd_sel <= 0;
    end

    //Read port
    reg [REG_DWIDTH-1:0] addr0_cnt_temp1;
    reg [REG_DWIDTH-1:0] addr0_cnt_temp2;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            addr0_cnt_temp1 <= 0;
            addr0_cnt_temp2 <= 0;
        end
        else if (madd_en) begin
            if (madd_sel)
                addr0_cnt_temp1 <= addr0_cnt_temp1 + 1;
            else if (!madd_sel)
                addr0_cnt_temp2 <= addr0_cnt_temp2 + 1;
        end
        else if (p_state[0] && i_en) begin
            addr0_cnt_temp1 <= i_m1_address;
            addr0_cnt_temp2 <= i_m2_address;
        end
    end

    reg [REG_DWIDTH-1:0] addr0_cnt_temp;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            addr0_cnt_temp <= 0;
        else if (p_state[1] && w_recip_valid_t_p)
            addr0_cnt_temp <= addr0_cnt;
        else if (p_state[1] && w_recip_valid_t_n)
            addr0_cnt_temp <= addr0_cnt;
        else if (p_state[0] && i_en)
            addr0_cnt_temp <= i_dest_address;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            addr0_cnt <= 0;
        else if (mmul_en) begin
            addr0_cnt <= w_mem_a_addr0;
        end
        else if (madd_en) begin
            if (madd_sel)
                addr0_cnt <= addr0_cnt_temp1;
            else if (!madd_sel)
                addr0_cnt <= addr0_cnt_temp2;
        end
        else if (relu_en) begin
            addr0_cnt <= addr0_cnt + 1;
        end
        else if (sfmx_en) begin
            if (w_recip_valid_t_p)
                addr0_cnt <= addr0_cnt_temp;
            else if (w_recip_valid_t_n)
                addr0_cnt <= addr0_cnt_temp;
            else
                addr0_cnt <= addr0_cnt + 1;
        end
        else if (p_state[0] && i_en) begin
            addr0_cnt <= i_m1_address;
        end
    end

    assign ce0 = p_state[1] || i_en || w_mem_a_ce0;
    assign we0 = w_mem_a_we0;
    assign d0 = 0;

    //write port
    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            addr1_cnt <= 0;
        else if (mmul_en)
            addr1_cnt <= w_mem_b_addr1;
        else if (p_state[1] && (w_valid || w_exp_valid))
            addr1_cnt <= addr1_cnt + 1;
        else if (p_state[0] && i_en)
            addr1_cnt <= (i_command==C_MADD) ? i_dest_address : i_m2_address;
    end

    assign ce1 = p_state[1] && (w_valid || w_exp_valid) || w_mem_b_ce1;
    assign we1 = p_state[1] && (w_valid || w_exp_valid) || w_mem_b_we1;

    reg [DWIDTH-1:0] width_cnt;
    reg [DWIDTH-1:0] length_cnt;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            width_cnt <= 1;
        else if (p_state[1] && w_valid)
            width_cnt <= (width_cnt == (r_m1_width>>1)) ? 1 : width_cnt + 1;
        else if (p_state[2])
            width_cnt <= 1;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            length_cnt <= 1;
        else if (p_state[1] && w_valid && (width_cnt == (r_m1_width>>1)))
            length_cnt <= length_cnt + 1;
        else if (p_state[2])
            length_cnt <= 1;
    end

    assign w_finish = (w_valid && (width_cnt == (r_m1_width>>1)) && (length_cnt == r_m1_length)) || w_mmul_done;

    wire [RAM_DWIDTH-1:0] w_mmul_out;
    wire [RAM_DWIDTH-1:0] w_madd_out;
    wire [RAM_DWIDTH-1:0] w_sfmx_out;
    wire [RAM_DWIDTH-1:0] w_relu_out;
    wire [RAM_DWIDTH-1:0] w_exp_out;

    always @ (*) begin
        case(r_command)
            C_MMUL : d1 = w_mmul_out;
            C_MADD : d1 = w_madd_out;
            C_SFMX : d1 = w_exp_valid ? w_exp_out : w_sfmx_out;
            C_RELU : d1 = w_relu_out;
            default : d1 = 0;
        endcase
    end

    assign o_q1_mram0 = p_state[1]||i_en ? 0 : q1_mram0;
    assign o_q1_mram1 = p_state[1]||i_en ? 0 : q1_mram1;

    /////////////////////////////Module Initialization///////////////////////////////////

    mmul #(
        .DATA_WIDTH(DWIDTH),
        .FRACTION_BITS(FRAC_BIT)
    ) mm_inst (
        .clk(clk),
        .arst_n(arst_n),
        .i_run(mmul_en),
        .i_a_row_width(r_m1_length),
        .i_a_col_width(r_m1_width),
        .i_b_row_width(r_m2_length),
        .i_b_col_width(r_m2_width),
        
        // .i_a_address(r_m1_address),
        // .i_b_address(r_m2_address),
        // .i_dest_address(r_dest_address),

        .o_s_idle(w_mmul_idle),
        .o_s_busy(w_mmul_busy),
        .o_s_done(w_mmul_done),

        .mem_a_d0(w_mem_a_d0),
        .mem_a_addr0(w_mem_a_addr0),
        .mem_a_ce0(w_mem_a_ce0),
        .mem_a_we0(w_mem_a_we0),
        .mem_a_q0(q0),

        .mem_a_d1(w_mmul_out),
        .mem_a_addr1(w_mem_a_addr1),
        .mem_a_ce1(w_mem_a_ce1),
        .mem_a_we1(w_mem_a_we1),
        .mem_a_q1(w_mem_a_q1),

        .mem_b_d0(w_mem_b_d0),
        .mem_b_addr0(w_mem_b_addr0),
        .mem_b_ce0(w_mem_b_ce0),
        .mem_b_we0(w_mem_b_we0),
        .mem_b_q0(w_mem_b_q0),

        .mem_b_d1(w_mmul_out),
        .mem_b_addr1(w_mem_b_addr1),
        .mem_b_ce1(w_mem_b_ce1),
        .mem_b_we1(w_mem_b_we1),
        .mem_b_q1(q1)
    );

    madd #(
        .DWIDTH(RAM_DWIDTH)
    ) ma_inst (
        .clk(clk),
        .arst_n(arst_n),
        .i_en(madd_en),
        .i_in(q0),
        .o_out(w_madd_out),
        .o_valid(w_valid_ma)
    );

    softmax #(
        .CNT_BIT(16),
        .INT_BIT(INT_BIT),
        .FRAC_BIT(FRAC_BIT),
        .DWIDTH(DWIDTH),
        .NR_ITERATIONS(4)
    ) sm_inst (
        .clk(clk),
        .arst_n(arst_n),
        .enable(sfmx_en),
        .i_in0(q0[RAM_DWIDTH-1:DWIDTH]),   
        .i_in1(q0[DWIDTH-1:0]),
        .i_exp0(q0[RAM_DWIDTH-1:DWIDTH]),
        .i_exp1(q0[DWIDTH-1:0]),
        .i_num(r_m1_width),      //the number of input

        .o_exp_out(w_exp_out),
        .o_exp_valid(w_exp_valid),
        .o_recip_valid(w_recip_valid),
        .o_out(w_sfmx_out),
        .o_valid(w_valid_sm)
    );

    relu #(
        .DWIDTH(RAM_DWIDTH)
    ) rl_inst (
        .clk(clk),
        .arst_n(arst_n),
        .i_en(relu_en),
        .i_in(q0),
        .o_out(w_relu_out),
        .o_valid(w_valid_rl)
    );

    dp_bram_r #(
        .DWIDTH(RAM_DWIDTH),
        .AWIDTH(REG_DWIDTH),
        .MEM_SIZE(RAM0_SIZE)
    ) bram0 (
        .clk		(clk), 
    //Use Core
		.addr0		(addr0_cnt_mram0), 
		.ce0		(ce0_mram0  	), 
		.we0		(we0_mram0  	), 
		.q0			(q0_mram0   	), 
		.d0			(d0_mram0   	), 
	//Use AXI4 & Core
        .addr1 		(p_state[1]||i_en ? addr1_cnt_mram0 : i_addr1_cnt_mram0), 
		.ce1		(p_state[1]||i_en ? ce1_mram0	: i_ce1_mram0           ), 
		.we1		(p_state[1]||i_en ? we1_mram0	: i_we1_mram0		    ),
		.q1			(q1_mram0	                                     ), 
		.d1			(p_state[1]||i_en ? d1_mram0 : i_d1_mram0		        )
		// .addr1 		(!ram_ptr ? addr1_cnt_mram0 : i_addr1_cnt_mram0), 
		// .ce1		(!ram_ptr ? ce1_mram0	: i_ce1_mram0           ), 
		// .we1		(!ram_ptr ? we1_mram0	: i_we1_mram0		    ),
		// .q1			(q1_mram0	                                     ), 
		// .d1			(!ram_ptr ? d1_mram0 : i_d1_mram0		        )
        // .addr1 		(i_addr1_cnt_mram0), 
		// .ce1		(i_ce1_mram0           ), 
		// .we1		(i_we1_mram0		    ),
		// .q1			(o_q1_mram0	            ), 
		// .d1			(i_d1_mram0		        )
    );

    dp_bram_r #(
        .DWIDTH(RAM_DWIDTH),
        .AWIDTH(REG_DWIDTH),
        .MEM_SIZE(RAM1_SIZE)
    ) bram1 (
        .clk		(clk), 
    //Use Core
		.addr0		(addr0_cnt_mram1),
		.ce0		(ce0_mram1  	), 
		.we0		(we0_mram1  	), 
		.q0			(q0_mram1   	), 
		.d0			(d0_mram1   	), 
	//Use AXI4 & Core
    	.addr1 		(p_state[1]||i_en ? addr1_cnt_mram1 : i_addr1_cnt_mram1), 
		.ce1		(p_state[1]||i_en ? ce1_mram1	: i_ce1_mram1           ), 
		.we1		(p_state[1]||i_en ? we1_mram1	: i_we1_mram1		    ),
		.q1			(q1_mram1	                                    ), 
		.d1			(p_state[1]||i_en ? d1_mram1 : i_d1_mram1		        )
		// .addr1 		(ram_ptr ? addr1_cnt_mram1 : i_addr1_cnt_mram1), 
		// .ce1		(ram_ptr ? ce1_mram1	: i_ce1_mram1           ), 
		// .we1		(ram_ptr ? we1_mram1	: i_we1_mram1		    ),
		// .q1			(q1_mram1	                                    ), 
		// .d1			(ram_ptr ? d1_mram1 : i_d1_mram1		        )
		
		// .addr1 		(i_addr1_cnt_mram1), 
		// .ce1		(i_ce1_mram1           ), 
		// .we1		(i_we1_mram1		    ),
		// .q1			(o_q1_mram1	            ), 
		// .d1			(i_d1_mram1		        )
    );

endmodule