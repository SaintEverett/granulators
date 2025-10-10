@import "../classes/granular_class.ck"

int num;
if(!me.args()) me.exit();
else Std.atoi(me.arg(0)) => num;
"cymbalhit4" => string file;
Granulator grain(file+"_"+num+".wav");
Gain input(1.0); // input stage
JCRev reverb; // reverb
WvOut record;
0 => int stop;
reverb.mix(0.125); // full mix
record.wavFilename(file+"_"+(num+1)+".wav");

grain => input => reverb => dac; // wet chain
reverb => record => blackhole;

Hid key; // hid
HidMsg msg; // hid decrypt
int transport; // marker for position in file

0 => int current;
1 => int play; // 0 stop 1 play
0 => int mode; // pause, loop, ping pong
0.75 => float speed; // negative backwards, positive forward, max of 4 times the original speed
38.5 => float grainsize; // how long are grains
1.0 => float pitch;

pitch => grain.pitch;
pitch => grain.pitch_target;
grainsize => grain.grain_duration;

fun void clock(int start, int stop, Granulator g)
{
    if(start == stop) me.exit();
    
    while(true)
    {
        if(play)
        {
            if(edgeCase(start, stop, g))
            {
                if(Math.sgn(speed) == 1) 1 +=> current;
                else if(Math.sgn(speed) == -1) 1 -=> current;
                Math.clampi(current, 0, stop) => current => g.position_target;
                (1.0/Math.fabs(speed))::samp => now;
            }  
        }
        else 1::samp => now;
    }
}


fun int edgeCase(int m_start, int m_stop, Granulator m_g)
{
    if(current == 0)
    {
        if(mode == 0) return 1;
        else if(mode == 1) return 1;
        else if(mode == 2) {-1.0 * speed => speed; return 1;}
    }
    else if(current == m_stop)
    {
        if(mode == 0) {m_stop => current; 1 => stop; return 1;}
        else if(mode == 1) {0 => current; 1 => play; return 1;}
        else if(mode == 2) {-1.0 * speed => speed; return 1;}
    }
    else if(current < m_stop && current > 0) return 1;
    return 0;
}

record.record();
grain.play();
spork ~ clock(0, grain.samples, grain);

while(true)
{
    if(stop)
    {
        record.closeFile();
        me.exit();
    }
    else 10::ms => now;
}