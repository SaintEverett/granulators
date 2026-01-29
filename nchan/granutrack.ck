//-----------------------------------------------------------------------------
// name: gametra.ck
// desc: gametrak boilerplate code;
//       prints 6 axes of the gametrak tethers + foot pedal button;
//       a helpful starting point for mapping gametrak
//
// author: Ge Wang (ge@ccrma.stanford.edu)
// date: summer 2014
//-----------------------------------------------------------------------------

@import "../classes/granular_class.ck"

Granulator grain("audio/granulmaterialhires.wav")[12];

Gain sum(1.0/grain.size())[2];
Gain feedbacks(0.99)[8];
Gain stringScale(1.0/10.0)[2];
Delay strings[8];

for(int i; i < strings.size(); i++)
{
    strings[i].set((i+32)::ms, (1+i+32)::ms);
    strings[i] => feedbacks[i] => strings[i] => stringScale[i%2];
}

for(int i; i < grain.size(); i++)
{
    Math.random2(0, grain[0].samples) => grain[i].position_target;
    150.0 => grain[i].rand_grain_duration;
    grain[i].play();
    grain[i] => sum[i%2];
}

stringScale[0] => dac.chan(0);
stringScale[1] => dac.chan(1);

sum[0] => dac.chan(0);
sum[1] => dac.chan(1);

// z axis deadzone
0 => float DEADZONE;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
HidMsg msg;

// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();

// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// gametrack
GameTrak gt;

// spork control
spork ~ gametrak();
spork ~ game2Grain(gt, grain);

// main loop
while( true )
{
    // print 6 continuous axes -- XYZ values for left and right
    //<<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2],
                 //gt.axis[3],gt.axis[4],gt.axis[5] >>>;

    // also can map gametrak input to audio parameters around here
    // note: gt.lastAxis[0]...gt.lastAxis[5] hold the previous XYZ values

    // advance time
    100::ms => now;
}

fun void game2Grain(GameTrak t, Granulator g[])
{
    while(true)
    {
        for(int i; i < g.size(); i++)
        {
            //Std.scalef(t.lastAxis[2], 0.0, 1.0, 0.5, 4.0) => g[i].pitch_target;
            //<<< t.lastAxis[2], grain[i].pitch >>>;
            Std.scalef(t.lastAxis[5] - t.lastAxis[2], -1.0, 1.0, g[0].samples/12, g[0].samples) => g[i].position_target;
            <<< "position: ", t.lastAxis[5] - t.lastAxis[2], g[i].position_target >>>;
            Std.scalef(t.lastAxis[3] - t.lastAxis[0], -2.0, 0.0, 2.5, 60.0) => g[i].grain_duration;
            <<< "grain dur: ", t.lastAxis[3] - t.lastAxis[0], g[i].grain_duration >>>;
            Std.scalef(t.lastAxis[1], -1.0, 1.0, 0.0, 5000) => g[i].rand_grain_duration;
            <<< "random grain dur: ", t.lastAxis[1], g[i].position_target >>>;
        }
        15::ms => now;
    }
}

// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                for(int i; i < grain.size(); i++)
                {
                    1 => grain[i].spacer;
                    grain[i] => strings[i%8];
                    //2+Math.random2f(-2,2) +=> grain[i].pitch_target;
                }
                <<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                for(int i; i < grain.size(); i++)
                {
                    0 => grain[i].spacer;
                    grain[i] =< strings[i%8];
                    //1 => grain[i].pitch_target;
                }
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}
