<p align=center><img alt="header image" src="./resources/fmsynth_header.jpg" height="auto" width="640"></p>

Copyrighted image. Permitted to be used as a header. Painted by [SEONGSU](https://twitter.com/seongsu_twit)


# IKA2151
A cycle-accurate, die shot based YM2151 core for FPGA implementation. It was reverse engineered with only Yamaha's datasheet and the [die shot](https://siliconpr0n.org/archive/doku.php?id=mcmaster:yamaha:ym2151) from siliconpr0n. This core does not reference any existing hard/soft core.

## Initial Goals
* Die-shot based, cycle-accurate BSD core. 
* Create an FPGA friendly core without changing the original circuits as much as possible.
* Emulate every signal of the actual chip exactly.
* Emulate uneven mixing behavior of the actual chip's accumulator.
* Implement all test functionality.
* Provide as many comments as possible to make it convenient for anyone who wants to study Yamaha's FM synth.
* Explicit code.
