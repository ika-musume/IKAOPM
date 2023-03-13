module IKA2151_reg #(
    parameter USE_BRAM_FOR_SR8 = 0,  
    parameter USE_BRAM_FOR_SR32 = 0
    ) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //timings
    input   wire            i_CYCLE_31,

    //control/address
    input   wire            i_CS_n,
    input   wire            i_RD_n,
    input   wire            i_WR_n,
    input   wire            i_A0,

    //bus data io
    input   wire    [7:0]   i_D,
    output  wire    [7:0]   o_D,

    //output driver enable
    output  wire            o_CTRL_OE_n,

    //timer input
    input   wire            i_TIMERA_FLAG,
    input   wire            i_TIMERB_FLAG,
    input   wire            i_TIMERA_OVFL,

    //register output
    output  reg     [7:0]   o_TEST,     //0x01      TEST register

    output  wire    [1:0]   o_CT,       //0x1B[7:6] CT2/CT1

    output  reg             o_NE,       //0x0F[7]   Noise Enable
    output  reg     [4:0]   o_NFRQ,     //0x0F[4:0] Noise Frequency

    output  reg     [7:0]   o_CLKA1,    //0x10      Timer A D[9:2]
    output  reg     [1:0]   o_CLKA2,    //0x11      Timer A D[1:0]
    output  reg     [7:0]   o_CLKB,     //0x12      Timer B
    output  reg     [5:0]   o_TIMERCTRL,//0x14      Timer Control

    output  reg     [7:0]   o_LFRQ,     //0x18      LFO frequency
    output  reg     [6:0]   o_PMD,      //0x19[6:0] D[7] == 1
    output  reg     [6:0]   o_AMD,      //0x19[6:0] D[7] == 0
    output  reg     [1:0]   o_W,        //0x1B[1:0] Waveform type
    output  wire            o_LFRQ_UPDATE,

    //PG
    output  wire    [6:0]   o_KC, 
    output  wire    [5:0]   o_KF, 
    output  wire    [2:0]   o_PMS,
    output  wire    [1:0]   o_DT2,
    output  wire    [2:0]   o_DT1,
    output  wire    [3:0]   o_MUL,

    //EG
    output  wire            o_KON,
    output  wire    [1:0]   o_KS,
    output  wire    [4:0]   o_AR,
    output  wire    [4:0]   o_D1R,
    output  wire    [4:0]   o_D2R,
    output  wire    [3:0]   o_RR,
    output  wire    [3:0]   o_D1L,
    output  wire    [3:0]   o_TL,
    output  wire    [1:0]   o_AMS,

    //OP
    output  wire    [2:0]   o_ALG,

    //ACC
    output  wire    [1:0]   o_RL,

    //input data for test registers
    input   wire            i_REG_LFO_CLK
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Bus/control data inlatch and synchronizer
////

//3.58MHz phiM and 1.79MHz phi1 would be too slow to catch up
//bus transaction speed. So the chip "latch" the input first.
//3-stage DFF chain will synchronize the data then.

//latch outputs
wire    [7:0]   bus_inlatch;
wire            dreg_rq_inlatch, areg_rq_inlatch;

//Synchronizer DFF
reg             dreg_rq_synced0, dreg_rq_synced1, dreg_rq_synced2;
reg             areg_rq_synced0, areg_rq_synced1, areg_rq_synced2;
wire            data_ld = dreg_rq_synced2;
wire            addr_ld = areg_rq_synced2;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) begin
        dreg_rq_synced0 <= 1'b0;
        dreg_rq_synced1 <= 1'b0;
        dreg_rq_synced2 <= 1'b0;

        areg_rq_synced0 <= 1'b0;
        areg_rq_synced1 <= 1'b0;
        areg_rq_synced2 <= 1'b0;
    end
    else begin
        if(!phi1ncen_n) begin
            //data load
            dreg_rq_synced0 <= dreg_rq_inlatch;
            dreg_rq_synced2 <= dreg_rq_synced1;

            //address load
            areg_rq_synced0 <= areg_rq_inlatch;
            areg_rq_synced2 <= areg_rq_synced1;
        end

        if(!phi1pcen_n) begin
            //data load
            dreg_rq_synced1 <= dreg_rq_synced0;

            //address load
            areg_rq_synced1 <= areg_rq_synced0;
        end
    end
end

//D latch
primitive_dlatch #(.WIDTH(8)) BUS_INLATCH (
    .i_EN(|{i_CS_n, i_WR_n}), .i_D(i_D), .i_Q(bus_inlatch)
);

