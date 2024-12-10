module nr_reciprocal 
#(
    parameter CNT_BIT = 16,
    parameter INT_BIT = 5,
    parameter FRAC_BIT = 11,
    parameter DWIDTH = 16,
    parameter ITERATIONS = 4
)
(
    input                       clk, arst_n,
    input                       enable,
    input signed  [DWIDTH-1:0]  i_in,   
    input         [CNT_BIT-1:0] i_num,   //The number of softmax input

    output signed [DWIDTH-1:0]  o_out,  
    output                      o_valid     
);

    wire w_valid;
    reg [CNT_BIT-1:0] cnt;
    reg [2:0] iter;             //NR algorithm iteration

    assign w_valid = (iter==ITERATIONS) && (cnt<=i_num+1);    //Output valid as many times as softmax inputs

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            cnt <= 0;
        else if (enable && w_valid)
            cnt <= cnt+1;
        else if (enable)
            cnt[2:0] <= cnt[2:0]==3'd3 ? 3'd1 : cnt+1;  //0,1,2,3,1,2,3,1,2,3,... for NR algorithm iteration
        else
            cnt <= 0;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            iter <= 0;
        else if (enable && cnt[2:0]==3'd3 && !w_valid)
            iter <= iter+1;
        else if (!enable)
            iter <= 0;
    end

    reg signed [DWIDTH-1:0] r_in;                   

    always @ (posedge clk, negedge arst_n) begin     //Input latching
        if (!arst_n)
            r_in <= 0;
        else if (enable && cnt==0)
            r_in <= i_in;
    end

    reg [DWIDTH-1:0] est_init;          

    always @ (*) begin                      //Input preprocessing (to prevent divergence or convergence)
        casex(i_in[14:11])
            4'b1xxx : est_init = i_in>>8;
            4'b01xx : est_init = i_in>>6;
            4'b001x : est_init = i_in>>4;
            4'b0001 : est_init = i_in>>2;
            default : est_init = i_in;
        endcase
    end
    
    //NR algorithm x = x(2 - a*x)
    reg signed [DWIDTH-1:0] r_estimate; //Estimated value

    wire signed [DWIDTH-1:0] w_temp;
    wire signed [DWIDTH*2-1:0] w_mult;
    assign w_temp = cnt==10'd1 ? r_estimate : r_in;
    assign w_mult = w_temp*r_estimate;

    reg signed [DWIDTH-1:0] r_1shift;
    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_1shift <= 0;
        else if (enable && cnt==10'd1)
            r_1shift <= r_estimate<<1;
    end

    always @ (posedge clk, negedge arst_n) begin
        if (!arst_n)
            r_estimate <= 0;
        else if (enable && cnt==0)
            r_estimate <= est_init;
        else if (enable && (cnt[2:0]==3'd1 || cnt[2:0]==3'd2))                  //iter i.1, i.2
            r_estimate <= {w_mult[DWIDTH*2-1], w_mult[DWIDTH+FRAC_BIT-2:FRAC_BIT]};
        else if (enable && cnt[2:0]==3'd3)                                      //iter i.3
            r_estimate <= r_1shift - r_estimate;
    end

    reg [DWIDTH-1:0] r_out;

    always @ (posedge clk, negedge arst_n) begin 
        if (!arst_n)
            r_out <= 0;
        else if (enable && iter==ITERATIONS-1 && cnt==10'd3)
            r_out <= r_estimate;
    end

    assign o_out = r_out;
    assign o_valid = w_valid;

endmodule