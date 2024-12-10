module exp 
#(
    parameter INT_BIT = 5,
    parameter FRAC_BIT = 11,
    parameter DWIDTH = 16
)
(
    input              clk, arst_n,
    input              enable,
    input [DWIDTH-1:0] i_in,

    output [DWIDTH-1:0] o_out,
    output              o_valid
);

    wire [INT_BIT-1:0] w_int;
    wire [FRAC_BIT-1:0] w_frac;
    assign w_int = i_in[DWIDTH-1:DWIDTH-INT_BIT]; //Integer part
    assign w_frac = i_in[FRAC_BIT-1:0];           //Fraction part

    wire [DWIDTH-1:0] w_lut_out;
    wire [DWIDTH-1:0] w_pwl_out;

    exp_lut 
    #(
        .INT_BIT(INT_BIT),
        .DWIDTH(DWIDTH)
    ) lut_inst (
        .clk(clk),
        .arst_n(arst_n),
        .enable(enable),
        .i_int(w_int),
        .o_out(w_lut_out)
    );

    exp_pwl
    #(
        .FRAC_BIT(FRAC_BIT),
        .DWIDTH(DWIDTH)
    ) pwl_inst (
        .clk(clk),
        .arst_n(arst_n),
        .enable(enable),
        .i_frac(w_frac),
        .o_out(w_pwl_out)
    );

    wire [DWIDTH*2-1:0] mul;
    assign mul = w_lut_out*w_pwl_out;           //e^(x1+x2) = e^x1 * e^x2

    reg [DWIDTH-1:0] r_mul;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_mul <= 0;
        else if (enable)
            r_mul <= {mul[DWIDTH*2-1], mul[DWIDTH+FRAC_BIT-2:FRAC_BIT]};    //32bits->16bits
    end

    reg [1:0] cnt;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            cnt <= 0;
        else if (enable)
            cnt <= cnt==2'd3 ? cnt : cnt+1;
        else
            cnt <= 0;
    end

    assign o_out = r_mul;
    assign o_valid = cnt==2'd3 && enable ? 1 : 0;   //Consider initial latency

endmodule