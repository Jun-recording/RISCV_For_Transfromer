`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/17 18:13:08
// Design Name: 
// Module Name: dp_bram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module dp_bram 
#(
    parameter DWIDTH = 32,
    parameter AWIDTH = 32,
    parameter MEM_SIZE = 3840
)
(
	input clk,
    input [AWIDTH-1:0] addr0,
    input ce0,
    input we0,
    output reg [DWIDTH-1:0] q0,
    input [DWIDTH-1:0] d0,

    input [AWIDTH-1:0] addr1,
    input ce1,
    input we1,
    output reg [DWIDTH-1:0] q1,
    input [DWIDTH-1:0] d1
);

(* ram_style = "block" *)reg [DWIDTH-1:0] ram[0:MEM_SIZE-1];

always @(posedge clk)  
begin 
    if (ce0) begin
        if (we0) 
            ram[addr0[AWIDTH-1:2]] <= d0;
		else
        	q0 <= ram[addr0[AWIDTH-1:2]];
    end
end

always @(posedge clk)  
begin 
    if (ce1) begin
        if (we1) 
            ram[addr1] <= d1;
		else
        	q1 <= ram[addr1];
    end
end

endmodule
