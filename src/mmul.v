`timescale 1ns/100ps

module mmul #
(
    parameter       MEM_A_DATA_WIDTH        =   32              ,
    parameter       MEM_A_ADDR_WIDTH        =   10              ,
    parameter       MEM_A_MEM_DEPTH         =   1024            ,
    
    parameter       MEM_B_DATA_WIDTH        =   32              ,
    parameter       MEM_B_ADDR_WIDTH        =   10              ,
    parameter       MEM_B_MEM_DEPTH         =   1024            ,

    parameter       DATA_WIDTH              =   16              ,
    parameter       FRACTION_BITS           =   11
)
(
    input                                       clk             ,
    input                                       arst_n          ,

    // run signal 
    input                                       i_run           ,

    // matrix length
    input   [  DATA_WIDTH-1       : 0  ]        i_a_row_width   ,
    input   [  DATA_WIDTH-1       : 0  ]        i_a_col_width   ,
    input   [  DATA_WIDTH-1       : 0  ]        i_b_row_width   ,
    input   [  DATA_WIDTH-1       : 0  ]        i_b_col_width   ,

    // fsm state 
    output                                      o_s_idle        ,
    output                                      o_s_busy        ,
    output                                      o_s_done        ,

    // BRAM I/F - Matrix a
    output  [  MEM_A_DATA_WIDTH-1 : 0  ]        mem_a_d0        ,
    output  [  MEM_A_ADDR_WIDTH-1 : 0  ]        mem_a_addr0     ,
    output                                      mem_a_ce0       ,
    output                                      mem_a_we0       ,
    input   [  MEM_A_DATA_WIDTH-1 : 0  ]        mem_a_q0        ,
    
    output  [  MEM_A_DATA_WIDTH-1 : 0  ]        mem_a_d1        ,
    output  [  MEM_A_ADDR_WIDTH-1 : 0  ]        mem_a_addr1     ,
    output                                      mem_a_ce1       ,
    output                                      mem_a_we1       ,
    input   [  MEM_A_DATA_WIDTH-1 : 0  ]        mem_a_q1        ,
    
    // BRAM I/F - Matrix b
    output  [  MEM_B_DATA_WIDTH-1 : 0  ]        mem_b_d0        ,
    output  [  MEM_B_ADDR_WIDTH-1 : 0  ]        mem_b_addr0     ,
    output                                      mem_b_ce0       ,
    output                                      mem_b_we0       ,
    input   [  MEM_B_DATA_WIDTH-1 : 0  ]        mem_b_q0        ,
    
    output  [  MEM_B_DATA_WIDTH-1 : 0  ]        mem_b_d1        ,
    output  [  MEM_B_ADDR_WIDTH-1 : 0  ]        mem_b_addr1     ,
    output                                      mem_b_ce1       ,
    output                                      mem_b_we1       ,
    input   [  MEM_B_DATA_WIDTH-1 : 0  ]        mem_b_q1
);

localparam          S_IDLE                  =           2'b00                           ;
localparam          S_BUSY                  =           2'b01                           ;
localparam          S_DONE                  =           2'b10                           ;

// fsm
reg                 [  1                    : 0  ]      cs                              ;
reg                 [  1                    : 0  ]      ns                              ;
reg                 [  3                    : 0  ]      s_busy_d                        ;
reg                 [  3                    : 0  ]      s_done_d                        ;

wire                                                    s_idle                          ;
wire                                                    s_busy                          ;
wire                                                    s_done                          ;

// matrix length buffer
reg                 [  DATA_WIDTH-1         : 0  ]      a_row_width                     ;
reg                 [  DATA_WIDTH-1         : 0  ]      a_col_width                     ;
reg                 [  DATA_WIDTH-1         : 0  ]      b_row_width                     ;
reg                 [  DATA_WIDTH-1         : 0  ]      b_col_width                     ;

// memory index
reg                 [  DATA_WIDTH-1         : 0  ]      idx_p                           ;
reg                 [  DATA_WIDTH-1         : 0  ]      idx_q                           ;
reg                                                     idx_r                           ;
reg                 [  DATA_WIDTH-1         : 0  ]      idx_s                           ;

reg                 [  DATA_WIDTH*2-1       : 0  ]      idx_p_d                         ;
reg                 [  DATA_WIDTH*2-1       : 0  ]      idx_q_d                         ;
reg                 [  2                    : 0  ]      idx_r_d                         ;
reg                 [  DATA_WIDTH*3-1       : 0  ]      idx_s_d                         ;

wire                                                    idx_p_done                      ;
wire                                                    idx_q_done                      ;
wire                                                    idx_s_done                      ;

// memory address
reg                 [  MEM_A_ADDR_WIDTH-1   : 0  ]      addr_a1_offset                  ;

reg                 [  MEM_A_ADDR_WIDTH-1   : 0  ]      row_addr_a0_mult                ;
reg                 [  MEM_A_ADDR_WIDTH-1   : 0  ]      row_addr_a1_mult                ;
reg                 [  MEM_B_ADDR_WIDTH-1   : 0  ]      row_addr_b_mult                 ;
reg                 [  MEM_A_ADDR_WIDTH-1   : 0  ]      row_addr_a1_shift               ;

reg                 [  MEM_B_ADDR_WIDTH-1   : 0  ]      addr_b_d        [  1 : 0  ]     ;

// ALU
wire    signed      [  DATA_WIDTH-1         : 0  ]      mult_in0        [  1 : 0  ]     ;
wire    signed      [  DATA_WIDTH-1         : 0  ]      mult_in1        [  1 : 0  ]     ;
reg     signed      [  DATA_WIDTH*2-1       : 0  ]      mult_out        [  1 : 0  ]     ;

wire    signed      [  DATA_WIDTH-1         : 0  ]      add_in0         [  1 : 0  ]     ;
wire    signed      [  DATA_WIDTH-1         : 0  ]      add_in1         [  1 : 0  ]     ;
wire    signed      [  DATA_WIDTH           : 0  ]      add_out         [  1 : 0  ]     ;
wire                [  1                    : 0  ]      overflow0                       ;
wire                [  1                    : 0  ]      overflow1                       ;
wire    signed      [  DATA_WIDTH-1         : 0  ]      add_satd        [  1 : 0  ]     ;

wire    signed      [  DATA_WIDTH-1         : 0  ]      a_temp                          ;

// fsm
always @(*) begin
    ns = cs;
    case(cs)
        S_IDLE:
            if(i_run)
                ns = S_BUSY;
        S_BUSY:
            if(idx_p_done && idx_q_done && idx_r && idx_s_done)
                ns = S_DONE;
        S_DONE:
            ns = S_IDLE;
    endcase
end

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        cs              <=      S_IDLE                                                                  ;
        s_busy_d        <=      4'd0                                                                    ;
        s_done_d        <=      4'd0                                                                    ;
    end else begin
        cs              <=      ns                                                                      ;
        s_busy_d        <=      {  s_busy_d[2:0] ,  s_busy  }                                           ;
        s_done_d        <=      {  s_done_d[2:0] ,  s_done  }                                           ;
    end
end

assign s_idle           =       (   cs  ==  S_IDLE  )                                                   ;
assign s_busy           =       (   cs  ==  S_BUSY  )                                                   ;
assign s_done           =       (   cs  ==  S_DONE  )                                                   ;

assign o_s_idle         =       !o_s_busy   &&      !o_s_done                                           ;
assign o_s_busy         =       s_busy      ||      s_busy_d[3]                                         ;
assign o_s_done         =       s_done_d[3]                                                             ;

// matrix length buffer
always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        a_row_width     <=      {   DATA_WIDTH  {   1'b0    }       }                                   ;
        a_col_width     <=      {   DATA_WIDTH  {   1'b0    }       }                                   ;
        b_row_width     <=      {   DATA_WIDTH  {   1'b0    }       }                                   ;
        b_col_width     <=      {   DATA_WIDTH  {   1'b0    }       }                                   ;
    end else if(i_run) begin
        a_row_width     <=      i_a_row_width                                                           ;
        a_col_width     <=      {   1'b0    ,   i_a_col_width[DATA_WIDTH-1:1]   }                       ;
        b_row_width     <=      {   1'b0    ,   i_b_row_width[DATA_WIDTH-1:1]   }                       ;
        b_col_width     <=      {   1'b0    ,   i_b_col_width[DATA_WIDTH-1:1]   }                       ;
    end else begin
        a_row_width     <=      a_row_width                                                             ;
        a_col_width     <=      a_col_width                                                             ;
        b_row_width     <=      b_row_width                                                             ;
        b_col_width     <=      b_col_width                                                             ;
    end
end


// memory index
always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        idx_p           <=      {   DATA_WIDTH      {1'b0}  }                                           ;
        idx_q           <=      {   (DATA_WIDTH-1)  {1'b0}  }                                           ;
        idx_r           <=      1'b0                                                                    ;
        idx_s           <=      {   (DATA_WIDTH-1)  {1'b0}  }                                           ;
    end else if(s_busy) begin
        idx_p           <=      idx_p_done ? {DATA_WIDTH{1'b0}} : ((idx_q_done && idx_r && idx_s_done) ? (idx_p + 1) : idx_p)    ;
        idx_q           <=      idx_q_done ? {DATA_WIDTH{1'b0}} : ((idx_r && idx_s_done) ? (idx_q + 1) : idx_q)    ;
        idx_r           <=      idx_s_done ?       ~idx_r       :       idx_r                           ;
        idx_s           <=      idx_s_done ? {DATA_WIDTH{1'b0}} : idx_s + 1                             ;
    end else if(s_done) begin
        idx_p           <=      {   DATA_WIDTH      {1'b0}  }                                           ;
        idx_q           <=      {   DATA_WIDTH      {1'b0}  }                                           ;
        idx_r           <=      1'b0                                                                    ;
        idx_s           <=      {   DATA_WIDTH      {1'b0}  }                                           ;
    end else begin
        idx_p           <=      idx_p                                                                   ;
        idx_q           <=      idx_q                                                                   ;
        idx_r           <=      idx_r                                                                   ;
        idx_s           <=      idx_s                                                                   ;
    end
end

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        idx_p_d         <=      {   (DATA_WIDTH*2) {1'b0}  }                                            ;
        idx_q_d         <=      {   (DATA_WIDTH*2) {1'b0}  }                                            ;
        idx_r_d         <=      3'd0                                                                    ;
        idx_s_d         <=      {   (DATA_WIDTH*3) {1'b0}  }                                            ;
    end else begin
        idx_p_d         <=      {   idx_p_d[DATA_WIDTH-1:0]   , idx_p         }                         ;
        idx_q_d         <=      {   idx_q_d[DATA_WIDTH-1:0]   , idx_q         }                         ;
        idx_r_d         <=      {   idx_r_d[1:0]              , idx_r         }                         ;
        idx_s_d         <=      {   idx_s_d[DATA_WIDTH*2-1:0] , idx_s         }                         ;
    end
end

assign idx_p_done       =       (idx_p == (a_row_width-1)) && idx_q_done && idx_r && idx_s_done         ;
assign idx_q_done       =       (idx_q == (b_row_width-1)) && idx_r && idx_s_done                       ;
assign idx_s_done       =       (idx_s == (b_col_width-1)) || (a_temp == 0) && s_busy_d[2] && (idx_s_d[DATA_WIDTH*2 +: DATA_WIDTH] == 0);

// memory address calculation
always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        addr_a1_offset      <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
    end else if(i_run) begin
        addr_a1_offset      <=  i_a_row_width * {1'b0, i_a_col_width[MEM_A_ADDR_WIDTH-1:1]}             ;
    end else if(s_done_d[3]) begin
        addr_a1_offset      <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
    end else begin 
        addr_a1_offset      <=  addr_a1_offset                                                          ;
    end
end

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        row_addr_a1_shift   <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                      ;
    end else if(s_busy) begin
        row_addr_a1_shift   <=  {idx_q[MEM_A_ADDR_WIDTH-2:0], 1'b0} + {{(MEM_A_ADDR_WIDTH-1){1'b0}}, idx_r};
    end else if(s_done) begin
        row_addr_a1_shift   <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                      ;
    end else begin
        row_addr_a1_shift   <=  row_addr_a1_shift                                                       ;
    end
end

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        row_addr_a0_mult    <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
        row_addr_a1_mult    <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
        row_addr_b_mult     <=  {  MEM_B_ADDR_WIDTH {  1'b0  }  }                                       ;
     end else if(s_busy_d[0]) begin
        row_addr_a0_mult    <=  b_row_width     *   idx_p_d[DATA_WIDTH*0 +: MEM_A_ADDR_WIDTH]           ;
        row_addr_a1_mult    <=  b_col_width     *   row_addr_a1_shift                                   ;
        row_addr_b_mult     <=  b_col_width     *   idx_p_d[DATA_WIDTH*0 +: MEM_B_ADDR_WIDTH]           ;
    end else if(s_done_d[0]) begin
        row_addr_a0_mult    <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
        row_addr_a1_mult    <=  {  MEM_A_ADDR_WIDTH {  1'b0  }  }                                       ;
        row_addr_b_mult     <=  {  MEM_B_ADDR_WIDTH {  1'b0  }  }                                       ;
    end else begin
        row_addr_a0_mult    <=  row_addr_a0_mult                                                        ;
        row_addr_a1_mult    <=  row_addr_a1_mult                                                        ;
        row_addr_b_mult     <=  row_addr_b_mult                                                         ;
    end
end

always @(posedge clk or negedge arst_n) begin
    if(!arst_n) begin
        addr_b_d[0]         <=  {  MEM_B_ADDR_WIDTH {1'b0}  }                                           ;
        addr_b_d[1]         <=  {  MEM_B_ADDR_WIDTH {1'b0}  }                                           ;
    end else begin
        addr_b_d[0]         <=  row_addr_b_mult + idx_s_d[DATA_WIDTH*1 +: DATA_WIDTH]                   ;
        addr_b_d[1]         <=  addr_b_d[0]                                                             ;
    end
end

assign mem_a_addr0          =   row_addr_a0_mult + idx_q_d[DATA_WIDTH*1 +: MEM_A_ADDR_WIDTH]            ;
assign mem_a_addr1          =   row_addr_a1_mult + idx_s_d[DATA_WIDTH*1 +: MEM_A_ADDR_WIDTH] + addr_a1_offset;
assign mem_b_addr0          =   addr_b_d[0]                                                             ;
assign mem_b_addr1          =   addr_b_d[1]                                                             ;

// ALU
genvar alu_idx;
generate
    for(alu_idx=0; alu_idx<2; alu_idx=alu_idx+1) begin : gen_add
        assign add_out[alu_idx] = add_in0[alu_idx] + add_in1[alu_idx];
        assign overflow0[alu_idx] = (!add_in0[alu_idx][DATA_WIDTH-1] && !add_in1[alu_idx][DATA_WIDTH-1] && add_out[alu_idx][DATA_WIDTH-1]);
        assign overflow1[alu_idx] = (add_in0[alu_idx][DATA_WIDTH-1] && add_in1[alu_idx][DATA_WIDTH-1] && !add_out[alu_idx][DATA_WIDTH-1]);
        assign add_satd[alu_idx] = overflow0[alu_idx] ? {1'b0, {DATA_WIDTH-1{1'b1}}} : (overflow1[alu_idx] ? {1'b1, {DATA_WIDTH-1{1'b0}}} : add_out[alu_idx][DATA_WIDTH-1:0]);
        always @(posedge clk) begin
            if(s_busy_d[2]) begin
                mult_out[alu_idx] <= mult_in0[alu_idx]*mult_in1[alu_idx];
            end
        end
    end
endgenerate

assign a_temp           =       !idx_r_d[2] ? mem_a_q0[DATA_WIDTH-1:0] : mem_a_q0[DATA_WIDTH +: DATA_WIDTH]         ; 

assign mult_in0[0]      =       a_temp                                                                              ; 
assign mult_in1[0]      =       mem_a_q1[DATA_WIDTH-1:0]                                                            ; 
assign mult_in0[1]      =       a_temp                                                                              ; 
assign mult_in1[1]      =       mem_a_q1[DATA_WIDTH +: DATA_WIDTH]                                                  ; 


assign add_in0[0]       =       {mult_out[0][DATA_WIDTH*2-1], mult_out[0][FRACTION_BITS +: (DATA_WIDTH-1)]}         ;
assign add_in1[0]       =       mem_b_q0[DATA_WIDTH-1:0]                                                            ;
assign add_in0[1]       =       {mult_out[1][DATA_WIDTH*2-1], mult_out[1][FRACTION_BITS +: (DATA_WIDTH-1)]}         ;
assign add_in1[1]       =       mem_b_q0[DATA_WIDTH +: DATA_WIDTH]                                                  ;

// BRAM I/F
assign mem_a_d0         =       {  MEM_A_DATA_WIDTH   {  1'b0  }   }                                                ;
assign mem_a_ce0        =       s_busy_d[1]                                                                         ;
assign mem_a_we0        =       1'b0                                                                                ;

assign mem_a_d1         =       {  MEM_A_DATA_WIDTH   {  1'b0  }   }                                                ;
assign mem_a_ce1        =       s_busy_d[1]                                                                         ;
assign mem_a_we1        =       1'b0                                                                                ;

assign mem_b_d0         =       {  MEM_B_DATA_WIDTH   {  1'b0  }   }                                                ;
assign mem_b_ce0        =       s_busy_d[2]                                                                         ;
assign mem_b_we0        =       1'b0                                                                                ;

assign mem_b_d1         =       {  add_satd[1]  ,   add_satd[0]  }                                                  ;
assign mem_b_ce1        =       s_busy_d[3]                                                                         ;
assign mem_b_we1        =       s_busy_d[3]                                                                         ;

endmodule
