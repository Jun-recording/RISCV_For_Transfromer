module relu 
#(
    parameter DWIDTH = 32
)
(
    input               clk, arst_n,
    input               i_en,
    input  [DWIDTH-1:0] i_in,

    output  [DWIDTH-1:0] o_out,
    output               o_valid
);
    //Delayed i_en
    reg r_en;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_en <= 0;
        else
            r_en <= i_en;
    end

    wire [(DWIDTH/2)-1:0] w_in0;
    wire [(DWIDTH/2)-1:0] w_in1;
    assign w_in0 = i_in[DWIDTH-1:DWIDTH/2];
    assign w_in1 = i_in[(DWIDTH/2)-1:0];

    reg [(DWIDTH/2)-1:0] r_out0, r_out1;
    reg                  r_valid;

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n) begin
            r_out0 <= 0;
            r_out1 <= 0;
        end
        else if (r_en) begin
            r_out0 <= w_in0[(DWIDTH/2)-1] ? 0 : w_in0;
            r_out1 <= w_in1[(DWIDTH/2)-1] ? 0 : w_in1;
        end
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_valid <= 0;
        else if (r_en)
            r_valid <= 1;
        else
            r_valid <= 0;
    end

    assign o_out = {r_out0, r_out1};
    assign o_valid = r_valid;

endmodule