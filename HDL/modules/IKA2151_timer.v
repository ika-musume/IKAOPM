module IKA2151_timer (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_31,

    //control input
    input   wire    [7:0]   i_CLKA1,
    input   wire    [1:0]   i_CLKA2,
    input   wire    [7:0]   i_CLKB,
    input   wire            i_TIMERA_RUN,
    input   wire            i_TIMERB_RUN,
    input   wire            i_TIMERA_IRQ_EN,
    input   wire            i_TIMERB_IRQ_EN,

    //timer output
    output  wire            o_TIMERA_FLAG,
    output  wire            o_TIMERB_FLAG,
    output  wire            o_TIMERA_OVFL
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;





endmodule