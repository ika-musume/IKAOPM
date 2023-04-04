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
wire            cycle_31, cycle_01; //to REG
wire            cycle_12_28, cycle_05_21, cycle_byte; //to LFO
wire            cycle_05, cycle_10; //to PG
wire            cycle_03, cycle_00_16, cycle_01_to_16; //to EG
wire            cycle_12, cycle_15_31; //to NOISE

//global
wire    [7:0]   test;

//NOISE
wire    [4:0]   nfrq;
wire            acc_noise, lfo_noise; //same signal

//LFO
wire    [7:0]   lfrq;
wire    [6:0]   pmd;
wire    [6:0]   amd;
wire    [1:0]   w;
wire            lfrq_update;
wire    [7:0]   lfa, lfp;

//PG
wire    [6:0]   kc;
wire    [5:0]   kf;
wire    [2:0]   pms;
wire    [1:0]   dt2;
wire    [2:0]   dt1;
wire    [3:0]   mul;
wire    [4:0]   pdelta_shamt;

//EG
wire            kon;
wire    [1:0]   ks;
wire    [4:0]   ar;
wire    [4:0]   d1r;
wire    [4:0]   d2r;
wire    [3:0]   rr;
wire    [3:0]   d1l;
wire    [6:0]   tl;
wire    [1:0]   ams;



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

    .o_CYCLE_01                 (cycle_01                   ),
    .o_CYCLE_31                 (cycle_31                   ),

    .o_CYCLE_12_28              (cycle_12_28                ),
    .o_CYCLE_05_21              (cycle_05_21                ),
    .o_CYCLE_BYTE               (cycle_byte                 ),

    .o_CYCLE_05                 (cycle_05                   ),
    .o_CYCLE_10                 (cycle_10                   ),

    .o_CYCLE_03                 (cycle_03                   ),
    .o_CYCLE_00_16              (cycle_00_16                ),
    .o_CYCLE_01_TO_16           (cycle_01_to_16             ),

    .o_CYCLE_12                 (cycle_12                   ),
    .o_CYCLE_15_31              (cycle_15_31                )
);

IKA2151_reg #(
    .USE_BRAM_FOR_D32REG        (0                          )
) REG (
    .i_EMUCLK                   (i_EMUCLK                   ),
    .i_MRST_n                   (mrst_n                     ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_01                 (cycle_01                   ),
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

    .o_TEST                     (test                       ),
    .o_CT                       (                           ),
    .o_NE                       (                           ),
    .o_NFRQ                     (nfrq                       ),
    .o_CLKA1                    (                           ),
    .o_CLKA2                    (                           ),
    .o_CLKB                     (                           ),
    .o_TIMERCTRL                (                           ),

    .o_LFRQ                     (lfrq                       ),
    .o_PMD                      (pmd                        ),
    .o_AMD                      (amd                        ),
    .o_W                        (w                          ),
    .o_LFRQ_UPDATE              (lfrq_update                ),

    .o_KC                       (kc                         ),
    .o_KF                       (kf                         ),
    .o_PMS                      (pms                        ),
    .o_DT2                      (dt2                        ),
    .o_DT1                      (dt1                        ),
    .o_MUL                      (mul                        ),

    .o_KON                      (kon                        ),
    .o_KS                       (ks                         ),
    .o_AR                       (ar                         ),
    .o_D1R                      (d1r                        ),
    .o_D2R                      (d2r                        ),
    .o_RR                       (rr                         ),
    .o_D1L                      (d1l                        ),
    .o_TL                       (tl                         ),
    .o_AMS                      (ams                        ),

    .o_ALG                      (                           ),
    .o_FL                       (                           ),

    .o_RL                       (                           ),

    .i_REG_LFO_CLK              (                           )
);



IKA2151_noise NOISE (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_12                 (cycle_12                   ),
    .i_CYCLE_15_31              (cycle_15_31                ),

    .i_NFRQ                     (nfrq                       ),

    .i_NOISE_ATTENLEVEL         (1'b0                       ),

    .o_ACC_NOISE                (                           ),
    .o_LFO_NOISE                (lfo_noise                  )
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
    .i_TEST                     (test                       ),

    .i_LFRQ_UPDATE              (lfrq_update                ),

    .i_LFO_NOISE                (lfo_noise                  ),

    .o_LFA                      (lfa                        ),
    .o_LFP                      (lfp                        )
);


IKA2151_pg #(
    .USE_BRAM_FOR_PHASEREG      (1                          )
) PG (
    .i_EMUCLK                   (i_EMUCLK                   ),

    .i_MRST_n                   (mrst_n                     ),
    
    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_05                 (cycle_05                   ),
    .i_CYCLE_10                 (cycle_10                   ),

    .i_KC                       (kc                         ),
    .i_KF                       (kf                         ),
    .i_PMS                      (pms                        ),
    .i_DT2                      (dt2                        ),
    .i_DT1                      (dt1                        ),
    .i_MUL                      (mul                        ),
    .i_TEST                     (test                       ),

    .i_LFP                      (lfp                        ),

    .i_PG_PHASE_RST             (1'b0 | ~mrst_n             ),
    .o_EG_PDELTA_SHIFT_AMOUNT   (pdelta_shamt               ),
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

    .i_KON                      (kon                        ),
    .i_KS                       (ks                         ),
    .i_AR                       (ar                         ),
    .i_D1R                      (d1r                        ),
    .i_D2R                      (d2r                        ),
    .i_RR                       (rr                         ),
    .i_D1L                      (d1l                        ),
    .i_TL                       (tl                         ),
    .i_AMS                      (ams                        ),
    .i_LFA                      (8'd0                        ),
    .i_TEST                     (test                       ),

    .i_EG_PDELTA_SHIFT_AMOUNT   (pdelta_shamt               ),

    .o_OP_ATTENLEVEL            (                           ),
    .o_NOISE_ATTENLEVEL         (                           ),
    .o_REG_ATTENLEVEL_CH8_C2    (                           )
);


endmodule