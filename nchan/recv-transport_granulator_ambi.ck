@import "../classes/granular_class.ck"
@import "../classes/granular_support.ck"
@import "../classes/delayline_class.ck"
@import "../classes/oscHID.ck"
@import "../classes/FakeCursor.ck"

class TransportGran extends Granulator
{
    fun void TransportGran(string file)
    {
        file => filename;
        buffer.read(filename);
        buffer.interp(2); // change buffer interpolation mode for fun
        if(buffer.ready() == 0) <<< "buffer #", "encountered issues" >>>;
        for(int i; i < env.size(); i++)
        {
            // patchbay
            env[i].gain(0.95);
            buffer => env[i] => outlet;
            env[i].setBlackmanHarris();
        }
        buffer.samples() => samples; // give GPS sample count from associated buffer
        gain_target => buffer.gain; // set buffer gain
    }
    0 => int current;
    0 => int play_; // 0 stop 1 play
    0 => int mode; // pause, loop, ping pong
    1.0 => float speed; // negative backwards, positive forward, max of 4 times the original speed
    85.0 => float grainsize; // how long are grains
}

0 => int DELAY_LINES; // using delay lines?
0 => int AMBISONIC; // using ambisonics?
0 => int FAKE_CURSOR; // using fake cursor? 
3 => int GRAINS_PER_CHAN; // nchan sets an amount of grain "objects" positioned in ambisonic space, controlled by the numpad, how many granulators would you like per object?

8 => int nchan; // how many granulators!?!??!
string file;
0 => int device;
int keyArray[nchan];
if(me.args() == 2)
{
    me.arg(0) => file;
    me.arg(1) => Std.atoi => device; // what hid device 
}
else if(me.args() == 1)
{
    me.arg(0) => file;
}
else { cherr <= "please provide input arguments" <= IO.nl(); me.exit(); }
0 => int mode;
int ctrl_state;

FileIO fio;
OscHID inhid(4526); // receive some hid values
DelayLine lines[3]; // 3 delay lines for each granulator
WinFuncEnv entries[nchan]; // env for delays of each granulator
WvOut recorder[9]; // record my performance automatically

TransportGran grain(file)[nchan*GRAINS_PER_CHAN]; // the actual granulators
GranularSupport assistance; // helper to interpret hid
Encode2 grainCode[nchan]; // encoders for granulators
OrderGain2 sum(1.0/nchan); // sum all the encoders down to a single spatial mix

1 => assistance.print; // print out control messages

Gain wet(0.0)[nchan]; // wet gain
Gain dry(0.0)[nchan]; // dry gain
Gain input(0.0)[nchan]; // input stage
Gain atten(0.65)[3]; // attenuate the delays going into the reverb
NRev reverb[nchan]; // reverb
NRev delay_verb[3]; // set and forget reverbs for delay lines
Shred stack[3][nchan];

200::ms => dur env_time;

for(int i; i < grain.size(); i++)
{
    reverb[i%nchan].mix(1.0); // full mix
    entries[i%3].attackTime(env_time); 
    entries[i%3].releaseTime(env_time);
    grain[i] => entries[i%nchan]; // into envelope for delays
    grain[i] => input[i%nchan] => wet[i%nchan] => reverb[i%nchan] => grainCode[i%nchan]; // wet chain
    grain[i] => input[i%nchan] => dry[i%nchan] => grainCode[i%nchan]; // dry chain
    grainCode[i%nchan] => sum; // into bformat sum
}

if(DELAY_LINES)
{
    for(int i; i < lines.size(); i++)
    {
        lines[i].DelayLine(((i+i+1)*178)::ms,(((i+i+1)*178)+4)::ms);
        lines[i].feedback(0.56);
        delay_verb[i].mix(0.025444);
    }
    lines[0] => atten[0] => delay_verb[0] => dac.chan(1); // this is gonna have to be user specific
    lines[1] => atten[1] => delay_verb[1] => dac.chan(4);
    lines[2] => atten[2] => delay_verb[2] => dac.chan(6);
}