//SR latch
primitive_srlatch DREG_RQ_INLATCH (
    .i_S(~(|{i_CS_n, i_WR_n, ~i_A0, ~mrst_n} | dreg_rq_synced1)), .i_R(dreg_rq_synced1), .o_Q(dreg_rq_inlatch)
);
primitive_srlatch AREG_RQ_INLATCH (
    .i_S(~(|{i_CS_n, i_WR_n,  i_A0, ~mrst_n} | areg_rq_synced1)), .i_R(areg_rq_synced1), .o_Q(areg_rq_inlatch)
);



///////////////////////////////////////////////////////////
//////  Loreg decoder
////

wire            reg10_en, reg11_en, reg12_en, reg14_en; //timer related
wire            reg01_en; //test register
wire            reg0f_en; //noise generator
wire            reg19_en; //vibrato
wire            reg18_en; //LFO
wire            reg1b_en; //GPO
wire            reg08_en; //KON register

assign  o_LFRQ_UPDATE = reg18_en; //LFO frequency update flag;

submdl_loreg_decoder #(.TARGET_ADDR(8'h10)) REG10 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg10_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h11)) REG11 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg11_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h12)) REG12 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg12_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h14)) REG14 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg14_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h01)) REG01 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg01_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h0f)) REG0f (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg0f_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h19)) REG19 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg19_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h18)) REG18 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg18_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h1b)) REG1b (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg1b_en)
);

submdl_loreg_decoder #(.TARGET_ADDR(8'h08)) REG08 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg08_en)
);



///////////////////////////////////////////////////////////
//////  Hireg temp register, flags, decoder
////

//
//  TEMPORARY ADDRESS REGISTER FOR HIREG
//

