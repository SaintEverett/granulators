@import "../classes/granular_class.ck"
@import "../classes/granular_support.ck"
@import "../classes/delayline_class.ck"

class transportGran extends Granulator
{
    fun void transportGran(string file)
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

4 => int nchan; // how many granulators!?!??!
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
transportGran grain(file)[nchan]; // the actual granulators
DelayLine lines[3]; // 3 delay lines for each granulator
WinFuncEnv entries[nchan]; // env for delays of each granulator
WvOut recorder[9]; // record my performance automatically
GranularSupport assistance; // helper to interpret hid
Encode2 grainCode[nchan]; // encoders for granulators
OrderGain2 sum(1.0/nchan); // sum all the encoders down to a single spatial mix

1 => assistance.print; // print out control messages

Gain wet(0.0)[nchan]; // wet gain
Gain dry(0.0)[nchan]; // dry gain
Gain input(0.0)[nchan]; // input stage
NRev reverb[nchan]; // reverb
NRev delay_verb[3]; // set and forget reverbs for delay lines
Gain atten(0.65)[3]; // attenuate the delays going into the reverb
Shred stack[3][nchan];

200::ms => dur env_time;

for(int i; i < nchan; i++)
{
    reverb[i].mix(1.0); // full mix
    entries[i].attackTime(env_time); 
    entries[i].releaseTime(env_time);
    grain[i] => entries[i]; // into envelope for delays
    grain[i] => input[i] => wet[i] => reverb[i] => grainCode[i]; // wet chain
    grain[i] => input[i] => dry[i] => grainCode[i]; // dry chain
    grainCode[i] => sum; // into bformat sum
}

for(int i; i < lines.size(); i++)
{
    lines[i].DelayLine(((i+i+1)*178)::ms,(((i+i+1)*178)+4)::ms);
    lines[i].feedback(0.56);
    delay_verb[i].mix(0.025444);
}

lines[0] => atten[0] => delay_verb[0] => dac.chan(1); // this is gonna have to be user specific
lines[1] => atten[1] => delay_verb[1] => dac.chan(4);
lines[2] => atten[2] => delay_verb[2] => dac.chan(6);

beginRecord(sum, recorder);
spork ~ setupDecode(sum);

Hid key; // hid
HidMsg msg; // hid decrypt

if(!key.openKeyboard(device)) {cherr <= "Could not open specified key device"; me.exit();}

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

fun void clock(transportGran g)
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

fun int edgeCase(transportGran m_g)
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

fun void arrayOnChanger(int key)
{
    if( keyArray.size() == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) (key-94) => keyArray[(key-95)];
        else if( key == 92 ) 8 => keyArray[7];
        else if( key == 94 ) 4 => keyArray[3];
        else if( key <= 91 && key >= 89 ) (-1 * key) + 96 => keyArray[(-1 * key) + 95];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 85 ) [1,0,3,0,5,0,7,0] @=> keyArray;// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) [0,2,0,4,0,6,0,8] @=> keyArray;// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( keyArray.size() == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) (key-95) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all at once
        else if( key == 94 ) (key-92) => keyArray[1];
        else if( key == 90 ) (key-87) => keyArray[2];
        else if( key == 92 ) (key-88) => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) (key-94) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all at once
        else if( key == 97 ) (key-95) => keyArray[1];
        else if( key == 91 ) (key-98) => keyArray[2];
        else if( key == 89 ) (key-85) => keyArray[3];
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
        else if( key == 92 ) 0 => keyArray[7];
        else if( key == 94 ) 0 => keyArray[3];
        else if( key <= 91 && key >= 89 ) 0 => keyArray[(-1 * key) + 95];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 85 ) keyArray.zero();// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) keyArray.zero();// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( keyArray.size() == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 94 ) 0 => keyArray[1];
        else if( key == 90 ) 0 => keyArray[2];
        else if( key == 92 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( keyArray.size() == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all at once
        else if( key == 97 ) 0 => keyArray[1];
        else if( key == 91 ) 0 => keyArray[2];
        else if( key == 89 ) 0 => keyArray[3];
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

fun void miceWatch()
{
    Hid mos;
    HidMsg mosmsg; 
    if(!mos.openMouse(0)) {cherr <= "Could not open specified mouse device"; me.exit();}
    float position[2];

    while(true)
    {
        mos => now;
        while(mos.recv(mosmsg))
        {
            mosmsg.scaledCursorX => position[0];
            mosmsg.scaledCursorY => position[1];
            for(int i; i < keyArray.size(); i++)
            {
                if(keyArray[i] != 0)
                {
                    assistance.mouse(position, grain[i]);
                }
            }
        }
    }
}

spork ~ miceWatch();

for(int i; i < nchan; i++)
{
    grain[i].play();
    grainCode[i].pos(i*90.0, 0); // set each encoder 90 degrees apart
    spork ~ clock(grain[i]);
}

fio.open("../audio/");
fio.dirList() @=> string files[];

while(true)
{
    key => now;
    while(key.recv(msg))
    {
        if(msg.isButtonDown())
        {
            //cherr <= msg.key <= " " <= IO.newline();
            if(msg.key == 41) {cherr <= IO.newline() <= "Exiting" <= IO.newline(); for(int i; i < recorder.size(); i++) {recorder[i].closeFile();} me.exit();} // close up shop
            else if( msg.key <= 97 && msg.key >= 84 ) spork ~ arrayOnChanger(msg.key); // change our keypad array
            else if(msg.key == 224) 1 => ctrl_state; // set control state
            else if(ctrl_state)
            {
                if(msg.key >= 16 && msg.key <= 25)
                {
                    msg.key - 16 => int index;
                    <<< index >>>;
                    for(int i; i < keyArray.size(); i++)
                    {
                        if(keyArray[i] != 0)
                        {
                            grain[i].fileChange("../audio/"+files[index]); 
                            cherr <= "Grain " <= i <= " swapping to file " <= "../audio/"+files[index] <= IO.nl(); 
                        }
                    }
                }
            }
            else if (msg.key == 82 || msg.key == 81) // set reverb gain
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        if(msg.key == 82)
                        {
                            Math.pow(wet[i].gain()/4.0,2) + wet[i].gain() + 0.01 => wet[i].gain;
                            Math.clampf(wet[i].gain(), 0.0, 1.0) => wet[i].gain;
                            1.0 - wet[i].gain() => dry[i].gain;
                            Math.clampf(dry[i].gain(), 0.0, 1.0) => dry[i].gain;
                            cherr <= "Wet gain: " <= wet[i].gain() <= " Dry gain: " <= dry[i].gain() <= IO.newline();
                        }
                        else 
                        {
                            wet[i].gain() - (0.01 + Math.pow(wet[i].gain()/4.0,2)) => wet[i].gain;
                            Math.clampf(wet[i].gain(), 0.0, 1.0) => wet[i].gain;
                            1.0 - wet[i].gain() => dry[i].gain;
                            Math.clampf(dry[i].gain(), 0.0, 1.0) => dry[i].gain;
                            cherr <= "Wet gain: " <= wet[i].gain() <= " Dry gain: " <= dry[i].gain() <= IO.newline();
                        }
                    }
                }          
            }
            else if (msg.key == 43 || msg.key == 225) // set input gain
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        if(msg.key == 43)
                        {
                            Math.pow(input[i].gain()/4.0,2) + input[i].gain() + 0.01 => input[i].gain;
                            Math.clampf(input[i].gain(), 0.0, 1.0) => input[i].gain;
                            cherr <= "Input gain: " <= input[i].gain() <= IO.newline();
                        }
                        else 
                        {
                            input[i].gain() - (0.01 + Math.pow(input[i].gain()/4.0,2)) => input[i].gain;
                            Math.clampf(input[i].gain(), 0.0, 1.0) => input[i].gain;
                            cherr <= "Input gain: " <= input[i].gain() <= IO.newline();
                        }
                    }
                }
            }
            else if (msg.key == 79 || msg.key == 80) // set transport speed
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        if(msg.key == 79)
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
            else if(msg.key == 45 || msg.key == 46) // set transport mode
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
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
            else if(msg.key == 44) // transport pause
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        1 +=> grain[i].play_; grain[i].play_%2 => grain[i].play_;
                        if(grain[i].play_) cherr <= "Play" <= IO.newline();
                        else cherr <= "Paused" <= IO.newline();
                    }
                }
            }
            else if(msg.key == 228 || msg.key == 230) // increase decrease grain size with alt & ctrl
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        if(msg.key == 228)
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
            else if(msg.key <= 69 && msg.key >= 58) // open selected grains to a delay line
            {
                if(msg.key == 58 || msg.key == 62 || msg.key == 66) // if entry
                {
                    for(int i; i < nchan; i++)
                    {
                        if(keyArray[i] != 0)
                        {
                            spork ~ keyOn(entries[i], (msg.key-58)/4) @=> stack[(msg.key-58)/4][i];
                            cherr <= "Opened grain " <= i <= " to delay line " <= (msg.key-58)/4 <= IO.newline();
                        }
                    }
                }
                
                else if(ctrl_state)
                {
                    if(msg.key == 59 || msg.key == 63 || msg.key == 67) // if entry
                    {
                        (Math.fabs(lines[(msg.key-59)/4].feedback()) + Math.pow(0.5*lines[(msg.key-59)/4].feedback()+0.1, 2)) => float temp;
                        lines[(msg.key-59)/4].feedback(Math.clampf(temp, 0.0, 1.0));
                        cherr <= "Line " <= (msg.key-59)/4 <= " increased to " <= lines[(msg.key-59)/4].feedback() <= IO.newline();
                    }
                }

                if(msg.key == 60 || msg.key == 64 || msg.key == 68) // if entry
                {
                    lines[(msg.key-60)/4].feedback() * -1.0 => float temp;
                    lines[(msg.key-60)/4].feedback(Math.clampf(temp, -1.0, 1.0));
                    cherr <= "Line " <= (msg.key-59)/4 <= " flipped to " <= lines[(msg.key-59)/4].feedback() <= IO.newline();
                }
            }
            else // if it can fit in the assistance class it'll be here
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        assistance.key(msg.key, grain[i]);
                    }
                }
            }
        }
        if (msg.isButtonUp())
        {
            if( msg.key <= 97 && msg.key >= 84 ) spork ~ arrayOffChanger(msg.key);
            else if(msg.key == 58 || msg.key == 62 || msg.key == 66) // if you let go of a delay line send, this is where it is disconnected
            {
                for(int i; i < nchan; i++)
                {
                    if(!stack[(msg.key-58)/4][i].done())
                    {
                        cherr <= "exited" <= IO.newline();
                        stack[(msg.key-58)/4][i].exit();
                        cherr <= "Closing grain " <= i <= " from line " <= (msg.key-58)/4 <= IO.newline();
                        spork ~ keyOff(entries[i], (msg.key-58)/4);
                    }
                }
            }
            else if(!ctrl_state) // if you decreased a delay line's gain 
            {
                if(msg.key == 59 || msg.key == 63 || msg.key == 67) // if entry
                {
                    (Math.fabs(lines[(msg.key-59)/4].feedback()) - Math.pow(0.15*lines[(msg.key-59)/4].feedback()+0.1, 2)) => float temp;
                    lines[(msg.key-59)/4].feedback(Math.clampf(temp, 0.0, 1.0));
                    cherr <= "Line " <= (msg.key-59)/4 <= " decreased to " <= lines[(msg.key-59)/4].feedback() <= IO.newline();
                }
            }
            else if(msg.key == 224) // set ctrl state
            {
                0 => ctrl_state;
                //cherr <= ctrl_state <= IO.newline();
            }
        }
    }
}