if(AMBISONIC) spork ~ setupDecode(sum);
else sum.chan(0) => dac;

beginRecord(sum, recorder);

fun void setupDecode(OrderGain2 b_format)
{
    float speakAngles[9][2];
    for(int i; i < speakAngles.size(); i++)
    {
        i * 360.0/8.0 => speakAngles[(i+1)%9][0];
    }
    SAD2 sad(speakAngles);
    b_format => sad;
    for(int i; i < sad.channels(); i++)
    {
        sad.chan(i) => dac.chan(i);
    }
    while(true)
    {
        1::day => now;
    }
}

fun void beginRecord(OrderGain2 sum, WvOut recorder[])
{
    for(int i; i < sum.channels(); i++)
    {
        recorder[i].wavFilename("../recordings/"+Machine.timeOfDay()+"-"+i+".wav");
        sum.chan(i) => recorder[i] => blackhole;
    }
}

fun void keyOn(WinFuncEnv env_, int which)
{
    env_ => lines[which];
    env_.keyOn();
    while(true)
    {
        env_time => now;
    }
}

fun void keyOff(WinFuncEnv env_, int which)
{
    env_.keyOff();
    env_time => now;
    env_ =< lines[which];
}

fun void clock(TransportGran g)
{
    if(0 == g.samples) me.exit();  
    while(true)
    {
        if(g.play_)
        {
            if(edgeCase(g))
            {
                g.position_target $ int => g.current;
                if(Math.sgn(g.speed) == 1) 1 +=> g.current;
                else if(Math.sgn(g.speed) == -1) 1 -=> g.current;
                Math.clampi(g.current, 0, g.samples) => g.current => g.position_target;
                (1.0/Math.fabs(g.speed))::samp => now;
            }  
        }
        else 1::samp => now;
    }
}

fun int edgeCase(TransportGran m_g)
{
    if(m_g.current == 0)
    {
        if(m_g.mode == 0) return 1;
        else if(m_g.mode == 1) return 1;
        else if(m_g.mode == 2) {-1.0 * m_g.speed => m_g.speed; return 1;}
    }
    else if(m_g.current == m_g.samples)
    {
        if(m_g.mode == 0) {0 => m_g.current; 0 => m_g.play_; return 1;}
        else if(m_g.mode == 1) {0 => m_g.current; 1 => m_g.play_; return 1;}
        else if(m_g.mode == 2) {-1.0 * m_g.speed => m_g.speed; return 1;}
    }
    else if(m_g.current < m_g.samples && m_g.current > 0) return 1;
    return 0;
}

/*

        TODO: numpad key codes are different across laptop, mac, and linux machine (who would've guessed)

            solution: design more robust numpad class which is platform dependent

*/
fun void arrayOnChanger(int key)
{
    if( keyArray.size() == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) key-94 => keyArray[(key-95)];
        else if( key == 94 ) 4 => keyArray[3];
        else if( key == 82 ) 5 => keyArray[4];
        else if ( key == 81 ) 6 => keyArray[5];
        else if( key == 89 ) 7 => keyArray[6];
        else if( key == 92 ) 8 => keyArray[7];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 85 ) [1,0,3,0,5,0,7,0] @=> keyArray;// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) [0,2,0,4,0,6,0,8] @=> keyArray;// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( keyArray.size() == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 92 ) 1 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all at once
        else if( key == 96 ) 2 => keyArray[1];
        else if( key == 94 ) 3 => keyArray[2];
        else if( key == 81 ) 4 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) 1 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all at once
        else if( key == 97 ) 2 => keyArray[1];
        else if( key == 89 ) 3 => keyArray[2];
        else if( key == 82 ) 4 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) (key-91) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all at once
        else if ( key == 94 ) (key-92) => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

