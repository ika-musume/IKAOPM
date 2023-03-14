module IKA2151
(
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n, //phiM clock enable

    //chip reset
    input   wire            i_IC_n,    

    //phi1
    output  wire            o_phi1,

    //bus control and address
    input   wire            i_CS_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n,
    input   wire            i_A0,

    //bus data
    input   wire    [7:0]   i_D,
    output  wire    [7:0]   o_D,

    //output driver enable
    output  wire            o_CTRL_OE_n,

    //sh
    output  wire            o_SH1,
    output  wire            o_SH2
);


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n, phi1ncen_n;
wire            mrst_n;



///////////////////////////////////////////////////////////
//////  Interconnects
////

//timings
wire            cycle_12_28, cycle_05_21, cycle_byte; //to LFO
wire            cycle_03, cycle_31, cycle_00_16, cycle_01_to_16; //to EG

//global
wire    [7:0]   test;

//LFO
wire    [7:0]   lfrq;
wire    [6:0]   pmd;
wire    [6:0]   amd;
wire    [1:0]   w;
wire            lfrq_update;


wire    [7:0]   lfa, lfp;



IKA2151_timinggen TIMINGGEN (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_IC_n                     (i_IC_n                     ),
    .o_MRST_n                   (mrst_n                     ),

    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),

    .o_phi1                     (o_phi1                     ),
    .o_phi1_PCEN_n              (phi1pcen_n                 ),
    .o_phi1_NCEN_n              (phi1ncen_n                 ),

    .o_SH1                      (o_SH1                      ),
    .o_SH2                      (o_SH2                      ),

    .o_CYCLE_12_28              (cycle_12_28                ),
    .o_CYCLE_05_21              (cycle_05_21                ),
    .o_CYCLE_BYTE               (cycle_byte                 ),

    .o_CYCLE_03                 (cycle_03                   ),
    .o_CYCLE_31                 (cycle_31                   ),
    .o_CYCLE_00_16              (cycle_00_16                ),
    .o_CYCLE_01_TO_16           (cycle_01_to_16             )
);

IKA2151_reg #(
    .USE_BRAM_FOR_SR8           (0                          ),
    .USE_BRAM_FOR_SR32          (0                          )
) REG (
    .i_EMUCLK                   (i_EMUCLK                   ),
    .i_MRST_n                   (mrst_n                     ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_31                 (cycle_31                   ),

    .i_CS_n                     (i_CS_n                     ),
    .i_RD_n                     (i_RD_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_A0                       (i_A0                       ),

    .i_D                        (i_D                        ),
    .o_D                        (o_D                        ),

    .o_CTRL_OE_n                (o_CTRL_OE_n                ),

    .i_TIMERA_FLAG              (                           ),
    .i_TIMERB_FLAG              (                           ),
    .i_TIMERA_OVFL              (                           ),

    .o_TEST                     (                           ),
    .o_CT                       (                           ),
    .o_NE                       (                           ),
    .o_NFRQ                     (                           ),
    .o_CLKA1                    (                           ),
    .o_CLKA2                    (                           ),
    .o_CLKB                     (                           ),
    .o_TIMERCTRL                (                           ),

    .o_LFRQ                     (lfrq                       ),
    .o_PMD                      (pmd                        ),
    .o_AMD                      (amd                        ),
    .o_W                        (w                          ),
    .o_LFRQ_UPDATE              (lfrq_update                ),

    .o_KC                       (                           ),
    .o_KF                       (                           ),
    .o_PMS                      (                           ),
    .o_DT2                      (                           ),
    .o_DT1                      (                           ),
    .o_MUL                      (                           ),

    .o_KON                      (                           ),
    .o_KS                       (                           ),
    .o_AR                       (                           ),
    .o_D1R                      (                           ),
    .o_D2R                      (                           ),
    .o_RR                       (                           ),
    .o_D1L                      (                           ),
    .o_TL                       (                           ),
    .o_AMS                      (                           ),
    .o_ALG                      (                           ),
    .o_RL                       (                           ),
    .i_REG_LFO_CLK              (                           )
);


IKA2151_lfo LFO (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),
    
    .i_CYCLE_12_28              (cycle_12_28                ),
    .i_CYCLE_05_21              (cycle_05_21                ),
    .i_CYCLE_BYTE               (cycle_byte                 ),
    
    .i_LFRQ                     (lfrq                       ),
    .i_PMD                      (7'd127                     ),
    .i_AMD                      (7'd127                     ),
    .i_W                        (w                          ),
    .i_TEST                     (8'h00                      ),

    .i_LFRQ_UPDATE              (lfrq_update                ),

    .i_LFO_NOISE                (1'b0                       ),

    .o_LFA                      (lfa                        ),
    .o_LFP                      (lfp                        )
);


IKA2151_pg PG (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_05                 (                           ),

    .i_KC                       (                           ),
    .i_KF                       (                           ),
    .i_PMS                      (                           ),
    .i_DT2                      (                           ),
    .i_DT1                      (                           ),
    .i_MUL                      (                           ),
    .i_TEST                     (                           ),

    .i_LFP                      (lfp                        ),

    .i_PG_PHASE_RST             (                           ),
    .o_EG_PDELTA_SHIFT_AMOUNT   (                           ),
    .o_OP_ORIGINAL_PHASE        (                           ),
    .o_REG_PHASE_CH6_C2         (                           )
);


IKA2151_eg EG (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_03                 (cycle_03                   ),
    .i_CYCLE_31                 (cycle_31                   ),
    .i_CYCLE_00_16              (cycle_00_16                ),
    .i_CYCLE_01_TO_16           (cycle_01_to_16             ),

    .i_KON                      (                           ),
    .i_KS                       (                           ),
    .i_AR                       (                           ),
    .i_D1R                      (                           ),
    .i_D2R                      (                           ),
    .i_RR                       (                           ),
    .i_D1L                      (                           ),
    .i_TL                       (                           ),
    .i_AMS                      (                           ),
    .i_LFA                      (                           ),
    .i_TEST                     (                           ),

    .i_EG_PDELTA_SHIFT_AMOUNT   (                           ),

    .o_OP_ATTENLEVEL            (                           ),
    .o_NOISE_ATTENLEVEL         (                           ),
    .o_REG_ATTENLEVEL_CH8_C2    (                           )
);

endmodule