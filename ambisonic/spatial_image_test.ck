//--------------------------SETUP-------------------------------
string name;
if(me.args()) me.arg(0) => name;
else me.exit();
5 => int M_ORDER; // what are order are we in
1 => int N_OBJECTS; // how many sound sources
(M_ORDER+1)*(M_ORDER+1) => int N_CHANNELS; // how many channels
["W","Y","Z","X","V","T","R","S","U","Q","O","M","K","L","N","P"] @=> string letters[]; // symbols

Encode5 enc; // ENCODE
AmbiMath calc; // CALCULATOR
WvOut record[N_CHANNELS]; // record
Gain input; // abstracted input "fader"
input.gain(0.75);
input => enc;
for(int i; i < enc.chans(); i++)
{
    enc.chan(i) => record[i] => blackhole;
    record[i].wavFilename(name+"_"+i);
}
//--------------------------------------------------------------

SinOsc osc;
float coordinates[N_CHANNELS];
calc.all(0.0,0.0,coordinates,M_ORDER);
enc.coeff(coordinates);
osc => input;
0.5 => osc.gain;
second / samp => float srate; // get the sample rate

for(-1 => float i; i < 1; i+0.001 => i)
{
    Math.pow(100,i-1)*srate => osc.freq;
    cherr <= osc.freq() <= IO.newline();
    10::ms => now;
}

for(int i; i < record.size(); i++)
{
    record[i].closeFile();
}