fun void arrayOffChanger(int key)
{
    if( keyArray.size() == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) 0 => keyArray[(key-95)];
        else if( key == 94 ) 0 => keyArray[3];
        else if( key == 82 ) 0 => keyArray[4];
        else if ( key == 81 ) 0 => keyArray[5];
        else if( key == 89 ) 0 => keyArray[6];
        else if( key == 92 ) 0 => keyArray[7];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 85 ) keyArray.zero();// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) keyArray.zero();// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( keyArray.size() == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 92 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 96 ) 0 => keyArray[1];
        else if( key == 94 ) 0 => keyArray[2];
        else if( key == 81 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 97 ) 0 => keyArray[1];
        else if( key == 89 ) 0 => keyArray[2];
        else if( key == 82 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if ( key == 94 ) 0 => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

for(int i; i < grain.size(); i++)
{
    grain[i].play();
    grainCode[i%nchan].pos(i*(360.0/nchan), 0); // set each encoder some distance apart
    spork ~ clock(grain[i]);
}

fio.open("../audio/");
fio.dirList() @=> string files[];

while(true)
{ 
    inhid.signal => now;
    if(inhid.lastMsgType == 0)
    {
        if(inhid.lastKeyOn == 70) {cherr <= IO.newline() <= "Exiting" <= IO.newline(); for(int i; i < recorder.size(); i++) {recorder[i].closeFile();} me.exit();} // close up shop
        else if(inhid.lastKeyOn <= 97 && inhid.lastKeyOn >= 81) arrayOnChanger(inhid.lastKeyOn); // change our keypad array
        else if(inhid.lastKeyOn == 224) 1 => ctrl_state; // set control state
        else if(ctrl_state)
        {
            if(inhid.lastKeyOn >= 16 && inhid.lastKeyOn <= 25)
            {
                inhid.lastKeyOn - 16 => int index;
                <<< index >>>;
                for(int i; i < grain.size(); i++)
                {
                    if(keyArray[i%nchan] != 0)
                    {
                        grain[i].fileChange("../audio/"+files[index]); 
                        cherr <= "Grain " <= i <= " swapping to file " <= "../audio/"+files[index] <= IO.nl(); 
                    }
                }
            }
        }
        else if (inhid.lastKeyOn == 75 || inhid.lastKeyOn == 78) // set reverb gain
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    if(inhid.lastKeyOn == 75)
                    {
                        Math.pow(wet[i%nchan].gain()/4.0,2) + wet[i%nchan].gain() + 0.01 => wet[i%nchan].gain;
                        Math.clampf(wet[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => wet[i%nchan].gain;
                        1.0 - wet[i%nchan].gain() => dry[i%nchan].gain;
                        Math.clampf(dry[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => dry[i%nchan].gain;
                        cherr <= "Wet gain: " <= wet[i%nchan].gain() * GRAINS_PER_CHAN <= " Dry gain: " <= dry[i%nchan].gain() <= IO.newline();
                    }
                    else 
                    {
                        wet[i%nchan].gain() - (0.01 + Math.pow(wet[i%nchan].gain()/4.0,2)) => wet[i%nchan].gain;
                        Math.clampf(wet[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => wet[i%nchan].gain;
                        1.0 - wet[i%nchan].gain() => dry[i%nchan].gain;
                        Math.clampf(dry[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => dry[i%nchan].gain;
                        cherr <= "Wet gain: " <= wet[i%nchan].gain() * GRAINS_PER_CHAN <= " Dry gain: " <= dry[i%nchan].gain() <= IO.newline();
                    }
                }
            }          
        }
        else if (inhid.lastKeyOn == 43 || inhid.lastKeyOn == 225) // set input gain
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    if(inhid.lastKeyOn == 43)
                    {
                        Math.pow(input[i%nchan].gain()/4.0,2) + input[i%nchan].gain() + 0.01 => input[i%nchan].gain;
                        Math.clampf(input[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => input[i%nchan].gain;
                        cherr <= "Input gain: " <= input[i%nchan].gain() * GRAINS_PER_CHAN <= IO.newline();
                    }
                    else 
                    {
                        input[i%nchan].gain() - (0.01 + Math.pow(input[i%nchan].gain()/4.0,2)) => input[i%nchan].gain;
                        Math.clampf(input[i%nchan].gain(), 0.0, (1.0/GRAINS_PER_CHAN)) => input[i%nchan].gain;
                        cherr <= "Input gain: " <= input[i%nchan].gain() * GRAINS_PER_CHAN <= IO.newline();
                    }
                }
            }
        }
        else if (inhid.lastKeyOn == 79 || inhid.lastKeyOn == 80) // set transport speed
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    if(inhid.lastKeyOn == 79)
                    {
                        Math.pow(grain[i].speed/4.0,2) + grain[i].speed + 0.01 => grain[i].speed;
                        Math.clampf(grain[i].speed, -4.0, 4.0) => grain[i].speed;
                        cherr <= "Speed: " <= grain[i].speed <= IO.newline();
                    }
                    else
                    {
                        grain[i].speed - (0.01 + Math.pow(grain[i].speed/4.0,2)) => grain[i].speed;
                        Math.clampf(grain[i].speed, -4.0, 4.0) => grain[i].speed;
                        cherr <= "Speed: " <= grain[i].speed <= IO.newline();
                    }
                }
            }
        }
        else if(inhid.lastKeyOn == 45 || inhid.lastKeyOn == 46) // set transport mode
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    1 +=> grain[i].mode;
                    grain[i].mode%3 => grain[i].mode;
                    if(grain[i].mode == 0) cherr <= "no loop";
                    else if(grain[i].mode == 1) cherr <= "loop";
                    else if(grain[i].mode == 2) cherr <= "ping-pong";
                    cherr <= IO.newline();
                }
            }
        }
        else if(inhid.lastKeyOn == 44) // transport pause
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    1 +=> grain[i].play_; grain[i].play_%2 => grain[i].play_;
                    if(grain[i].play_) cherr <= "Play" <= IO.newline();
                    else cherr <= "Paused" <= IO.newline();
                }
            }
        }
        else if(inhid.lastKeyOn == 228 || inhid.lastKeyOn == 230) // increase decrease grain size with alt & ctrl
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    if(inhid.lastKeyOn == 228)
                    {
                        Math.pow(grain[i].grainsize/2.0,4) + grain[i].grainsize + 0.001 => grain[i].grainsize;
                        Math.clampf(grain[i].grainsize, 0.0, 1.0) => grain[i].grainsize;
                        ((Math.pow((grain[i].grainsize - 0.0),4) * (grain[i].grainSizeMax - grain[i].grainSizeMin) + grain[i].grainSizeMin)) => grain[i].grain_duration;
                        cherr <= "Grain size: " <= grain[i].grain_duration <= IO.newline();
                    }
                    else 
                    {
                        grain[i].grainsize - (0.001 + Math.pow(grain[i].grainsize/2.0,4)) => grain[i].grainsize;
                        Math.clampf(grain[i].grainsize, 0.0, 1.0) => grain[i].grainsize;
                        ((Math.pow((grain[i].grainsize - 0.0),4) * (grain[i].grainSizeMax - grain[i].grainSizeMin) + grain[i].grainSizeMin)) => grain[i].grain_duration;
                        cherr <= "Grain size: " <= grain[i].grain_duration <= IO.newline();
                    }
                }
            }
            
        }
        else if(inhid.lastKeyOn <= 69 && inhid.lastKeyOn >= 58 || DELAY_LINES) // open selected grains to a delay line
        {
            if(inhid.lastKeyOn == 58 || inhid.lastKeyOn == 62 || inhid.lastKeyOn == 66) // if entry
            {
                for(int i; i < grain.size(); i++)
                {
                    if(keyArray[i%nchan] != 0)
                    {
                        spork ~ keyOn(entries[i%nchan], (inhid.lastKeyOn-58)/4) @=> stack[(inhid.lastKeyOn-58)/4][i%nchan];
                        cherr <= "Opened grain " <= i <= " to delay line " <= (inhid.lastKeyOn-58)/4 <= IO.newline();
                    }
                }
            }
            
            else if(ctrl_state)
            {
                if(inhid.lastKeyOn == 59 || inhid.lastKeyOn == 63 || inhid.lastKeyOn == 67) // if entry
                {
                    (Math.fabs(lines[(inhid.lastKeyOn-59)/4].feedback()) + Math.pow(0.5*lines[(inhid.lastKeyOn-59)/4].feedback()+0.1, 2)) => float temp;
                    lines[(inhid.lastKeyOn-59)/4].feedback(Math.clampf(temp, 0.0, 1.0));
                    cherr <= "Line " <= (inhid.lastKeyOn-59)/4 <= " increased to " <= lines[(inhid.lastKeyOn-59)/4].feedback() <= IO.newline();
                }
            }

            if(inhid.lastKeyOn == 60 || inhid.lastKeyOn == 64 || inhid.lastKeyOn == 68) // if entry
            {
                lines[(inhid.lastKeyOn-60)/4].feedback() * -1.0 => float temp;
                lines[(inhid.lastKeyOn-60)/4].feedback(Math.clampf(temp, -1.0, 1.0));
                cherr <= "Line " <= (inhid.lastKeyOn-59)/4 <= " flipped to " <= lines[(inhid.lastKeyOn-59)/4].feedback() <= IO.newline();
            }
        }
        else // if it can fit in the assistance class it'll be here
        {
            for(int i; i < grain.size(); i++)
            {
                if(keyArray[i%nchan] != 0)
                {
                    assistance.key(inhid.lastKeyOn, grain[i]);
                }
            }
        }
    }
    else if (inhid.lastMsgType == 1) 
    {
        if( inhid.lastKeyOff <= 97 && inhid.lastKeyOff >= 81 ) arrayOffChanger(inhid.lastKeyOff);
        else if(inhid.lastKeyOff == 58 || inhid.lastKeyOff == 62 || inhid.lastKeyOff == 66 || DELAY_LINES) // if you let go of a delay line send, this is where it is disconnected
        {
            for(int i; i < nchan; i++)
            {
                if(!stack[(inhid.lastKeyOff-58)/4][i].done())
                {
                    cherr <= "exited" <= IO.newline();
                    stack[(inhid.lastKeyOff-58)/4][i].exit();
                    cherr <= "Closing grain " <= i <= " from line " <= (inhid.lastKeyOff-58)/4 <= IO.newline();
                    spork ~ keyOff(entries[i], (inhid.lastKeyOff-58)/4);
                }
            }
        }
        else if(!ctrl_state || DELAY_LINES) // if you decreased a delay line's gain 
        {
            if(inhid.lastKeyOff == 59 || inhid.lastKeyOff == 63 || inhid.lastKeyOff == 67) // if entry
            {
                (Math.fabs(lines[(inhid.lastKeyOff-59)/4].feedback()) - Math.pow(0.15*lines[(inhid.lastKeyOff-59)/4].feedback()+0.1, 2)) => float temp;
                lines[(inhid.lastKeyOff-59)/4].feedback(Math.clampf(temp, 0.0, 1.0));
                cherr <= "Line " <= (inhid.lastKeyOff-59)/4 <= " decreased to " <= lines[(inhid.lastKeyOff-59)/4].feedback() <= IO.newline();
            }
        }
        else if(inhid.lastKeyOff == 224) // set ctrl state
        {
            0 => ctrl_state;
        }
    }
    else if(inhid.lastMsgType == 2)
    {
        float position[2];
        inhid.lastMouseX => position[0];
        inhid.lastMouseY => position[1];
        for(int i; i < grain.size(); i++)
        {
            if(keyArray[i%nchan] != 0)
            {
                assistance.mouse(position, grain[i]);
            }
        }
    }
    else if(inhid.lastMsgType == 3)
    {
        float position[2];
        inhid.lastMouseX => position[0];
        inhid.lastMouseY => position[1];
        for(int i; i < grain.size(); i++)
        {
            if(keyArray[i%nchan] != 0)
            {
                assistance.mouse(position, grain[i]);
            }
        }
    }
}
