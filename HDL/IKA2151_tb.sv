`timescale 10ps/10ps
module IKA2151_tb;

//BUS IO wires
reg             EMUCLK = 1'b1;
reg             IC_n = 1'b1;
reg             CS_n = 1'b1;
reg             WR_n = 1'b1;
reg             A0 = 1'b0;
reg     [7:0]   DIN = 8'h0;


//generate clock
always #1 EMUCLK = ~EMUCLK;

reg     [1:0]   clkdiv = 2'b00;
reg             phiMref = 1'b0;
wire            phiM_PCEN_n = ~(clkdiv == 2'b11);
always @(posedge EMUCLK) begin
    if(clkdiv == 2'b11) begin clkdiv <= 2'b00; phiMref <= 1'b1; end
    else clkdiv <= clkdiv + 2'b01;

    if(clkdiv == 2'b01) phiMref <= 1'b0;
end


//async reset
initial begin
    #30 IC_n <= 1'b0;
    #800 IC_n <= 1'b1;
end


//main chip
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



task automatic IKA2151_write (
    input       [7:0]   i_TARGET_ADDR,
    input       [7:0]   i_WRITE_DATA,
    ref logic           o_CS_n,
    ref logic           o_WR_n,
    ref logic           o_A0,
    ref logic   [7:0]   o_DATA
); begin
    #0   o_CS_n = 1'b0; o_WR_n = 1'b1; o_A0 = 1'b0; o_DATA = i_TARGET_ADDR;
    #30  o_CS_n = 1'b0; o_WR_n = 1'b0; o_A0 = 1'b0; o_DATA = i_TARGET_ADDR;
    #40  o_CS_n = 1'b1; o_WR_n = 1'b1; o_A0 = 1'b0; o_DATA = i_TARGET_ADDR;
    #30  o_CS_n = 1'b0; o_WR_n = 1'b1; o_A0 = 1'b1; o_DATA = i_WRITE_DATA;
    #30  o_CS_n = 1'b0; o_WR_n = 1'b0; o_A0 = 1'b1; o_DATA = i_WRITE_DATA;
    #40  o_CS_n = 1'b1; o_WR_n = 1'b1; o_A0 = 1'b1; o_DATA = i_WRITE_DATA;
end endtask

initial begin
    #900;
    #0   IKA2151_write(8'h18, 8'hFF, CS_n, WR_n, A0, DIN); //write 0xFF, 0x18(LFRQ)
    #100 IKA2151_write(8'h1B, 8'h02, CS_n, WR_n, A0, DIN); //write 0x02, 0x1B(CT/W)
    #100 IKA2151_write(8'h28, 8'h4A, CS_n, WR_n, A0, DIN); //write 0x7F, 0x28(KC)
    #100 IKA2151_write(8'h38, 8'h70, CS_n, WR_n, A0, DIN); //write 0x10, 0x38(PMS) pms = 3'b111
end

endmodule