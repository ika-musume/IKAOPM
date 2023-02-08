module IKA2151_lfo
(
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_30,
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_00_TO_15_n
);




endmodule