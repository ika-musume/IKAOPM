module IKA2151_noise
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_03,
    input   wire            i_CYCLE_12,
    input   wire            i_CYCLE_14_30,

    //register data
    input   wire    [4:0]   i_NFRQ,

    //output data
    output  wire    [13:0]  o_ACC_NOISE,
    output  wire            o_LFO_NOISE
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;






endmodule