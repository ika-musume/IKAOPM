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
    #900 IC_n <= 1'b1;
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
    #1100;
    #0   IKA2151_write(8'h18, 8'hFF, CS_n, WR_n, A0, DIN); //write 0xFF, 0x18(LFRQ)
    #500 IKA2151_write(8'h1B, 8'h01, CS_n, WR_n, A0, DIN); //write 0x02, 0x1B(CT/W)
    #500 IKA2151_write(8'h28, 8'h4E, CS_n, WR_n, A0, DIN); //write 0x3A, 0x28(KC)

    //PG
    #500 IKA2151_write(8'h38, {1'b0, 3'b000, 2'b00, 2'b00}, CS_n, WR_n, A0, DIN); //write 0x10, 0x38(PMS/AMS) pms = 3'b111
    #500 IKA2151_write(8'hC0, {2'b00, 1'b0, 5'b11100}, CS_n, WR_n, A0, DIN); //write 0x00, 0xC0(DT2/D2R) dt2 = 2'b00
    #500 IKA2151_write(8'hC8, {2'b01, 1'b0, 5'b00000}, CS_n, WR_n, A0, DIN); //write 0x40, 0xC8(DT2/D2R) dt2 = 2'b01
    #500 IKA2151_write(8'hD0, {2'b10, 1'b0, 5'b00000}, CS_n, WR_n, A0, DIN); //write 0x80, 0xD0(DT2/D2R) dt2 = 2'b10
    #500 IKA2151_write(8'hD8, {2'b11, 1'b0, 5'b00000}, CS_n, WR_n, A0, DIN); //write 0xC0, 0xD8(DT2/D2R) dt2 = 2'b11
    #500 IKA2151_write(8'hDF, {2'b00, 1'b0, 5'b11110}, CS_n, WR_n, A0, DIN); //write 0x00, 0xC0(DT2/D2R) dt2 = 2'b00

    //EG
    #500 IKA2151_write(8'h80, {2'b00, 1'b0, 5'b10111}, CS_n, WR_n, A0, DIN); //write 0x1F, 0x80(KS/AR) AR = 5'b11000
    #500 IKA2151_write(8'hA0, {1'b1, 2'b00, 5'b00000}, CS_n, WR_n, A0, DIN); //write 0x1F, 0xD0(AMEN/D1R) D1R = 5'b11000
    #500 IKA2151_write(8'hE0, {4'b0111, 4'b1100}, CS_n, WR_n, A0, DIN); //write 0xEF, 0xE0(D1L/RR)
    #500 IKA2151_write(8'h60, 8'h04, CS_n, WR_n, A0, DIN); //write 0x7F, 0x60(TL)

    //EG(noise)
    #500 IKA2151_write(8'h9F, {2'b00, 1'b0, 5'b10111}, CS_n, WR_n, A0, DIN); //write 0x1F, 0x80(KS/AR) AR = 5'b11000
    #500 IKA2151_write(8'hBF, {1'b1, 2'b00, 5'b11000}, CS_n, WR_n, A0, DIN); //write 0x1F, 0xD0(AMEN/D1R) D1R = 5'b11000
    #500 IKA2151_write(8'hFF, {4'b1011, 4'b1110}, CS_n, WR_n, A0, DIN); //write 0xEF, 0xE0(D1L/RR)
    #500 IKA2151_write(8'h7F, 8'h00, CS_n, WR_n, A0, DIN); //write 0x7F, 0x60(TL)

    //KON
    #60000 IKA2151_write(8'h08, {1'b0, 4'b0001, 3'd0}, CS_n, WR_n, A0, DIN); //write 0x7F, 0x08(KON)
    #500   IKA2151_write(8'h08, {1'b0, 4'b1000, 3'd7}, CS_n, WR_n, A0, DIN); //write 0x7F, 0x08(KON)
    #520000 IKA2151_write(8'h08, {1'b0, 4'b0000, 3'd0}, CS_n, WR_n, A0, DIN); //write 0x7F, 0x08(KON)
    #220000  IKA2151_write(8'h08, {1'b0, 4'b0000, 3'd7}, CS_n, WR_n, A0, DIN); //write 0x7F, 0x08(KON)
end

endmodule