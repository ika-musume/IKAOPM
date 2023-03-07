module IKA2151_eg
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
    input   wire            i_CYCLE_00_16,
    input   wire            i_CYCLE_01_TO_16,

    //register data
    input   wire            i_KON, //key on
    input   wire    [1:0]   i_KS,  //key scale
    input   wire    [4:0]   i_AR,  //attack rate
    input   wire    [4:0]   i_D1R, //first decay rate
    input   wire    [4:0]   i_D2R, //second decay rate
    input   wire    [3:0]   i_RR,  //release rate
    input   wire    [3:0]   i_D1L, //first decay level
    input   wire    [3:0]   i_TL,  //total level
    input   wire    [7:0]   i_LFA, //amplitude modulation from LFO
    input   wire    [7:0]   i_TEST, //test register

    //input data
    input   wire    [4:0]   i_EG_PDELTA_SHIFT_AMOUNT,

    //output data
    output  wire    [9:0]   o_OP_ENV_LEVEL, //envelope level
    output  wire            o_NOISE_ENV_LEVEL, //envelope level(for noise module)
    output  wire            o_REG_ENV_CH8_C2 //noise envelope level
);



///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;
wire            mrst_n = i_MRST_n;



///////////////////////////////////////////////////////////
//////  Cycle number
////

//additional cycle bits
reg             cycle_01_17;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cycle_01_17 <= i_CYCLE_00_16;
    end
end



///////////////////////////////////////////////////////////
//////  Third sample flag
////

