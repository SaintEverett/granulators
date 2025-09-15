@import "granular_class.ck"
@import "granular_support.ck"
@import "delayline_class.ck"

class transportGran extends Granulator
{
    fun void transportGran(string file)
    {
        file => filename;
        buffer.read(filename);
        buffer.interp(2); // change buffer interpolation mode for fun
        if(buffer.ready() == 0) <<< "buffer #", id, "encountered issues" >>>;
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

dac.channels() => int nchan;
0 => int device;
int keyArray[nchan];
if(me.args()) me.arg(0) => Std.atoi => device; // what hid device
0 => int mode;
int ctrl_state;

transportGran grain("source.wav")[nchan];
DelayLine lines[3]; // 3 delay lines for each granulator
WinFuncEnv entries[nchan]; // env for delays of each granulator
GranularSupport assistance; // helper to interpret hid
1 => assistance.print; // print out control messages
Gain wet(0.0)[nchan]; // wet gain
Gain dry(0.0)[nchan]; // dry gain
Gain input(0.0)[nchan]; // input stage
JCRev reverb[nchan]; // reverb
JCRev delay_verb[3]; // set and forget reverbs for delay lines
Gain atten(0.35)[3];
Shred stack[3][nchan];
200::ms => dur env_time;

for(int i; i < nchan; i++)
{
    reverb[i].mix(1.0); // full mix
    entries[i].attackTime(env_time);
    entries[i].releaseTime(env_time);
    grain[i] => entries[i];
    grain[i] => input[i] => wet[i] => reverb[i] => dac.chan(i); // wet chain
    grain[i] => input[i] => dry[i] => dac.chan(i); // dry chain
}

for(int i; i < lines.size(); i++)
{
    lines[i].DelayLine(((i+i+1)*178)::ms,(((i+i+1)*178)+4)::ms);
    lines[i].feedback(0.56);
    delay_verb[i].mix(0.025444);
}

lines[0] => atten[0] => delay_verb[0] => dac.chan(0);
lines[2] => atten[2] => delay_verb[2] => dac.chan(1);

Hid key; // hid
HidMsg msg; // hid decrypt

if(!key.openKeyboard(device)) {cherr <= "Could not open specified HID device"; me.exit();}

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


for(int i; i < nchan; i++)
{
    grain[i].play();
    spork ~ clock(grain[i]);
}

while(true)
{
    key => now;
    while(key.recv(msg))
    {
        if(msg.isButtonDown())
        {
            //cherr <= msg.key <= " " <= IO.newline();
            if(msg.key == 41) {cherr <= IO.newline() <= "Exiting" <= IO.newline(); me.exit();}
            else if( msg.key <= 97 && msg.key >= 84 ) spork ~ arrayOnChanger(msg.key);
            else if(msg.key == 224)
            {
                1 => ctrl_state;
                //cherr <= ctrl_state <= IO.newline();
            }
            else if (msg.key == 82 || msg.key == 81)
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
            else if (msg.key == 43 || msg.key == 225)
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
            else if (msg.key == 79 || msg.key == 80)
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
            else if(msg.key == 45 || msg.key == 46)
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
            else if(msg.key == 44) 
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
            else if(msg.key == 75 || msg.key == 78)
            {
                for(int i; i < nchan; i++)
                {
                    if(keyArray[i] != 0)
                    {
                        if(msg.key == 75)
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
            else if(msg.key <= 69 && msg.key >= 58)
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
            else 
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
            else if(msg.key == 58 || msg.key == 62 || msg.key == 66) // if entry
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
            else if(!ctrl_state)
            {
                if(msg.key == 59 || msg.key == 63 || msg.key == 67) // if entry
                {
                    (Math.fabs(lines[(msg.key-59)/4].feedback()) - Math.pow(0.15*lines[(msg.key-59)/4].feedback()+0.1, 2)) => float temp;
                    lines[(msg.key-59)/4].feedback(Math.clampf(temp, 0.0, 1.0));
                    cherr <= "Line " <= (msg.key-59)/4 <= " decreased to " <= lines[(msg.key-59)/4].feedback() <= IO.newline();
                }
            }
            else if(msg.key == 224)
            {
                0 => ctrl_state;
                //cherr <= ctrl_state <= IO.newline();
            }
        }
    }
}