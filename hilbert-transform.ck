///////////////////////////////////////////////////
// hilbert.ck - v1.0 - Douglas Nunn, April 2018
//
// IIR "Hilbert transform" - porting [hilbert~] from Pure Data to ChucK
//            ("the name is abused here according to computer music tradition")
//            (I Can't Believe It's Not The Analytic Signal)
//
// This is a pair of 4th-order all-pass filters whose outputs somehow manage to be about
// 90 degrees out of phase from each other. Both have different phases from the original.
// Adapted from a 4X patch by Emmanuel Favreau, circa 1982.
//
// Note that the signs of a1 and a2 are flipped compared to the pd parameters.
// This is because ChucK's BiQuad is implemented differently to pd's [biquad~].
// References
//   https://ccrma.stanford.edu/~jos/filters/Direct_Form_II.html
//   https://en.wikipedia.org/wiki/Digital_biquad_filter#Direct_form_2
//   https://github.com/olilarkin/OL-OWLPatches/blob/master/IIRHilbert.dsp - FAUST code


class HilbertOne extends Chugraph
{
  inlet => BiQuad out1filter1 => BiQuad out1filter2 => outlet;
  // [biquad~ -0.02569 0.260502 -0.260502 0.02569 1]
   0.02569  => out1filter1.a1;
  -0.260502 => out1filter1.a2;
  -0.260502 => out1filter1.b0;
   0.02569  => out1filter1.b1;
   1.0      => out1filter1.b2;
  // [biquad~ 1.8685 -0.870686 0.870686 -1.8685 1]
  -1.8685   => out1filter2.a1;
   0.870686 => out1filter2.a2;
   0.870686 => out1filter2.b0;
  -1.8685   => out1filter2.b1;
   1.0      => out1filter2.b2;
}

class HilbertTwo extends Chugraph
{
  inlet => BiQuad out2filter1 => BiQuad out2filter2 => outlet;
  // [biquad~ 1.94632 -0.94657 0.94657 -1.94632 1]
  -1.94632  => out2filter1.a1;
   0.94657  => out2filter1.a2;
   0.94657  => out2filter1.b0;
  -1.94632  => out2filter1.b1;
   1.0      => out2filter1.b2;
  // [biquad~ 0.83774 -0.06338 0.06338 -0.83774 1]
  -0.83774  => out2filter2.a1;
   0.06338  => out2filter2.a2;
   0.06338  => out2filter2.b0;
  -0.83774  => out2filter2.b1;
   1.0      => out2filter2.b2;
}


// testing
SinOsc ef;
Std.mtof(63) => ef.freq;
0.5          => ef.gain;

ef  => HilbertOne h1 => dac.chan(0);
ef  => HilbertTwo h2 => dac.chan(1);

dac => WvOut2 w => blackhole;
me.dir()+"testhilbert.wav" => w.wavFilename;
null @=> w;

1982::ms => now;
/**/