reg     [1:0]   samplecntr;
wire            third_sample = samplecntr[1] | i_TEST[0];

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!i_MRST_n) begin
            samplecntr <= 2'd0;
        end
        else begin
            if(i_CYCLE_31) begin
                if(samplecntr == 2'd2) samplecntr <= 2'd0;
                else samplecntr <= samplecntr + 2'd1;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  Attenuation rate generator
////

/*
    YM2151 uses serial counter and shift register to get the rate below

    timecntr = X_0000_00000_00000 = 0
    timecntr = X_1000_00000_00000 = 14
    timecntr = X_X100_00000_00000 = 13
    timecntr = X_XX10_00000_00000 = 12
    ...
    timecntr = X_XXXX_XXXXX_XXX10 = 2
    timecntr = X_XXXX_XXXXX_XXXX1 = 1

    I used parallel 4-bit counter instead of the shift register to save
    FPGA resources.
*/

reg             mrst_z;
reg     [1:0]   timecntr_adder;
reg     [14:0]  timecntr_sr; //this sr can hold 15-bit integer

reg             onebit_det, mrst_dlyd;
reg     [3:0]   conseczerobitcntr;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //adder
        timecntr_adder <= mrst_n ? (((third_sample & i_CYCLE_01_TO_16) & (cycle_01_17 | timecntr_adder[1])) + timecntr_sr[0]) :
                                   2'd0;

        //sr
        timecntr_sr[14] <= timecntr_adder[0];
        timecntr_sr[13:0] <= timecntr_sr[14:1];

        //consecutive zero bits counter
        mrst_z <= ~mrst_n; //delay master reset, to synchronize the reset timing with timecntr_adder register

        if(mrst_z | cycle_01_17) begin
            onebit_det <= 1'b0;
            conseczerobitcntr <= 4'd1; //start from 1
        end
        else begin
            if(!onebit_det) begin
                if(timecntr_adder[0]) begin
                    onebit_det <= 1'b1;
                    conseczerobitcntr <= conseczerobitcntr;
                end
                else begin
                    onebit_det <= 1'b0;
                    conseczerobitcntr <= (conseczerobitcntr == 4'd14) ? 4'd0 : conseczerobitcntr + 4'd1; //max 14
                end
            end
        end
    end
end

reg     [1:0]   envcntr;
reg     [3:0]   attenrate;

always @(posedge i_EMUCLK) begin
    if(!phi1pcen_n) begin //positive edge!!!!
        if(third_sample & ~i_CYCLE_01_TO_16 & cycle_01_17) begin
            envcntr <= timecntr_sr[2:1];

            attenrate <= conseczerobitcntr;
        end
    end
end



///////////////////////////////////////////////////////////
//////  Previous KON shift register
////

/*
                                             previous KON data
                                     |----------(32 stages)---------|
    i_KON(cyc5) -> (cyc6 - cyc9) -+> (cyc10 - cyc37) -> (cyc6 - cyc9) -> -o|¯¯¯¯\
                                  |                                        | AND )--- positive edge detector
                                  +------------------------------------> --|____/
*/

//These shift registers holds KON values from previous 32 cycles
reg     [3:0]   cyc6r_cyc9r_kon_current_dlyline; //outer process delay compensation(4 cycles)
reg     [27:0]  cyc10r_cyc37r_kon_previous; //previous KON values
reg     [3:0]   cyc6r_cyc9r_kon_previous; //delayed concurrently with the current kon delay line

wire            cyc9r_kon_current = cyc6r_cyc9r_kon_current_dlyline[3]; //current kon value
wire            cyc9r_kon_detected = ~cyc6r_cyc9r_kon_previous[3] & cyc9r_kon_current; //prev=0, curr=1, new kon detected

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc6r_cyc9r_kon_current_dlyline[0] <= i_KON;
        cyc6r_cyc9r_kon_current_dlyline[3:1] <= cyc6r_cyc9r_kon_current_dlyline[2:0];

        cyc10r_cyc41r_kon_previous[0] <= cyc6r_cyc9r_kon_current_dlyline[3];
        cyc10r_cyc41r_kon_previous[27:1] <= cyc10r_cyc41r_kon_previous[26:0];

        cyc6r_cyc9r_kon_previous[0] <= cyc10r_cyc37r_kon_previous[27];
        cyc6r_cyc9r_kon_previous[3:1] <= cyc6r_cyc9r_kon_previous[2:0];
    end
end



///////////////////////////////////////////////////////////
//////  Envelope state machine
////

/*
    Envelope state machine holds the states of 32 operators

                  (state update)
                        |
                        V
    (cyc6 - cyc9) -> (cyc10 - cyc37) (loop to cyc 6, total 32 stages) 
*/

localparam ATTACK = 2'd0;
localparam FIRST_DECAY = 2'd1;
localparam SECOND_DECAY = 2'd2;
localparam RELEASE = 2'd3;

//
//  combinational part
//

//flags and prev state for FSM
wire            cyc10c_first_decay_end;
wire            cyc10c_env_level_max;
wire            cyc10c_env_level_min;


//
//  register part
//

//total 32 stages to store states of all operators
reg     [1:0]   cyc6r_cyc9r_envstate_previous[0:3]; //4 stages
reg     [1:0]   cyc10r_envstate_current; //1 stage
reg     [1:0]   cyc11r_cyc37r_envstate_previous[0:26]; //27 stages

wire    [1:0]   cyc10c_envstate_previous = cyc6r_cyc9r_envstate_previous[3];

//sr4
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        //if kon detected, make previous envstate ATTACK
        cyc6r_cyc9r_envstate_previous[0] <= (~cyc11r_cyc37r_kon_previous[26] & i_KON) ? ATTACK : cyc11r_cyc37r_envstate_previous[26];
        cyc6r_cyc9r_envstate_previous[1] <= cyc6r_cyc9r_envstate_previous[0];
        cyc6r_cyc9r_envstate_previous[2] <= cyc6r_cyc9r_envstate_previous[1];
        cyc6r_cyc9r_envstate_previous[3] <= cyc6r_cyc9r_envstate_previous[2];
    end
end

//state machine
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(!mrst_n) begin
            cyc10r_envstate_current <= RELEASE;
        end
        else begin
            if(cyc9r_kon_detected) begin
                cyc10r_envstate_current <= ATTACK; //start attack
            end
            else begin
                if(cyc9r_kon_current) begin
                    case(cyc10c_envstate_previous)
                        //current state 0: attack
                        2'd0: begin
                            if(cyc10c_env_level_max) begin
                                cyc10r_envstate_current <= FIRST_DECAY; //start first decay
                            end
                            else begin
                                cyc10r_envstate_current <= ATTACK; //hold state
                            end
                        end

                        //current state 1: first decay
                        2'd1: begin
                            if(cyc10c_env_level_min) begin
                                cyc10r_envstate_current <= RELEASE; //start release
                            end
                            else begin
                                if(cyc10c_first_decay_end) begin
                                    cyc10r_envstate_current <= SECOND_DECAY; //start second decay
                                end
                                else begin
                                    cyc10r_envstate_current <= FIRST_DECAY; //hold state
                                end
                            end
                        end 

                        //current state 2: second decay
                        2'd2: begin
                            if(cyc10c_env_level_min) begin
                                cyc10r_envstate_current <= RELEASE; //start release
                            end
                            else begin
                                cyc10r_envstate_current <= SECOND_DECAY; //hold state
                            end
                        end

                        //current state 3: release
                        2'd3: begin
                            cyc10r_envstate_current <= RELEASE; //hold state
                        end
                    endcase                    
                end
                else begin
                    cyc10r_envstate_current <= RELEASE; //key off -> start release
                end
            end
        end
    end
end

//sr27 first stage
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc11r_cyc37r_envstate_previous[0] <= cyc10r_envstate_current;
    end
end

//sr27 the other stages
genvar stage;
generate
for(stage = 0; stage < 26; stage = stage + 1) begin : envstate_sr27
    always @(posedge i_EMUCLK) begin
        if(!phi1ncen_n) begin
            cyc11r_cyc37r_envstate_previous[stage + 1] <= cyc11r_cyc37r_envstate_previous[stage];
        end
    end
end
endgenerate



///////////////////////////////////////////////////////////
//////  Data pipeline Cycle 8: EG param/KS latch 
////


//
//  combinational part
//

reg     [4:0]   cyc8c_egparam;
always @(*) begin
    if(!mrst_n) begin
        cyc8c_egparam <= 5'd32;
    end
    else begin
        case(cyc6r_cyc9r_envstate_previous[1])
            ATTACK:         cyc8c_egparam <= i_AR;
            FIRST_DECAY:    cyc8c_egparam <= i_D1R;
            SECOND_DECAY:   cyc8c_egparam <= i_D2R;
            RELEASE:        cyc8c_egparam <= {i_RR, 1'b0};
        endcase
    end
end


//
//  register part
//

reg     [4:0]   cyc8r_egparam;
reg             cyc8r_egparam_zero;
reg     [4:0]   cyc8r_keyscale;
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc8r_egparam <= cyc8c_egparam;
        cyc8r_egparam_zero <= cyc8c_egparam == 5'd0;

        case(i_KS)
            2'd0: cyc8r_keyscale <= (cyc8c_egparam == 5'd0) ? 5'd0 : {3'b000, i_EG_PDELTA_SHIFT_AMOUNT[4:3]};
            2'd1: cyc8r_keyscale <= {2'b00, i_EG_PDELTA_SHIFT_AMOUNT[4:2]};
            2'd2: cyc8r_keyscale <= {1'b0, i_EG_PDELTA_SHIFT_AMOUNT[4:1]};
            2'd3: cyc8r_keyscale <= i_EG_PDELTA_SHIFT_AMOUNT;
        endcase
    end