//hireg temporary address register load enable
wire            hireg_addrreg_en = (addr_ld & (bus_inlatch[7:5] != 3'b000)); //not 000X_XXXX

//hireg "address" temporary register with async reset
reg     [7:0]   hireg_addr;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) begin
        hireg_addr <= 8'hFF;
    end
    else begin
        if(!phi1pcen_n) begin
            if(hireg_addrreg_en) hireg_addr <= bus_inlatch;
        end
    end
end

//hireg address valid flag, reset when the address input is loreg
reg             hireg_addr_valid;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        hireg_addr_valid <= hireg_addrreg_en | (hireg_addr_valid & ~addr_ld);
    end
end


//
//  TEMPORARY DATA REGISTER FOR HIREG
//

//hireg temporary data register load enable
wire            hireg_datareg_en = data_ld & hireg_addr_valid;

//hireg "data" temporary register with async reset
reg     [7:0]   hireg_data;
always @(posedge i_EMUCLK or negedge mrst_n) begin
    if(!mrst_n) begin
        hireg_addr <= 8'hFF;
    end
    else begin
        if(!phi1pcen_n) begin
            if(hireg_datareg_en) hireg_data <= bus_inlatch;
        end
    end
end

//hireg data valid flag, reset when the data input is loreg
reg             hireg_data_valid;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        hireg_addr_valid <= hireg_addrreg_en | (hireg_addr_valid & ~addr_ld);
    end
end


//
//  HIREG ADDRESS COUNTER
//

reg     [4:0]   hireg_addrcntr;
always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin
        if(i_CYCLE_31) hireg_addrcntr <= 5'd0;
        else hireg_addrcntr <= (hireg_addrcntr == 5'd31) ? 5'd0 : hireg_addrcntr + 5'd1;
    end
end


//
//  DECODER
//

reg             reg38_3f_en; //PMS[6:4]/AMS[1:0]
reg             reg30_37_en; //KF[7:2]
reg             reg28_2f_en; //KC[6:0]
reg             reg20_27_en; //RL[7:6]/FL[5:3]/CONNECT(algorithm)[2:0]

reg             rege0_ff_en; //D1L[7:4]/RR[3:0]
reg             regc0_df_en; //DT2[7:6]/D2R[4:0]
reg             rega0_bf_en; //AMS-EN[7]/D1R[4:0]
reg             reg80_9f_en; //KS[7:6]/AR[4:0]
reg             reg60_7f_en; //TL[6:0]
reg             reg40_5f_en; //DT1[6:4]/MUL[3:0]

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        reg38_3f_en <= (hireg_addr[7:3] == 5'b00111) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg30_37_en <= (hireg_addr[7:3] == 5'b00110) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg28_2f_en <= (hireg_addr[7:3] == 5'b00101) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;
        reg20_27_en <= (hireg_addr[7:3] == 5'b00100) & (hireg_addr[2:0] == hireg_addrcntr[2:0]) & hireg_data_valid;

        rege0_ff_en <= (hireg_addr[7:5] == 3'b111)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        regc0_df_en <= (hireg_addr[7:5] == 3'b110)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        rega0_bf_en <= (hireg_addr[7:5] == 3'b101)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg80_9f_en <= (hireg_addr[7:5] == 3'b100)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg60_7f_en <= (hireg_addr[7:5] == 3'b011)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
        reg40_5f_en <= (hireg_addr[7:5] == 3'b010)   & (hireg_addr[4:0] == hireg_addrcntr)      & hireg_data_valid;
    end
end



///////////////////////////////////////////////////////////
//////  Low registers
////

//
//  GENERAL STATIC REGISTERS
//

reg     [1:0]   ct_reg;
assign  o_CT[0] = ct_reg[0];
assign  o_CT[1] = o_TEST[3] ? i_REG_LFO_CLK : ct_reg[1]; //LSI test purpose

reg             csm_reg;
reg     [6:0]   kon_temp_reg;

always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin //positive edge!!
        if(!mrst_n) begin
            o_TEST          <= 8'h0;

            ct_reg          <= 2'b00;

            o_NE            <= 1'b0;
            o_NFRQ          <= 5'h00;

            o_CLKA1         <= 8'h0;
            o_CLKA2         <= 2'h0;
            o_CLKB          <= 8'h0;
            o_TIMERCTRL     <= 6'b00_00_00;

            o_LFRQ          <= 8'h00;
            o_PMD           <= 7'h00;
            o_AMD           <= 7'h00;
            o_W             <= 2'd0;

            csm_reg         <= 1'b0;
            kon_temp_reg    <= 7'b0000_000;
        end
        else begin
            o_TEST          <= reg01_en ? bus_inlatch      : o_TEST;

            ct_reg          <= reg1b_en ? bus_inlatch[7:6] : ct_reg;
            
            o_NE            <= reg0f_en ? bus_inlatch[7]   : o_NE;
            o_NFRQ          <= reg0f_en ? bus_inlatch[4:0] : o_NFRQ;

            o_CLKA1         <= reg10_en ? bus_inlatch      : o_CLKA1;
            o_CLKA2         <= reg11_en ? bus_inlatch[1:0] : o_CLKA2;
            o_CLKB          <= reg12_en ? bus_inlatch      : o_CLKB;
            o_TIMERCTRL     <= reg14_en ? bus_inlatch[5:0] : o_TIMERCTRL;

            o_LFRQ          <= reg18_en ? bus_inlatch      : o_LFRQ;
            o_PMD           <= reg19_en ? (bus_inlatch[7] == 1'b1) ? bus_inlatch[6:0] : o_PMD :
                                          o_PMD;
            o_AMD           <= reg19_en ? (bus_inlatch[7] == 1'b0) ? bus_inlatch[6:0] : o_AMD :
                                          o_AMD;
            o_W             <= reg1b_en ? bus_inlatch[1:0] : o_W;

            csm_reg         <= reg14_en ? bus_inlatch[7]   : csm_reg;
            kon_temp_reg    <= reg08_en ? bus_inlatch[6:0] : kon_temp_reg;
        end
    end
end


//
//  DYNAMIC REGISTERS FOR KON
//

reg             ch_equal, force_kon, force_kon_z;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        ch_equal <= hireg_addrcntr == {2'b00, kon_temp_reg[2:0]}; //channel number

        force_kon <= i_TIMERA_OVFL & csm_reg;
        force_kon_z <= force_kon;
    end
end

/*
    define 8-bit, 4-line, total 32-stage shift register(8*4)
    Data flows from LSB to MSB. The LSB of each line has a multiplexer
    to choose data to be written in the LSB register.
    When ch_equal is activated, new data from temporary kon reg is loaded.
    If not, it gets data from the MSB of the previous "line"
*/
reg             kon_m1, kon_m2, kon_c1, kon_c2;
reg     [7:0]   kon_sr_0_7, kon_sr_8_15, kon_sr_16_23, kon_sr_24_31;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        kon_m1 <= kon_temp_reg[3]; kon_m2 <= kon_temp_reg[5];
        kon_c1 <= kon_temp_reg[4]; kon_c2 <= kon_temp_reg[6];

        //line 1
        kon_sr_0_7[0] <= ch_equal ? kon_m1 : (kon_sr_24_31[7] & mrst_n);
        kon_sr_0_7[7:1] <= kon_sr_0_7[6:0];

        //line 2
        kon_sr_8_15[0] <= ch_equal ? kon_c2 : kon_sr_0_7[7];
        kon_sr_8_15[7:1] <= kon_sr_8_15[6:0];

        //line 3
        kon_sr_16_23[0] <= ch_equal ? kon_c1 : kon_sr_8_15[7];
        kon_sr_16_23[7:1] <= kon_sr_16_23[6:0];

        //line 4
        kon_sr_24_31[0] <= ch_equal ? kon_m2 : kon_sr_16_23[7];
        kon_sr_24_31[7:1] <= kon_sr_24_31[6:0];
    end
end

wire            kon_data = kon_sr_24_31[5] | force_kon_z;



///////////////////////////////////////////////////////////
//////  High registers
////

//
//  SR8 REGISTERS
//

/*
    8-stage sr for the data below:

    Address 38_3f : PMS[6:4]    AMS[1:0]
    Address 30_37 : KF[7:2]
    Address 28_2f : KC[6:0]
    Address 20_27 : RL[7:6]     FL[5:3]     CONNECT(algorithm)[2:0]
*/

//define register
reg     [2:0]   pms_reg[0:7]; //phase modulation sensitivity
reg     [1:0]   ams_reg[0:7]; //amplitude modulation sensitivity
reg     [5:0]   kf_reg[0:7];  //key fraction
reg     [6:0]   kc_reg[0:7];  //key code
reg     [2:0]   fl_reg[0:7];  //feedback level
reg     [2:0]   alg_reg[0:7]; //algorithm type
reg     [1:0]   rl_reg[0:7];  //right/left channel enable

//define taps
assign  o_PMS = !mrst_n ? 3'd0  : reg38_3f_en ? hireg_data[6:4] : pms_reg[7]; //input of stage 0
assign  o_KF = kf_reg[0];
assign  o_KC = kc_reg[0];
assign  o_FL = fl_reg[6];
assign  o_ALG = alg_reg[3];
assign  o_RL = rl_reg[4];

//first stage
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        pms_reg[0] <= !mrst_n ? 3'd0  : reg38_3f_en ? hireg_data[6:4] : pms_reg[7];
        ams_reg[0] <= !mrst_n ? 2'd0  : reg38_3f_en ? hireg_data[1:0] : ams_reg[7];
        kf_reg[0]  <= !mrst_n ? 6'd0  : reg30_37_en ? hireg_data[7:2] : kf_reg[7]; 
        kc_reg[0]  <= !mrst_n ? 7'd0  : reg28_2f_en ? hireg_data[6:0] : kc_reg[7]; 
        fl_reg[0]  <= !mrst_n ? 3'd0  : reg20_27_en ? hireg_data[5:3] : fl_reg[7]; 
        alg_reg[0] <= !mrst_n ? 3'd0  : reg20_27_en ? hireg_data[2:0] : alg_reg[7];
        rl_reg[0]  <= !mrst_n ? 2'b00 : reg20_27_en ? hireg_data[7:6] : rl_reg[7]; 
    end
end

//the other stages
genvar stage;
generate
for(stage = 0; stage < 7; stage = stage + 1) begin : hireg_sr8
    always @(posedge i_EMUCLK) begin
        if(!phi1ncen_n) begin
            pms_reg[stage + 1] <= pms_reg[stage];
            ams_reg[stage + 1] <= ams_reg[stage];
            kf_reg[stage + 1]  <= kf_reg[stage];
            kc_reg[stage + 1]  <= kc_reg[stage];
            fl_reg[stage + 1]  <= fl_reg[stage];
            alg_reg[stage + 1] <= alg_reg[stage];
            rl_reg[stage + 1]  <= rl_reg[stage];
        end
    end
end
endgenerate


//
//  SR32 REGISTERS
//

/*
    32-stage sr for the data below:

    Address e0_ff : D1L[7:4]    RR[3:0]
    Address c0_df : DT2[7:6]    D2R[4:0]
    Address a0_bf : AMS-EN[7]   D1R[4:0]
    Address 80_9f : KS[7:6]     AR[4:0]
    Address 60_7f : TL[6:0]
    Address 40_5f : DT1[6:4]    MUL[3:0]
*/

//define register
reg     [1:0]   dt2_reg[0:31];  //detune2
reg     [2:0]   dt1_reg[0:31];  //detune1
reg     [3:0]   mul_reg[0:31];  //phase multuply
reg     [4:0]   ar_reg[0:31];   //attack rate
reg     [4:0]   d1r_reg[0:31];  //first decay rate
reg     [4:0]   d2r_reg[0:31];  //second decay rate
reg     [3:0]   rr_reg[0:31];   //release rate
reg     [3:0]   d1l_reg[0:31];  //first decay level
reg             amen_reg[0:31]; //amplitude modulation enable
reg     [1:0]   ks_reg[0:31];   //key scale
reg     [6:0]   tl_reg[0:31];   //total level

//define taps
assign  o_DT2 = dt2_reg[26];
assign  o_DT1 = dt1_reg[31];
assign  o_MUL = mul_reg[31];
assign  o_AR = ar_reg[31];
assign  o_D1R = d1r_reg[31];
assign  o_D2R = d2r_reg[31];
assign  o_RR = rr_reg[31];
assign  o_D1L = d1l_reg[31];
assign  o_KS = ks_reg[31];
assign  o_TL = tl_reg[31];

assign  o_AMS = ams_reg[7] & {2{amen_reg[31]}};

//first stage
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        dt2_reg[0]  <= !mrst_n ? 2'd0 : regc0_df_en ? hireg_data[7:6] : dt2_reg[0];
        dt1_reg[0]  <= !mrst_n ? 3'd0 : reg40_5f_en ? hireg_data[6:4] : dt1_reg[0];
        mul_reg[0]  <= !mrst_n ? 4'd0 : reg40_5f_en ? hireg_data[3:0] : mul_reg[0];
        ar_reg[0]   <= !mrst_n ? 5'd0 : reg80_9f_en ? hireg_data[4:0] : ar_reg[0];
        d1r_reg[0]  <= !mrst_n ? 5'd0 : rega0_bf_en ? hireg_data[4:0] : d1r_reg[0];
        d2r_reg[0]  <= !mrst_n ? 5'd0 : regc0_df_en ? hireg_data[4:0] : d2r_reg[0];
        rr_reg[0]   <= !mrst_n ? 4'd0 : rege0_ff_en ? hireg_data[3:0] : rr_reg[0];
        d1l_reg[0]  <= !mrst_n ? 4'd0 : rege0_ff_en ? hireg_data[7:4] : d1l_reg[0];
        amen_reg[0] <= !mrst_n ? 1'b0 : rega0_bf_en ? hireg_data[7]   : amen_reg[0];
        ks_reg[0]   <= !mrst_n ? 2'd0 : reg80_9f_en ? hireg_data[7:6] : ks_reg[0] ;
        tl_reg[0]   <= !mrst_n ? 7'd0 : reg60_7f_en ? hireg_data[6:0] : tl_reg[0] ;
    end
end

//the other stages
generate
for(stage = 0; stage < 31; stage = stage + 1) begin : hireg_sr32
    always @(posedge i_EMUCLK) begin
        if(!phi1ncen_n) begin
            dt2_reg[stage + 1]  <= dt2_reg[stage];
            dt1_reg[stage + 1]  <= dt1_reg[stage];
            mul_reg[stage + 1]  <= mul_reg[stage];
            ar_reg[stage + 1]   <= ar_reg[stage];
            d1r_reg[stage + 1]  <= d1r_reg[stage];
            d2r_reg[stage + 1]  <= d2r_reg[stage];
            rr_reg[stage + 1]   <= rr_reg[stage];
            d1l_reg[stage + 1]  <= d1l_reg[stage];
            amen_reg[stage + 1] <= amen_reg[stage];
            ks_reg[stage + 1]   <= ks_reg[stage];
            tl_reg[stage + 1]   <= tl_reg[stage];
        end
    end
end
endgenerate



///////////////////////////////////////////////////////////
//////  Read-only register multiplexer
////














endmodule

module submdl_loreg_decoder #(parameter TARGET_ADDR = 8'h00 ) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //internal clock
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //address to be decoded
    input   wire    [7:0]   i_ADDR,

    input   wire            i_ADDR_LD,
    input   wire            i_DATA_LD,

    output  wire            o_REG_LD
);

reg             loreg_addr_valid;
always @(posedge i_EMUCLK) begin
    if(!i_phi1_NCEN_n) begin
        loreg_addr_valid <= ((TARGET_ADDR == i_ADDR) & i_ADDR_LD) | (loreg_addr_valid & ~i_ADDR_LD);
    end
end

assign  o_REG_LD = loreg_addr_valid & i_DATA_LD;

endmodule