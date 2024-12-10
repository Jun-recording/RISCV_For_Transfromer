module madd
#(
    parameter DWIDTH = 32
)
(
    input                   clk, arst_n,
    input                   i_en,
    input       [DWIDTH-1:0] i_in,

    output      [DWIDTH-1:0] o_out,
    output                   o_valid
);
    //Delayed i_en
    reg r_en;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_en <= 0;
        else 
            r_en <= i_en;
    end

    //Delayed r_en
    reg r_en_d;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_en_d <= 0;
        else 
            r_en_d <= r_en;
    end

    //Input demux select signal (0 : input delay, 1 : to add)
    reg r_sel;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_sel <= 0;
        else if (r_en_d)
            r_sel <= ~r_sel;
        else
            r_sel <= 0;
    end

    wire signed [(DWIDTH/2)-1:0] w_in0;
    wire signed [(DWIDTH/2)-1:0] w_in1;
    assign w_in0 = i_in[DWIDTH-1:DWIDTH/2];
    assign w_in1 = i_in[(DWIDTH/2)-1:0];

    reg signed [(DWIDTH/2)-1:0] r_in0;
    reg signed [(DWIDTH/2)-1:0] r_in1;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            r_in0 <= 0;
            r_in1 <= 0;
        end
        else if (r_en_d && !r_sel) begin
            r_in0 <= w_in0;
            r_in1 <= w_in1;
        end
    end

    reg signed [(DWIDTH/2)-1:0] r_out0;
    reg signed [(DWIDTH/2)-1:0] r_out1;
    reg                         r_valid;

    wire signed [(DWIDTH/2)-1:0] w_sum0;
    wire signed [(DWIDTH/2)-1:0] w_sum1;
    assign w_sum0 = r_in0 + w_in0;
    assign w_sum1 = r_in1 + w_in1;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            r_out0 <= 0;
            r_out1 <= 0;
        end
        else if (r_en_d && r_sel) begin
            if (r_in0[(DWIDTH/2)-1]==w_in0[(DWIDTH/2)-1] && w_sum0[(DWIDTH/2)-1]!=r_in0[(DWIDTH/2)-1])
                r_out0 <= w_sum0[(DWIDTH/2)-1] ? 16'b0_111_1111_1111_1111 : 16'b1_000_0000_0000_0001;
            else
                r_out0 <= w_sum0;
            if (r_in1[(DWIDTH/2)-1]==w_in1[(DWIDTH/2)-1] && w_sum1[(DWIDTH/2)-1]!=r_in1[(DWIDTH/2)-1])
                r_out1 <= w_sum1[(DWIDTH/2)-1] ? 16'b0_111_1111_1111_1111 : 16'b1_000_0000_0000_0001;
            else
                r_out1 <= w_sum1;
        end
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_valid <= 0;
        else if (r_en_d && r_sel)
            r_valid <= 1;
        else
            r_valid <= 0;
    end

    assign o_out = {r_out0, r_out1};
    assign o_valid = r_valid;

endmodule