end



///////////////////////////////////////////////////////////
//////  Data pipeline Cycle 9: apply KS
////

//
//  combinational part
//

wire    [6:0]   cyc9c_egparam_scaled_adder = {cyc8r_egparam, 1'b0} + {1'b0, cyc8r_keyscale};


//
//  register part
//

reg             cyc9r_egparam_zero;
reg     [5:0]   cyc9r_egparam_scaled;

reg             cyc9r_third_sample;
reg     [1:0]   cyc9r_envcntr;
reg     [3:0]   cyc9r_attenrate;

always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc9r_egparam_zero <= cyc8r_egparam_zero;
        cyc9r_egparam_scaled <= cyc9c_egparam_scaled_adder[6] ? 6'd0 : cyc9c_egparam_scaled_adder[5:0]; //saturation

        cyc9r_third_sample <= third_sample;
        cyc9r_envcntr <= envcntr;
        cyc9r_attenrate <= attenrate;
    end
end



///////////////////////////////////////////////////////////
//////  Data pipeline Cycle 10: make envelope weight
////

/*
    See "Attenuation rate generator" section. Attenrate value is determined
    from the counter value like below:

    timecntr = X_0000_00000_00000 = 0
    timecntr = X_1000_00000_00000 = 14
    timecntr = X_X100_00000_00000 = 13
    timecntr = X_XX10_00000_00000 = 12
    ...
    timecntr = X_XXXX_XXXXX_XXX10 = 2
    timecntr = X_XXXX_XXXXX_XXXX1 = 1

    An attenuation rate of 1 will occur most often, 14 or 0 will occur 
    least often. Attenuation rate * 4 (2-bit left shift) is added to 
    the "egparam_scaled" to get the final value.

    Therefore, the quadrupled values that should be added to 
    "egparam_scaled" are:

    least often <----                      ----> most often
    0, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4


    If the "egparam_scaled" is NOT 11XXXX, there are three conditions 
    that can change the envelope value:

    1. egparam_scaled      != from 6'd48 to 6'd63
       egparam_scaled      != 6'd0
       egparam_rateapplied == from 6'd48 to 6'd51

    2. egparam_scaled      != from 6'd48 to 6'd63
       egparam_rateapplied == 6'd54 or 6'd55

    3. egparam_scaled      != from 6'd48 to 6'd63
       egparam_rateapplied == 6'd57 or 6'd59

    These three conditions can be compressed like this:
        egparam_scaled      != from 6'd48 to 6'd63
        egparam_scaled      != 6'd0
        egparam_rateapplied == 48, 49, 50, 51, 54, 55, 57, 59


    Therefore, if "egparam scaled" is 1, this value can change the envelope
    level when the rate is "48"
    if "egparam_scaled" is 2, this value can change the envelope level when
    the rate is "48" or "52"
    if 3, the value-changable rate is "48" or "52" or "59"
    if 4, the value-changable rate is "44"

    The rate "44" appears more often than the sum of the frequency of
    occurrence of "48", "52", "59". So, egparam_scaled = 4 can change the
    envelope level often, than 1, 2, 3. If the envelope level changes frequently,
    the difference between the envelope level of the current sample and the next 
    sample becomes larger.
*/

