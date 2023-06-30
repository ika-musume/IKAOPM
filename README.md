# IKAOPM
An YM2151 Verilog core for FPGA implementation. It was reverse engineered with only Yamaha's datasheet and the [die shot](https://siliconpr0n.org/archive/doku.php?id=mcmaster:yamaha:ym2151) from siliconpr0n. **This core does not reference any existing hard/soft core.** © 2023 Sehyeon Kim(Raki)

<p align=center><img alt="header image" src="./resources/ikamusume_dx7.jpg" height="auto" width="640"></p>

Copyrighted work. Permitted to be used as the header image. Painted by [SEONGSU](https://twitter.com/seongsu_twit).

## Features
* A **cycle-accurate, die shot based, BSD2 lincensed** core.
* FPGA proven.
* Accurately emulates most signals of the actual chip.
* Emulates uneven mixing behavior of the actual chip's accumulator.
* All LSI test bits are implemented.

## Module instantiation
The steps below show how to instantiate the IKAOPM module in verilog:

1. Download this repository or add it as a submodule to your project.
2. You can use the Verilog snippet below to instantiate the module.

```verilog
//Verilog module instantiation example
IKAOPM #(
    .FULLY_SYNCHRONOUS          (1                          )
) u_ikaopm_0 (
    .i_EMUCLK                   (                           ),
    .i_phiM_PCEN_n              (                           ),

    .i_IC_n                     (                           ),

    .o_phi1                     (                           ),

    .i_CS_n                     (                           ),
    .i_RD_n                     (                           ),
    .i_WR_n                     (                           ),
    .i_A0                       (                           ),

    .i_D                        (                           ),
    .o_D                        (                           ),
    .o_D_OE                     (                           ),

    .o_CT1                      (                           ),
    .o_CT2                      (                           ),

    .o_IRQ_n                    (                           ),

    .o_SH1                      (                           ),
    .o_SH2                      (                           ),

    .o_SO                       (                           ),
    .o_EMU_R_PO                 (                           ),
    .o_EMU_L_PO                 (                           )
);
```
3. Attach your signals to the port. The direction and the polarity of the signals are described in the port names. The section below explains what the signals mean.


* `FULLY_SYNCHRONOUS` **1** makes the entire module synchronized(default, recommended). A 2-stage synchronizer is added to all asynchronous control signal inputs. Hence, `i_EMUCLK` at 3.58 MHz, all write operations are delayed by 2 clocks. If **0**, 10 latches are used. There are two unsafe D-latches to emulate an SR-latch for a write request, and an 8-bit D-latch to temporarily store a data bus write value. When using the latches, you must ensure that the enable signals are given the appropriate clock or global attribute. Quartus displays several warnings and treats these signals as GCLK. Because the latch enable signals are considered clocks, the timing analyzer will complain that additional constraints should be added to the bus control signals. I have verified that this asynchronous circuits work on an actual chip, but timing issues may exist.
*  `i_EMUCLK` is your system clock.
*  `i_phiM_PCEN_n` is the clock enable(negative logic) for positive edge of the phiM.
*  `i_IC_n` is the synchronous reset. To flush the every pipelines in the module, IC_n must be kept at zero for at least 64 phiM cycles.
*  `o_D_OE` is the output enable for FPGA's tri-state I/O driver.
*  `o_SO` is the YM3012-type serial audio output.
*  `o_EMU_R_PO` and `o_EMU_L_PO` is the 16-bit signed full range audio outputs.

## FPGA resource usage
* Altera EP4CE6E22C8: 2232LEs, BRAM 6608 bits, fmax=76.48MHz(slow 85C)
