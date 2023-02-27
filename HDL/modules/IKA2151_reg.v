module IKA2151_reg
(
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

    //output driver enable
    output  wire            o_CTRL_OE_n,

    //data io
    input   wire    [7:0]   i_D,
    output  wire    [7:0]   o_D,

    //register output
    output  reg     [7:0]   o_TEST,     //0x01      TEST register

    output  reg     [1:0]   o_CT        //0x1B[7:6] CT2/CT1

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
    output  wire            o_LFO_FREQ_UPDATE,

    //PG
    output  wire    [6:0]   o_KC, 
    output  wire    [5:0]   o_KF, 
    output  wire    [2:0]   o_PMS,
    output  wire    [1:0]   o_DT2,
    output  wire    [1:0]   o_DT1,

    //EG
    output  wire            o_KON
    output  wire    [1:0]   o_KS,
    output  wire    [4:0]   o_AR,
    output  wire    [4:0]   o_D1R
    output  wire    [4:0]   o_D2R
    output  wire    [4:0]   o_RR,
    output  wire    [3:0]   o_D1L
    output  wire    [3:0]   o_TL
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
wire            addr_ld = addr_rq_synced2;
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
submdl_dlatch #(.p_WITDH = 8) inlatch (
    .i_EN(|{i_CS_n, i_WR_n}), i_D(i_D), i_Q(bus_inlatch)
);

//SR latch
submdl_srlatch dreg_rq_inlatch (
    .i_S(~(|{i_CS_n, i_WR_n, ~i_A0, ~mrst_n} | dreg_rq_synced1)), i_R(dreg_rq_synced1), i_Q(dreg_rq_inlatch)
);
submdl_srlatch areg_rq_inlatch (
    .i_S(~(|{i_CS_n, i_WR_n,  i_A0, ~mrst_n} | areg_rq_synced1)), i_R(areg_rq_synced1), i_Q(areg_rq_inlatch)
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

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h10)) reg10 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg10_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h11)) reg11 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg11_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h12)) reg12 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg12_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h14)) reg14 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg14_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h01)) reg01 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg01_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h0f)) reg0f (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg0f_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h19)) reg19 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg19_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h18)) reg18 (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg18_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h1b)) reg1b (
    .i_EMUCLK(i_EMUCLK), .i_phi1_NCEN_n(phi1ncen_n),
    .i_ADDR(bus_inlatch), .i_ADDR_LD(addr_ld), .i_DATA_LD(data_ld), .o_REG_LD(reg1b_en)
);

submdl_loreg_decoder #(.p_TARGET_ADDR(8'h08)) reg08 (
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

reg     [1:0]   ct_reg;
reg             csm_reg;
reg     [6:0]   kon_temp_reg;
assign  o_LFO_FREQ_UPDATE = reg18_en; //LFO frequency update flag;

always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin
        if(!mrst_n) begin
            o_TEST          <= 8'h0;

            ct_reg          <= 2'b00;

            o_NE            <= 1'b0;
            o_NFRQ          <= 5'h00;

            o_CLKA1         <= 8'h0
            o_CLKA2         <= 2'h0;
            o_CLKB          <= 8'h0;
            o_TIMERCTRL     <= 6'b00_00_00;

            o_LFRQ          <= 8'h00;
            o_PMD           <= 7'h00;
            o_AMD           <= 7'h00
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














endmodule

module submdl_loreg_decoder #(parameter p_TARGET_ADDR = 8'h00 ) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //internal clock
    input   wire            i_phi1_NCEN_n, //engative edge clock enable for emulation

    //address to be decoded
    input   wire    [7:0]   i_ADDR,

    input   wire            i_ADDR_LD,
    input   wire            i_DATA_LD,

    output  wire            o_REG_LD
)

reg             loreg_addr_valid;
always @(posedge i_EMUCLK) begin
    if(!i_phi1_NCEN_n) begin
        loreg_addr_valid <= ((p_TARGET_ADDR == i_ADDR) & i_ADDR_LD) | (loreg_addr_valid & ~i_ADDR_LD);
    end
end

assign  o_REG_LD = loreg_addr_valid & i_DATA_LD;

endmodule

//submodule : SR latch
module submdl_srlatch (
    input   wire            i_S,
    input   wire            i_R,
    output  reg             o_Q
)

always @(*) begin
    case({i_S, i_R})
        2'b00: o_Q <= o_Q;
        2'b01: o_Q <= 1'b0;
        2'b10: o_Q <= 1'b1;
        2'b11: o_Q <= 1'b0; //invalid
    endcase
end

endmodule

//submodule : D latch
module submdl_dlatch #(parameter p_WIDTH = 8 ) (
    //master clock
    input   wire                    i_EN,
    input   wire    [p_WIDTH-1:0]   i_D,
    output  reg     [p_WIDTH-1:0]   o_Q
)

always @(*) begin
    if(i_EN) o_Q <= i_D;
    else o_Q <= o_Q;
end

endmodule