//
//  combinational part
//

reg             cyc10c_envdeltaweight_intensity; //0 = weak, 1 = strong
always @(*) begin
    case({cyc9r_egparam_scaled[1:0], cyc9r_envcntr})
        4'b00_00: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b00_01: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b00_10: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b00_11: cyc10c_envdeltaweight_intensity <= 1'b0;

        4'b01_00: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b01_01: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b01_10: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b01_11: cyc10c_envdeltaweight_intensity <= 1'b0;

        4'b10_00: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b10_01: cyc10c_envdeltaweight_intensity <= 1'b0;
        4'b10_10: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b10_11: cyc10c_envdeltaweight_intensity <= 1'b0;

        4'b11_00: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b11_01: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b11_10: cyc10c_envdeltaweight_intensity <= 1'b1;
        4'b11_11: cyc10c_envdeltaweight_intensity <= 1'b0;
    endcase
end

wire    [5:0]   cyc10c_egparam_rateapplied = cyc9r_egparam_scaled + {attenrate, 2'b00}; //discard carry


//
//  register part
//

reg     [3:0]   cyc10r_envdeltaweight; //lv4, lv3, lv2, lv1
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        if(cyc9r_third_sample) begin
            if     (cyc9r_egparam_scaled[5:2] == 4'b1111) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b1000 : 4'b1000;
            else if(cyc9r_egparam_scaled[5:2] == 4'b1110) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b1000 : 4'b0100;
            else if(cyc9r_egparam_scaled[5:2] == 4'b1101) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b0100 : 4'b0010;
            else if(cyc9r_egparam_scaled[5:2] == 4'b1100) cyc10r_envdeltaweight <= cyc10c_envdeltaweight_intensity ? 4'b0010 : 4'b0001;
            else begin
                if(cyc9r_egparam_zero) begin
                    cyc10r_envdeltaweight <= 4'b0000;
                end
                else begin
                    if(cyc9r_egparam_scaled != 6'd0 & 
                       |{cyc10c_egparam_rateapplied == 6'd59, cyc10c_egparam_rateapplied == 6'd57,
                         cyc10c_egparam_rateapplied == 6'd55, cyc10c_egparam_rateapplied == 6'd54,
                         cyc10c_egparam_rateapplied == 6'd51, cyc10c_egparam_rateapplied == 6'd50,
                         cyc10c_egparam_rateapplied == 6'd49, cyc10c_egparam_rateapplied == 6'd48}) begin
                        
                        cyc10r_envdeltaweight <= 4'b0001;
                    end
                    else begin
                        cyc10r_envdeltaweight <= 4'b0000;
                    end
                end
            end
        end
        else begin
            cyc10r_envdeltaweight <= 4'b0000;
        end
    end
end



///////////////////////////////////////////////////////////
//////  Data pipeline Cycle 9: apply KS
////





reg             cyc10r_env_underflow;

//flag
always @(posedge i_EMUCLK) begin
    if(!phi1ncen_n) begin
        cyc10r_env_underflow <= (cyc10c_envstate_previous != ATTACK) & ~cyc9r_kon_detected & cyc10c_env_level_min;
    end
end







endmodule