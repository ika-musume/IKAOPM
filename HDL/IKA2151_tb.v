`timescale 10ps/10ps
module IKA2151_tb;

reg             EMUCLK = 1'b1;
reg             IC_n = 1'b1;
reg             CS_n = 1'b1;
reg             WR_n = 1'b1;
reg             A0 = 1'b0;
reg     [7:0]   DIN = 8'h0;

always #1 EMUCLK = ~EMUCLK;

initial begin
    #30 IC_n <= 1'b0;
    #200 IC_n <= 1'b1;
end

reg     [1:0]   clkdiv = 2'b00;
reg             phiMref = 1'b0;
wire            phiM_PCEN_n = ~(clkdiv == 2'b11);
always @(posedge EMUCLK) begin
    if(clkdiv == 2'b11) begin clkdiv <= 2'b00; phiMref <= 1'b1; end
    else clkdiv <= clkdiv + 2'b01;

    if(clkdiv == 2'b01) phiMref <= 1'b0;
end

IKA2151 main (
    .i_EMUCLK                   (EMUCLK                     ),
    .i_phiM_PCEN_n              (phiM_PCEN_n                ),

    .i_IC_n                     (IC_n                       ),

    .o_phi1                     (                           ),

    .i_CS_n                     (CS_n                       ),
    .i_RD_n                     (1'b1                       ),
    .i_WR_n                     (WR_n                       ),
    .i_A0                       (A0                         ),

    .i_D                        (DIN                        ),
    .o_D                        (                           ),

    .o_CTRL_OE_n                (                           ),

    .o_SH1                      (                           ),
    .o_SH2                      (                           )
);


initial begin
    //write 0xFF, 0x18(LFRQ)
    #300 CS_n <= 1'b0; WR_n <= 1'b1; A0 <= 1'b0; DIN <= 8'h18;
    #30  CS_n <= 1'b0; WR_n <= 1'b0; A0 <= 1'b0; DIN <= 8'h18;
    #40  CS_n <= 1'b1; WR_n <= 1'b1; A0 <= 1'b0; DIN <= 8'h18;
    #30  CS_n <= 1'b0; WR_n <= 1'b1; A0 <= 1'b1; DIN <= 8'hFF;
    #30  CS_n <= 1'b0; WR_n <= 1'b0; A0 <= 1'b1; DIN <= 8'hFF;
    #40  CS_n <= 1'b1; WR_n <= 1'b1; A0 <= 1'b1; DIN <= 8'hFF;

    //write 0x02, 0x1B(CT/W)
    #30  CS_n <= 1'b0; WR_n <= 1'b1; A0 <= 1'b0; DIN <= 8'h1B;
    #30  CS_n <= 1'b0; WR_n <= 1'b0; A0 <= 1'b0; DIN <= 8'h1B;
    #40  CS_n <= 1'b1; WR_n <= 1'b1; A0 <= 1'b0; DIN <= 8'h1B;
    #30  CS_n <= 1'b0; WR_n <= 1'b1; A0 <= 1'b1; DIN <= 8'h02;
    #30  CS_n <= 1'b0; WR_n <= 1'b0; A0 <= 1'b1; DIN <= 8'h02;
    #40  CS_n <= 1'b1; WR_n <= 1'b1; A0 <= 1'b1; DIN <= 8'h02;
end





endmodule