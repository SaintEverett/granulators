@import "granular_class.ck"
@import "granular_support.ck"

0 => int device;
if(me.args()) me.arg(0) => Std.atoi => device; // what hid device

Granulator grain("hit.wav");
GranularSupport assistance; // helper to interpret hid
1 => assistance.print; // print out control messages
Gain wet(0.0); // wet gain
Gain dry(0.0); // dry gain
Gain input(0.0); // input stage
JCRev reverb; // reverb
reverb.mix(1.0); // full mix

grain => input => wet => reverb => dac; // wet chain
grain => input => dry => dac; // dry chain

Hid key; // hid
HidMsg msg; // hid decrypt
int transport; // marker for position in file

0 => int current;
0 => int play; // 0 stop 1 play
0 => int mode; // pause, loop, ping pong
1.0 => float speed; // negative backwards, positive forward, max of 4 times the original speed
85.0 => float grainsize; // how long are grains
grainsize => grain.grain_duration;

if(!key.openKeyboard(device)) {cherr <= "Could not open specified HID device"; me.exit();}

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
        if(mode == 0) {0 => current; 0 => play; return 1;}
        else if(mode == 1) {0 => current; 1 => play; return 1;}
        else if(mode == 2) {-1.0 * speed => speed; return 1;}
    }
    else if(current < m_stop && current > 0) return 1;
    return 0;
}

grain.play();
spork ~ clock(0, grain.samples, grain);

while(true)
{
    key => now;
    while(key.recv(msg))
    {
        if(msg.isButtonDown())
        {
            //cherr <= msg.key <= " " <= IO.newline();
            if(msg.key == 41) {cherr <= IO.newline() <= "Exiting" <= IO.newline(); me.exit();}
            else if (msg.key == 82 || msg.key == 81)
            {
                if(msg.key == 82)
                {
                    Math.pow(wet.gain()/4.0,2) + wet.gain() + 0.01 => wet.gain;
                    Math.clampf(wet.gain(), 0.0, 1.0) => wet.gain;
                    1.0 - wet.gain() => dry.gain;
                    Math.clampf(dry.gain(), 0.0, 1.0) => dry.gain;
                    cherr <= "Wet gain: " <= wet.gain() <= " Dry gain: " <= dry.gain() <= IO.newline();
                }
                else 
                {
                    wet.gain() - (0.01 + Math.pow(wet.gain()/4.0,2)) => wet.gain;
                    Math.clampf(wet.gain(), 0.0, 1.0) => wet.gain;
                    1.0 - wet.gain() => dry.gain;
                    Math.clampf(dry.gain(), 0.0, 1.0) => dry.gain;
                    cherr <= "Wet gain: " <= wet.gain() <= " Dry gain: " <= dry.gain() <= IO.newline();
                }
            }
            else if (msg.key == 43 || msg.key == 225)
            {
                if(msg.key == 43)
                {
                    Math.pow(input.gain()/4.0,2) + input.gain() + 0.01 => input.gain;
                    Math.clampf(input.gain(), 0.0, 1.0) => input.gain;
                    cherr <= "Input gain: " <= input.gain() <= IO.newline();
                }
                else 
                {
                    input.gain() - (0.01 + Math.pow(input.gain()/4.0,2)) => input.gain;
                    Math.clampf(input.gain(), 0.0, 1.0) => input.gain;
                    cherr <= "Input gain: " <= input.gain() <= IO.newline();
                }
            }
            else if (msg.key == 79 || msg.key == 80)
            {
                if(msg.key == 79)
                {
                    Math.pow(speed/4.0,2) + speed + 0.01 => speed;
                    Math.clampf(speed, -4.0, 4.0) => speed;
                    cherr <= "Speed: " <= speed <= IO.newline();
                }
                else
                {
                    speed - (0.01 + Math.pow(speed/4.0,2)) => speed;
                    Math.clampf(speed, -4.0, 4.0) => speed;
                    cherr <= "Speed: " <= speed <= IO.newline();
                }
            }
            else if(msg.key == 45 || msg.key == 46)
            {
                1 +=> mode;
                mode%3 => mode;
                if(mode == 0) cherr <= "no loop";
                else if(mode == 1) cherr <= "loop";
                else if(mode == 2) cherr <= "ping-pong";
                cherr <= IO.newline();
            }
            else if(msg.key == 44) 
            {
                1 +=> play; play%2 => play;
                if(play) cherr <= "Play" <= IO.newline();
                else cherr <= "Paused" <= IO.newline();
            }
            else if(msg.key == 228 || msg.key == 230)
            {
                if(msg.key == 228)
                {
                    Math.pow(grainsize/2.0,4) + grainsize + 0.001 => grainsize;
                    Math.clampf(grainsize, 0.0, 1.0) => grainsize;
                    ((Math.pow((grainsize - 0.0),4) * (grain.grainSizeMax - grain.grainSizeMin) + grain.grainSizeMin)) => grain.grain_duration;
                    cherr <= "Grain size: " <= grain.grain_duration <= IO.newline();
                }
                else 
                {
                    grainsize - (0.001 + Math.pow(grainsize/2.0,4)) => grainsize;
                    Math.clampf(grainsize, 0.0, 1.0) => grainsize;
                    ((Math.pow((grainsize - 0.0),4) * (grain.grainSizeMax - grain.grainSizeMin) + grain.grainSizeMin)) => grain.grain_duration;
                    cherr <= "Grain size: " <= grain.grain_duration <= IO.newline();
                }
                
            }
            else assistance.key(msg.key, grain);
        }
    }
}