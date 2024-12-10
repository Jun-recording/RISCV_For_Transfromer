`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/10/27 14:35:36
// Design Name: 
// Module Name: top
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


module top
#(
	parameter CNT_BIT = 31,
	
	parameter integer MEM0_DATA_WIDTH = 32,
	parameter integer MEM0_ADDR_WIDTH = 32,
	parameter integer MEM0_MEM_DEPTH  = 1024,

	parameter integer MEM1_DATA_WIDTH = 32,
	parameter integer MEM1_ADDR_WIDTH = 32,
	parameter integer MEM1_MEM_DEPTH  = 1024,
	
	parameter integer MEM2_DATA_WIDTH = 32,
	parameter integer MEM2_ADDR_WIDTH = 32,
	parameter integer MEM2_MEM_DEPTH  = 1024,

	parameter integer MEM3_DATA_WIDTH = 32,
	parameter integer MEM3_ADDR_WIDTH = 32,
	parameter integer MEM3_MEM_DEPTH  = 1024,

	// Parameters of Axi Slave Bus Interface S00_AXI
	parameter integer C_S00_AXI_DATA_WIDTH	= 32,
	parameter integer C_S00_AXI_ADDR_WIDTH	= 6 //used #16 reg
)
(

	// Ports of Axi Slave Bus Interface S00_AXI
	input wire  s00_axi_aclk,
	input wire  s00_axi_aresetn,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
	input wire [2 : 0] s00_axi_awprot,
	input wire  s00_axi_awvalid,
	output wire  s00_axi_awready,
	input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
	input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
	input wire  s00_axi_wvalid,
	output wire  s00_axi_wready,
	output wire [1 : 0] s00_axi_bresp,
	output wire  s00_axi_bvalid,
	input wire  s00_axi_bready,
	input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
	input wire [2 : 0] s00_axi_arprot,
	input wire  s00_axi_arvalid,
	output wire  s00_axi_arready,
	output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
	output wire [1 : 0] s00_axi_rresp,
	output wire  s00_axi_rvalid,
	input wire  s00_axi_rready
);

	wire  				w_run;
	wire [CNT_BIT-1:0]	w_num_cnt;
	wire   				w_idle;
	wire   				w_running;
	wire    			w_done;
	
	wire [2:0]          w_malu_status;

	wire				w_read;
	wire				w_write;

    //Memory I/F
	//IMEM, DMEM
	wire		[MEM0_ADDR_WIDTH-1:0] 	mem0_addr1	;
	wire		 						mem0_ce1	;
	wire		 						mem0_we1	;
	wire		[MEM0_DATA_WIDTH-1:0]  	mem0_q1		;
	wire		[MEM0_DATA_WIDTH-1:0] 	mem0_d1		;

	wire		[MEM1_ADDR_WIDTH-1:0] 	mem1_addr1	;
	wire		 						mem1_ce1	;
	wire		 						mem1_we1	;
	wire		[MEM1_DATA_WIDTH-1:0]  	mem1_q1		;
	wire		[MEM1_DATA_WIDTH-1:0] 	mem1_d1		;

	//MRAM0, MRAM1
	wire		[MEM2_ADDR_WIDTH-1:0] 	mem2_addr1	;
	wire		 						mem2_ce1	;
	wire		 						mem2_we1	;
	wire		[MEM2_DATA_WIDTH-1:0]  	mem2_q1		;
	wire		[MEM2_DATA_WIDTH-1:0] 	mem2_d1		;

	wire		[MEM3_ADDR_WIDTH-1:0] 	mem3_addr1	;
	wire		 						mem3_ce1	;
	wire		 						mem3_we1	;
	wire		[MEM3_DATA_WIDTH-1:0]  	mem3_q1		;
	wire		[MEM3_DATA_WIDTH-1:0] 	mem3_d1		;

// Instantiation of Axi Bus Interface S00_AXI
	myip_v1_0 # ( 
		.CNT_BIT(CNT_BIT),
		.MEM0_DATA_WIDTH (MEM0_DATA_WIDTH),
		.MEM0_ADDR_WIDTH (MEM0_ADDR_WIDTH),
		.MEM0_MEM_DEPTH  (MEM0_MEM_DEPTH ),
		.MEM1_DATA_WIDTH (MEM1_DATA_WIDTH),
		.MEM1_ADDR_WIDTH (MEM1_ADDR_WIDTH),
		.MEM1_MEM_DEPTH  (MEM1_MEM_DEPTH ),
		
		.MEM2_DATA_WIDTH (MEM2_DATA_WIDTH),
		.MEM2_ADDR_WIDTH (MEM2_ADDR_WIDTH),
		.MEM2_MEM_DEPTH  (MEM2_MEM_DEPTH ),
		.MEM3_DATA_WIDTH (MEM3_DATA_WIDTH),
		.MEM3_ADDR_WIDTH (MEM3_ADDR_WIDTH),
		.MEM3_MEM_DEPTH  (MEM3_MEM_DEPTH ),
		
		.C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S00_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) myip_v1_0_inst (
		.o_run		(w_run),
		.o_num_cnt	(w_num_cnt),
		.i_idle		(w_idle),
		.i_running	(w_running),
		.i_done		(w_done),
		.i_malu_status (w_malu_status),

		.mem0_addr1			(mem0_addr1	),
		.mem0_ce1			(mem0_ce1	),
		.mem0_we1			(mem0_we1	),
		.mem0_q1			(mem0_q1	),
		.mem0_d1			(mem0_d1	),

		.mem1_addr1			(mem1_addr1	),
		.mem1_ce1			(mem1_ce1	),
		.mem1_we1			(mem1_we1	),
		.mem1_q1			(mem1_q1	),
		.mem1_d1			(mem1_d1	),
		
		.mem2_addr1			(mem2_addr1	),
		.mem2_ce1			(mem2_ce1	),
		.mem2_we1			(mem2_we1	),
		.mem2_q1			(mem2_q1	),
		.mem2_d1			(mem2_d1	),

		.mem3_addr1			(mem3_addr1	),
		.mem3_ce1			(mem3_ce1	),
		.mem3_we1			(mem3_we1	),
		.mem3_q1			(mem3_q1	),
		.mem3_d1			(mem3_d1	),

		.s00_axi_aclk	(s00_axi_aclk	),
		.s00_axi_aresetn(s00_axi_aresetn),
		.s00_axi_awaddr	(s00_axi_awaddr	),
		.s00_axi_awprot	(s00_axi_awprot	),
		.s00_axi_awvalid(s00_axi_awvalid),
		.s00_axi_awready(s00_axi_awready),
		.s00_axi_wdata	(s00_axi_wdata	),
		.s00_axi_wstrb	(s00_axi_wstrb	),
		.s00_axi_wvalid	(s00_axi_wvalid	),
		.s00_axi_wready	(s00_axi_wready	),
		.s00_axi_bresp	(s00_axi_bresp	),
		.s00_axi_bvalid	(s00_axi_bvalid	),
		.s00_axi_bready	(s00_axi_bready	),
		.s00_axi_araddr	(s00_axi_araddr	),
		.s00_axi_arprot	(s00_axi_arprot	),
		.s00_axi_arvalid(s00_axi_arvalid),
		.s00_axi_arready(s00_axi_arready),
		.s00_axi_rdata	(s00_axi_rdata	),
		.s00_axi_rresp	(s00_axi_rresp	),
		.s00_axi_rvalid	(s00_axi_rvalid	),
		.s00_axi_rready	(s00_axi_rready	)
	);
	
	toast_top core_inst (
	    .clk_i		    (s00_axi_aclk	),
	    .resetn_i       (s00_axi_aresetn),
		.enable   		(w_run			),
		//.i_num_cnt	(w_num_cnt		),
		.o_idle		(w_idle			),
		.o_run    	(w_running	    ),
		.o_done		(w_done			),
	
		.IMEM_addr_i	(mem0_addr1		),
		.IMEM_ce_i   (mem0_ce1		),
		.IMEM_we_i   (mem0_we1		),
		.IMEM_q_o    (mem0_q1		),
		.IMEM_d_i    (mem0_d1		),
	
		.DMEM_addr_i	(mem1_addr1		),
		.DMEM_ce_i	(mem1_ce1		),
		.DMEM_we_i	(mem1_we1		),
		.DMEM_q_o	(mem1_q1		),
		.DMEM_d_i	(mem1_d1		),
		
		.i_addr1_cnt_mram0(mem2_addr1),
        .i_ce1_mram0(mem2_ce1),
        .i_we1_mram0(mem2_we1),
        .i_d1_mram0(mem2_d1),
        .o_q1_mram0(mem2_q1),
        
        .i_addr1_cnt_mram1(mem3_addr1),
        .i_ce1_mram1(mem3_ce1),
        .i_we1_mram1(mem3_we1),
        .i_d1_mram1(mem3_d1),
        .o_q1_mram1(mem3_q1),
        
        .o_malu_status(w_malu_status)
	);

endmodule