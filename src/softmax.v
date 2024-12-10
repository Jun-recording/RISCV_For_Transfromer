module softmax
#(
    parameter CNT_BIT = 16,
    parameter INT_BIT = 5,
    parameter FRAC_BIT = 11,
    parameter DWIDTH = 16,
    parameter NR_ITERATIONS = 4
)
(
    input                       clk, arst_n,
    input                       enable,
    input signed [DWIDTH-1:0]   i_in0,
    input signed [DWIDTH-1:0]   i_in1,
    input signed [DWIDTH-1:0]   i_exp0,      //From bram
    input signed [DWIDTH-1:0]   i_exp1,      //From bram
    input        [CNT_BIT-1:0]  i_num,      //The number of input

    output signed [2*DWIDTH-1:0]  o_exp_out,
    output                        o_exp_valid, 

    output                        o_recip_valid,

    output signed [2*DWIDTH-1:0]  o_out,
    output                        o_valid
);

    reg [CNT_BIT-1:0] cnt;
    wire [CNT_BIT-1:0] w_num;
    assign w_num = i_num>>1;
    
    reg r_valid;
    reg r_valid_d1;
    reg r_valid_d2;

    always @ (posedge clk, negedge arst_n) begin        //Counter for control
        if (!arst_n)
            cnt <= 0;
        else if (r_valid_d2 && !r_valid_d1)
            cnt <= 0;
        else if (enable)
            cnt <= cnt==w_num+10'd3 ? cnt : cnt+1;
        else
            cnt <= 0;
    end

    wire w_exp_en;      //Exp module enable
    wire w_acc_en;      //Acc enable
    //wire w_fifo_en;     //Fifo enable
    wire w_we;
    wire w_ce;
    wire w_recip_en;    //Reciprocal module enable

    wire w_exp_valid0;
    wire w_exp_valid1;
    wire w_recip_valid;

    assign w_exp_en = enable ? (cnt<w_num+10'd3 ? 1 : 0) : 0;
    assign w_acc_en = w_exp_valid0 || w_exp_valid1;
    //assign w_fifo_en = w_exp_valid || w_recip_valid;
    assign w_recip_en = enable ? (~w_exp_en) : 0;

    wire [DWIDTH-1:0] w_exp_in0;
    wire [DWIDTH-1:0] w_exp_in1;
    wire [DWIDTH-1:0] w_exp_out0;
    wire [DWIDTH-1:0] w_exp_out1;

    assign w_exp_in0 = i_in0;
    assign w_exp_in1 = i_in1;

    exp
    #(
        .INT_BIT(INT_BIT),
        .FRAC_BIT(FRAC_BIT),
        .DWIDTH(DWIDTH)
    ) exp_inst0 (
        .clk(clk),
        .arst_n(arst_n),
        .enable(w_exp_en),
        .i_in(w_exp_in0),
        .o_out(w_exp_out0),
        .o_valid(w_exp_valid0)
    );

    exp
    #(
        .INT_BIT(INT_BIT),
        .FRAC_BIT(FRAC_BIT),
        .DWIDTH(DWIDTH)
    ) exp_inst1 (
        .clk(clk),
        .arst_n(arst_n),
        .enable(w_exp_en),
        .i_in(w_exp_in1),
        .o_out(w_exp_out1),
        .o_valid(w_exp_valid1)
    );

    wire [DWIDTH-1:0] w_exp_sum;
    assign w_exp_sum = w_exp_out0 + w_exp_out1;

    reg [DWIDTH-1:0] r_exp_sum;
    reg r_acc_en;

    always @ (posedge clk, negedge arst_n) begin 
        if (!arst_n)
            r_exp_sum <= 0;
        else if (w_acc_en)
            r_exp_sum <= w_exp_sum;
        else
            r_exp_sum <= 0;
    end

    always @ (posedge clk, negedge arst_n) begin     //Accumulation enable
        if (!arst_n)
            r_acc_en <= 0;
        else
            r_acc_en <= w_acc_en;
    end

    reg [DWIDTH-1:0] r_exp_acc;
    wire [DWIDTH-1:0] w_exp_acc;
    assign w_exp_acc = r_exp_acc + r_exp_sum;

    always @ (posedge clk, negedge arst_n) begin     //Accumulation
        if (!arst_n)
            r_exp_acc <= 0;
        else if (r_acc_en)
            r_exp_acc <= w_exp_acc[DWIDTH-1] ? 16'b0_111_1111_1111_1111 : w_exp_acc;
        else
            r_exp_acc <= 0;
    end

    // reg [DWIDTH-1:0] fifo [0:9];                    //Delay to wait for reciprocal module

    // always @ (posedge clk, negedge arst_n) begin
    //     if (!arst_n) begin
    //         fifo[0] <= 0;
    //         fifo[1] <= 0;
    //         fifo[2] <= 0;
    //         fifo[3] <= 0;
    //         fifo[4] <= 0;
    //         fifo[5] <= 0;
    //         fifo[6] <= 0;
    //         fifo[7] <= 0;
    //         fifo[8] <= 0;
    //         fifo[9] <= 0;
    //     end
    //     else if (w_fifo_en) begin
    //         fifo[0] <= w_exp_out;
    //         fifo[1] <= fifo[0];
    //         fifo[2] <= fifo[1];
    //         fifo[3] <= fifo[2];
    //         fifo[4] <= fifo[3];
    //         fifo[5] <= fifo[4];
    //         fifo[6] <= fifo[5];
    //         fifo[7] <= fifo[6];
    //         fifo[8] <= fifo[7];
    //         fifo[9] <= fifo[8];
    //     end
    // end

    reg r_recip_en;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_recip_en <= 0;
        else
            r_recip_en <= w_recip_en;
    end

    wire [DWIDTH-1:0] w_recip_out;
    
    nr_reciprocal
    #(
        .CNT_BIT(CNT_BIT),
        .INT_BIT(INT_BIT),
        .FRAC_BIT(FRAC_BIT),
        .DWIDTH(DWIDTH),
        .ITERATIONS(NR_ITERATIONS)
    ) recip_inst (
        .clk(clk),
        .arst_n(arst_n),
        .enable(r_recip_en),
        .i_in(r_exp_acc),
        .i_num(w_num),
        .o_out(w_recip_out),
        .o_valid(w_recip_valid)
    );

    wire [DWIDTH*2-1:0] w_mul0, w_mul1;   
    assign w_mul0 = w_recip_out*i_exp0;         //Softmax result0
    assign w_mul1 = w_recip_out*i_exp1;         //Softmax result1

    reg [DWIDTH-1:0] r_out0;
    reg [DWIDTH-1:0] r_out1;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            r_out0 <= 0;
            r_out1 <= 0;
        end
        else if (r_valid_d1) begin
            r_out0 <= {w_mul0[DWIDTH*2-1], w_mul0[DWIDTH+FRAC_BIT-2:FRAC_BIT]};    //32bits->16bits
            r_out1 <= {w_mul1[DWIDTH*2-1], w_mul1[DWIDTH+FRAC_BIT-2:FRAC_BIT]};    //32bits->16bits
        end
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_valid <= 0;
        else
            r_valid <= w_recip_valid;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_valid_d1 <= 0;
        else
            r_valid_d1 <= r_valid;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_valid_d2 <= 0;
        else
            r_valid_d2 <= r_valid_d1;
    end

    assign o_exp_out = {w_exp_out0, w_exp_out1};
    assign o_exp_valid = w_exp_valid0 || w_exp_valid1;

    assign o_recip_valid = w_recip_valid;

    assign o_out = {r_out0, r_out1};
    assign o_valid = r_valid_d2;

endmodule