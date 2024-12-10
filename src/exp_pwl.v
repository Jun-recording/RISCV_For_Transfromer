module exp_pwl 
#(
    parameter FRAC_BIT = 11,
    parameter DWIDTH = 16
)
(
    input                  clk, arst_n,
    input                  enable,
    input  [FRAC_BIT-1:0]  i_frac,    //16-bit fixed point input (0 <= x < 1)

    output [DWIDTH-1:0] o_out     //16-bit fixed point output
);

    // Internal signals
    wire [2:0] segment;           //16 segments
    wire [7:0] offset;               //Offset within segment
    assign segment = i_frac[10:8];  //To determine segment
    assign offset = i_frac[7:0];    //To determine position

    reg [15:0] slope;            //Slope
    reg [15:0] intercept;        //Y-intercept

    // Calculate output using y = mx + b
    always @(*) begin
        case(segment)
            4'd0: begin 
                slope = 16'd2182;      //1.065187625
                intercept = 16'd2048;  //1.0
            end
            4'd1: begin
                slope = 16'd2472;      //1.207015709
                intercept = 16'd2321;  //1.133148453
            end
            4'd2: begin
                slope = 16'd2801;      //1.367727983
                intercept = 16'd2630;  //1.284025417
            end
            4'd3: begin 
                slope = 16'd3174;      //1.549838849
                intercept = 16'd2980;  //1.454991415
            end
            4'd4: begin
                slope = 16'd3597;      //1.756197494
                intercept = 16'd3377;  //1.648721271
            end
            4'd5: begin
                slope = 16'd4076;      //1.990032473
                intercept = 16'd3826;  //1.868245957
            end
            4'd6: begin 
                slope = 16'd4618;      //2.255002219
                intercept = 16'd4336;  //2.117000017
            end
            4'd7: begin
                slope = 16'd5233;      //2.555252276
                intercept = 16'd4913;  //2.398875294
            end
            default: begin
                slope = 16'd0;
                intercept = 16'd0;
            end
        endcase
    end

    wire [DWIDTH+FRAC_BIT-1:0] mul;
    assign mul = slope * offset;

    reg [DWIDTH-1:0] r_mul;

    always @ (posedge clk, negedge arst_n) begin
        if(!arst_n)
            r_mul <= 0;
        else if (enable)
            r_mul <= {mul[DWIDTH+FRAC_BIT-1], mul[DWIDTH+FRAC_BIT-2:FRAC_BIT]}; // 32bits->16bits
    end

    reg [DWIDTH-1:0] r_out;

    always @ (posedge clk, negedge arst_n) begin
        if(!arst_n)
            r_out <= 0;
        else if (enable)
            r_out <= r_mul + intercept;
    end

    assign o_out = r_out;

endmodule