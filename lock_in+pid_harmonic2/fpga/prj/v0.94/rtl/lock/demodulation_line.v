`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.02.2017 12:03:25
// Design Name: 
// Module Name: LP_filter
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


module demodulation_line #(parameter R=14, RT=5, BIT_ENHANCE=10)
    (
    input clk,rst,
    input         [ RT -1:0] tau1,tau2,amp,
    input  signed [ R  -1:0] in,ref,
    output signed [R*2+BIT_ENHANCE   -1:0] out_hr,
    output signed [ R  -1:0] out
    );
    
    // R resolution of input and output signals
    // Low Pass Filter characteristi time is: 8 ns * 2**tau

   // 28 bits
   wire signed [R*2               -1:0] mult_tmp_double, out_double;
   
   // 38 bits
   wire signed [R*2+BIT_ENHANCE   -1:0] mult_tmp_E, lpf1_out, lpf2_out, out_E ;

   // 53 bits
   wire signed [R*2+BIT_ENHANCE+RT-1:0] out_amp;

   mult_dsp_14  i_mult_dps_sin_ref (
      .CLK(clk), 
      .A($signed(ref)) , 
      .B(in), 
      .P(mult_tmp_double)
   );

   assign mult_tmp_E = mult_tmp_double <<< BIT_ENHANCE ; // this is for amplitud enhancement

   LP_filter3 #(.R(R*2+BIT_ENHANCE)) i_LP_filter_1 (
      .clk(clk), .rst(rst), 
      .tau(  tau1   ), 
      .in( mult_tmp_E ), 
      .out( lpf1_out ) 
   );

   LP_filter3 #(.R(R*2+BIT_ENHANCE)) i_LP_filter_2 (
      .clk(clk), .rst(rst), 
      .tau(  tau2   ), 
      .in( lpf1_out ), 
      .out( lpf2_out ) 
   );

   assign out_double   = lpf2_out >>> BIT_ENHANCE ; // this is for amplitud enhancement compensation
   assign out_amp      = ( lpf2_out   <<< amp  );

   satprotect2 #(.Ri(R*2+BIT_ENHANCE+RT),.Ro(R*2+BIT_ENHANCE)) i_satprotect_53   ( 
      .in( out_amp  ), 
      .out( out_E  ) 
   );

   satprotect2 #(.Ri(17),.Ro(R)) i_satprotect_38 ( 
      .in(  out_E[  R*2+BIT_ENHANCE-1:R*2+BIT_ENHANCE-17] ),    
      .out( out    ) 
   );

   assign out_hr = out_double;
   
endmodule





   //  localparam S=49; 
    
   //  reg  signed [S-1  :0] sum;
   //  wire signed [S    :0] sum_next;
   //  wire signed [S-6-1:0] sum_div;
    
   //  always @(posedge clk) begin
   //     if (rst) begin
   //         sum    <=    {S{1'b0}}    ;
   //      end 
   //      else begin
   //         if ( sum_next[S:S-1] == 2'b01  )  // positive overflow 
   //            sum    <=  {1'b0, {S-1{1'b1}} } ;
   //         else if ( sum_next[S:S-1] == 2'b10  )  // negative overflow 
   //            sum    <=  {1'b1, {S-1{1'b0}} } ;
   //         else
   //            sum    <=  sum_next[S-1:0] ;
   //      end
   //  end
    
   //  assign sum_next =  $signed(in)  - $signed( sum_div ) + $signed(sum)  ;
   //  assign sum_div  =  $signed( sum[S-1:0] ) >>> tau ;
   //  //assign out      =  sum_div[R-1:0] ;
   //  satprotect #(.Ri(S-6),.Ro(R),.SAT(R)) i_satprotect ( .in(sum_div), .out(out) );
    