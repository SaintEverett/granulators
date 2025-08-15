@import "granular_class.ck"
@import "granular_support.ck"

Granulator grain("screaming_05.08.2025_excerpt.wav");
GranularSupport assistance;
1 => assistance.print;
Gain wet(0.0);
Gain dry(0.0);
Gain input(0.0);
JCRev reverb;
reverb.mix(1.0);

grain => input => wet => reverb => dac;
grain => input => dry => dac;

Hid key;
HidMsg msg;
int transport;
0 => int device;
0 => int play;
1.0 => float speed;
0.5 => float grainsize;

if(me.args()) me.arg(0) => Std.atoi => device;
if(!key.openKeyboard(device)) {cherr <= "Could not open specified HID device"; me.exit();}

fun void clock(int start, int stop, Granulator g)
{
    if(start == stop) me.exit();
    int current;
    stop => int end;
    while(true)
    {
        if(current < stop)
        {
            if(speed) 1 +=> current;
            else 1 -=> current;
            Math.clampi(current, 0, end) => current => g.position_target;
            // cherr <= speed <= IO.newline();
            if(speed != 0.0 && play) 1*(1.0/Math.fabs(speed))::samp => now;
            else 10::ms => now;
        }
        else 10::ms => now;
    }
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
                cherr <= "nuh uh uh" <= IO.newline();
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