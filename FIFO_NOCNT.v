`timescale 1ns / 1ps
`default_nettype none
  module test;
  parameter clock_half_period = 10;
  parameter DW=32, DEPTH_LOG=3;

  reg [31:0] pcnt = 0;
  always @(posedge CLK) pcnt <= pcnt + 1;
  
  /* input */   
  reg CLK;
  reg RST;
  reg enq=0;
  reg deq=0;
  reg [DW-1:0] din=0;
  
  /* output */   
  wire dbg;
  wire emp, full;
  wire [DW-1:0] dot;

  initial begin
    CLK = 0;
    forever #(clock_half_period) CLK = ~CLK;
  end

  initial begin
    RST = 0;
    #1000;
    RST = 1;
    #1000;
    RST = 0;
  end

  always @(posedge CLK)
    if(RST) {enq, din, deq} <= 0;
    else begin
      enq <= $random;
      din <= $random;
      deq <= $random;
    end
  wire enq_t = enq && ~full;
  wire deq_t = deq && ~emp;
  
  FIFO_NOCNT #(.DW(DW), .DEPTH_LOG(DEPTH_LOG), .DBG(1)) uut (CLK, RST, enq && ~full, din, deq && ~emp, dot, emp, full, dbg);

  // MONITORING
  always @(posedge CLK) begin
    $write("%d|%b|ENQ:%b DIN:%d|DEQ:%b DOT:%d|EMP:%b FULL:%b|CNT:%d", pcnt, RST, enq_t, din, deq_t, dot, emp, full, uut.cnt);    
    $display();
  end

  initial begin
    $dumpfile("uut.vcd");
    $dumpvars(0, uut);
  end
  
  initial begin
    #10000;
    $finish;
  end
endmodule

module FIFO_NOCNT #(parameter DEPTH_LOG=3, DW = 32, DBG = 1) // DBG 1: WITH ELM COUNTER 0: WITHOUT IT
  (input  wire CLK,
   input  wire RST,
   input  wire enq,
   input  wire [DW-1:0] din,
   input  wire deq,
   output reg  [DW-1:0] dot=0,
   output wire emp, full,
   output wire dbg);

  reg [DEPTH_LOG:0] rd_ptr=0;
  always @(posedge CLK) if(RST) rd_ptr <= 0; else if(deq) rd_ptr <= rd_ptr + 1;
  reg [DEPTH_LOG:0] wr_ptr=0;
  always @(posedge CLK) if(RST) wr_ptr <= 0; else if(enq) wr_ptr <= wr_ptr + 1;

  // ELM COUNTER IS NOT NEEDED!!
  reg [DEPTH_LOG:0] cnt = 0;
  generate
    if(DBG==1) begin: DEBUG_MODE_WITH_ELM_CNT
      always @(posedge CLK)
        if(RST) cnt <= 0;
        else
          case({deq, enq})
            2'b10: cnt <= cnt - 1;
            2'b01: cnt <= cnt + 1;
          endcase
    end
  endgenerate
  assign emp  = (rd_ptr[DEPTH_LOG]==wr_ptr[DEPTH_LOG]) && (rd_ptr[DEPTH_LOG-1:0]==wr_ptr[DEPTH_LOG-1:0]); 
  assign full = (rd_ptr[DEPTH_LOG]!=wr_ptr[DEPTH_LOG]) && (rd_ptr[DEPTH_LOG-1:0]==wr_ptr[DEPTH_LOG-1:0]); 

  localparam DEPTH = 1 << DEPTH_LOG;
  reg [DW-1:0] mem [0:DEPTH-1];
  integer i;
  initial for (i=0;i<DEPTH;i=i+1) mem[i] = 0;

  always @(posedge CLK) if(enq) mem[wr_ptr[DEPTH_LOG-1:0]] <= din;
  always @(posedge CLK)
    if(RST) dot <= 0;
    else dot <= mem[rd_ptr[DEPTH_LOG-1:0]];
  
  reg [31:0] cnt_dbg=0;
  assign dbg = cnt_dbg[2];
  always @(posedge CLK) begin
    if (RST) cnt_dbg <= 0;
    else      cnt_dbg <= cnt_dbg + 1;
  end  

endmodule
`default_nettype wire
