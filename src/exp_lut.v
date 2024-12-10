module exp_lut 
#(
    parameter INT_BIT = 5,
    parameter DWIDTH = 16
)
(
    input                  clk, arst_n,
    input                  enable,
    input signed    [INT_BIT-1:0]   i_int,      //16-bit fixed point input (-16 <= x < 0) because of x-max(x)

    output signed   [DWIDTH-1:0] o_out        // 16-bit fixed point output
);
    wire               sign_bit;
    wire [INT_BIT-2:0] addr;

    assign sign_bit = i_int[INT_BIT-1]; 
    assign addr = i_int[INT_BIT-2:0];

    reg [DWIDTH-1:0] r_lut;          // LUT storage

    // pre-calculated e^x value
    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_lut <= 0;
        else if (enable)
            case(addr)
                // e^-16 to e^0 values
                4'd0 : r_lut <= sign_bit ? 16'd0 : 16'd2048;
                4'd15 : r_lut <= 16'd753; 
                4'd14 : r_lut <= 16'd277; 
                4'd13 : r_lut <= 16'd102;
                4'd12 : r_lut <= 16'd38; 
                4'd11 : r_lut <= 16'd14;  
                4'd10 : r_lut <= 16'd5; 
                4'd9 : r_lut <= 16'd2;  
                4'd8 : r_lut <= 16'd1;  
                4'd7 : r_lut <= 16'd0;  
                default : r_lut <= 16'd0;
            endcase
    end

    reg [DWIDTH-1:0] r_lut_d;   //Delay to wait for PWL module

    always @ (posedge clk, negedge arst_n) begin
        if(!arst_n)
            r_lut_d <= 0;
        else if (enable)
            r_lut_d <= r_lut;
    end

    // Output logic
    assign o_out = r_lut_d;


endmodule