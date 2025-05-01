/*
    name: 'recv_ambigrani.ck'
    Author: Everett M. Carpenter, written Spring 2025
    Credits: Rob Hamilton, Ge Wang, Baek San Chang and Kyle Spratt -- The sound source used in this script is a modification of Spratt's 'granular.ck'
    
    #----- [HOW TO USE] -----#
    This is the recieving end of an OSC communication pair. Simply launch this script along with it's partner 'send_ambigrani.ck'
    This script will recieve control data from the other end of the OSC pipe. Just ensure they are sending and recieving on the same address.
    To see the arguments required for this script, attempt to run it in MiniAudicle or the cmd line. 
    #------------------------#

    This script acts as an audio source and ambisonic processor (encoder and decoder). The sound source is a granulator controlled by the keyboard and mouse. 
    Controls for the granulator are as follows...

        "`1234567890" row -- This row is for where the "play head" of the granulator is located in the file. "`" is the beginning of the file, where the further to the right being later in the file.
        "QWERTYUIOP" row -- This row controls the randomization of grain position in the audio file, with the magnitude of randomization increasing the further you go towards "P".
        "ASDFGHJKL" row -- This row controls the pitch of the grains, with "A" being 0.000083, "S" being 0.25, then 0.5, 0.75,1,2,4,6,8,16 respectively.
        "ZXCVBNM" row -- This row is the randomization of grain pitch, following the same route as the QWERTY row, with randomization increasing as you move to the right.
        "-=" -- "=" steps forward in the audio file, where "-" steps backwards.
        "[]" -- incremental control of randomized position.
        ";'" -- incremental control of the pitch. 
        ",." -- incremental control of randomized pitch.
        "ENTER" and right "SHIFT" -- ENTER increases randomized grain length, and SHIFT reduces it.
        "TAB" and left "SHIFT" -- TAB increases reverb mix, and SHIFT reduces it.
        left "ALT" -- activates a "spacer" which places randomized gaps in between grains (works well with long grain sizes)
        "↑↓←→" (arrow keys) -- control the direction & height velocities of the ring of granulators, where left arrow increases, right decreases (negative velocities supported) and the same with up and down (up positive, down negative).
        "Cursor X-Axis" -- the x-axis placement of the cursor controls the grain size. (Only active when a granulator is selected)
        "Cursor Y-Axis" -- the y-axis placement controls the volume of the granulator. (Only active when a granulator is selected)

    When launching this script, you will specify whether you want 2 or 4 granulators (the second argument appropriately titled "howMany"). 
    The granulators are then mapped to the numpad, assigning the first to "7" and the following granulators to "8", "9", and "6", counter clockwise around "5". If you choose 2 granulators, they will map to "7" and "8".
    If you would like to edit a parameter of a specific granulator, hold down it's num pad key and the keyboard will act as a control on that granulator. You can edit more than only granulator at a time. 
    If you would like to edit ALL granulators, hold down "5". The "*" key edits "7" & "9" (diagonal to "5") and "+" edits "8" and "6" (perpendicular to "5").

    If you wish to modify this script, each variable, class, UGen, Event or function is labelled, so hot rodding this script should be easy. 

    Direct any questions to carpee2 @ rpi.edu

*/

// Declare GPS
class GPS
{
    0.0 => float grain_length; // can be changed to acheive a more varying asynchronous envelope for each grain duration
    int id; // unique id to GPS
    string filename; // buffer file
    // parameters of the function 
    72 => float grain_duration; // initial value to prevent starting at 0
    5.0 => float rand_grain_duration; 
    1.0 => float pitch;
    0.0 => float rand_pitch;
    int samples;
    int spacer;
    1 => int position; // this is in samples
    0 => int rand_position; // so is this
    // targets
    float position_target; // where the position slew wants to go
    1.0 => float pitch_target; // where the pitch slew wants to go
    0.0 => float gain_target; // where the volume slew wants to go
    0.0 => float temp_gain;
    0.0 => float pause;
    // ambisonics
    float coefficients[9]; // x,y,z,w,r,s,t,u,v
    float revmix;
    float target_revmix;
    float angles[2];
    // functions
    fun void setId( int y )
    {
        y => id;
    }
}

// instantiation
800.0 => float grainSizeMax; // used as max grain size value in cursor scaling
25.0 => float grainSizeMin; // used as min grain size value in cursor scaling
int nChans; // number of dac channels
int nGrans; // number of desired grains (specified in command line)
string filename; // audio file used as source
string hostname; // address to recieve OSC messages
int port; // port to recieve OSC messages
1 => int print; // print granulator changes or not
0 => int device; // where are you getting HID messages
Hid hi; // keyboard 
HidMsg msg; // keyboard reader
OscIn mailBox[7]; // recieves OSC messages
OscMsg letterOpener; // OSC reader
0 => int whichGPS; // initialize whichGPS variable
int keyArray[8]; // stores the current granulator you want to edit
["X","Y","Z","W","R","S","T","U","V"] @=> string coordinateMarkers[]; // just used to print messages for assurance
Event ready; // confirms everything is ready
dac.channels() => nChans; // remember how many dac channels

if( dac.channels() < 8 )
{
    cherr <= "you don't have enough output channels!" <= IO.newline();
    me.exit();
}

// check the command line
if( !me.args() || me.args() == 2 ) // take arguments
{
    cherr <= "Input required, format is [audiofile]:[howmany]:[hostname]:[port]" <= IO.newline()
          <= "If no port specified, default to 6449";
    me.exit();
}
else if( me.args() == 3 )
{
    me.arg(0) => filename;
    me.arg(1) => Std.atoi => nGrans;
    me.arg(2) => hostname;
    6449 => port;
}
else if( me.args() == 4 )
{
    me.arg(0) => filename;
    me.arg(1) => Std.atoi => nGrans;
    me.arg(2) => hostname;
    me.arg(3) => Std.atoi => port;
}

// GPS nGrans
GPS myGPS[nGrans]; // parameter storage for granulators
SndBuf buffs[nGrans]; // sound buffers to power granulator
Envelope env[nGrans]; // envelope to window grains
Gain fader(0.5)[nGrans]; // master fader for better volume control
Gain wet[nGrans];
Gain dry[nGrans];
JCRev rev[nGrans]; // reverb
HPF highpass[nGrans]; // hipass for reverb
Event revWait[nGrans]; // for interpolation of volume to rev
for( int i; i < rev.size(); i++ )
{
    65.0 => highpass[i].freq; // set hipass
    0.1 => highpass[i].Q; // set Q
    1.0 => rev[i].mix; // reverb mix
}

for( auto x : buffs ) // turn off buffer interpolation (fun sounding)
{
    x.interp(0); // buffer interpolation
}

// encoder and decoder declarations
Gain encoder[nGrans][9]; // creates x amount of 9 segment rows
Gain decoder[8][9]; // big decode block, 8 rows of 9, each row is a coordinate (x,y,z,w,r,s,t,u,v)
Gain speakSum(0.8)[8]; // this is the sum of the decoding into a single stream for the corresponding speaker

// state you're address
for( auto x : mailBox ) // set your port for OSC
{
    port => x.port; // set port
}

// all the OSC addresses
mailBox[0].addAddress("/keypresses/down");
mailBox[1].addAddress("/keypresses/up");
mailBox[2].addAddress("/trackpad/x");
mailBox[3].addAddress("/trackpad/y");
mailBox[4].addAddress("/sound/location/coordinates");
mailBox[5].addAddress("/sound/location/angles");
mailBox[6].addAddress("/speakers/coefficients");

// back and forth between GPS and buffs
for( int i; i < nGrans; i++ ) // assign GPS id, set, exchange and read filename, give sample count and set buffer gain
{
    i+1 => myGPS[i].id; // id assignment
    filename => myGPS[i].filename; // filename assignment
    buffs[i].read(myGPS[i].filename); // have buffer read file
    buffs[i].samples() => myGPS[i].samples; // give GPS sample count from associated buffer
    myGPS[i].gain_target => buffs[i].gain; // set buffer gain
    <<< "GPS #", myGPS[i].id, "has", myGPS[i].samples, " samples" >>>; // announcement
}

fun void ramp_reverb(int revId)
{
    revId => int id; // id for GPS
    0.005 => float slew;
    while( true )
    {
        if( myGPS[id].revmix != myGPS[id].target_revmix )
        {
            ( (myGPS[id].target_revmix - myGPS[id].revmix) * slew + myGPS[id].revmix ) => myGPS[id].revmix;
            myGPS[id].revmix => wet[id].gain;
            0.8 - wet[id].gain() => dry[id].gain;
            5::ms => now;
        }
        else { revWait[id] => now; }
    }
}

// position interpolation
fun void ramp_position( int posId )
{
    posId => int id; // each ramp (position,pitch and volume) has an id, so that is edits the same GPS every time
    // compute rough threshold
    2.0 * (myGPS[id].samples) $ float / 10.0 => float thresh;
    // choose slew
    0.005 => float slew;

    // go
    while( true )
    {
        // really far away from target?
        if( Std.fabs(myGPS[id].position - myGPS[id].position_target) > myGPS[id].samples / 5 )
        {
            1.0 => slew;
        }
        else
        {
            0.005 => slew;
        }
        // slew towards position
        ( (myGPS[id].position_target - myGPS[id].position) * slew + myGPS[id].position ) $ int => myGPS[id].position;
        // wait time
        1::ms => now;
    }
}

// pitch interpolation
fun void ramp_pitch( int pitId )
{
    pitId => int id; // each ramp (position,pitch and volume) has an id, so that is edits the same GPS every time
    // the slew
    0.01 => float slew;
    // go
    while( true )
    {
        // slew
        ((myGPS[id].pitch_target - myGPS[id].pitch) * slew + myGPS[id].pitch) => myGPS[id].pitch;
        // wait
        5::ms => now;
    }
}

// volume interpolation
fun void ramp_gain( int gainId )
{ 
    gainId => int id; // each ramp (position,pitch and volume) has an id, so that is edits the same GPS every time
    // the slew
    0.05 => float slew;
    // go
    while( true )
    {
        // slew
        ( (myGPS[id].gain_target - buffs[id].gain()) * slew + buffs[id].gain() ) => buffs[id].gain;
        // wait
        10::ms => now;
    }
}

// grain function
fun void grain( int grainId )
{ 
    grainId => int id; // each grain has an id, so that is edits the same GPS every time
    0.0 => myGPS[id].grain_length; // can be changed to acheive a more varying asynchronous envelope for each grain duration
    myGPS[id].grain_duration*0.5::ms => env[id].duration;
    if( buffs[id].ready() == 0 ) <<< "buffer #", id, "encountered issues" >>>;
    // patchbay
    buffs[id] => env[id] => wet[id] => highpass[id] => rev[id] => fader[id]; 
    buffs[id] => env[id] => dry[id] => fader[id];
    // go!
    while( true )
    {   
        // compute grain length
        Std.rand2f( Math.max(1.0,myGPS[id].grain_duration - myGPS[id].rand_grain_duration),
        myGPS[id].grain_duration + myGPS[id].rand_grain_duration) => myGPS[id].grain_length;
        // compute grain duration for envelope
        myGPS[id].grain_length * 0.5::ms => env[id].duration;
        // set buffer playback rate
        Std.rand2f( Math.max(0.0625, myGPS[id].pitch - myGPS[id].rand_pitch), myGPS[id].pitch + myGPS[id].rand_pitch ) => buffs[id].rate;
        // set buffer position
        Std.rand2( Math.max(1, myGPS[id].position - myGPS[id].rand_position ) $ int,
        Math.min( myGPS[id].samples, myGPS[id].position + myGPS[id].rand_position ) $ int ) => buffs[id].pos;
        env[id].keyOn(); // enable envelope
        myGPS[id].grain_length*0.5::ms => now; // wait for rise
        env[id].keyOff(); // close envelope
        myGPS[id].grain_length*0.5::ms => now; // wait
        myGPS[id].pause::ms => now; // until next grain
        if( myGPS[id].spacer%2 ) Std.rand2f(200,1000)::ms => now; // if the spacer is enabled for this GPS, it will cause random pauses between grains, making indeterminate spaces
    }
}

fun void gpsEditor(int key) // huge interface layer that edits all selected GPS in keyArray[] according to what keyboard USB key code is recieved
{
    // position setting via numerics
    if( key < 40 && key > 29 )
    {
        for( int i; i < nGrans; i++ ) // run through array, if a keyArray entry is non-zero, perform that parameter change to the/those GPS(s).
        {                             
            if( keyArray[i] != 0 )
            {
                (key - 29)*myGPS[i].samples/(10) => myGPS[i].position_target;
                <<< "position: ", myGPS[i].position_target >>>;
            }
        }
    }
    // enable spacer via alt key
    else if( key == 226 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].spacer + 1 => myGPS[i].spacer;
                <<< "spacer: ", myGPS[i].spacer%2 >>>;
            }
        }
    }
    // go to beginning of the file via `
    else if( key == 53 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0 => myGPS[i].position_target;
                <<< "position: ", myGPS[i].position_target >>>;
            }
        }
    }
    // advance via = 
    else if( key == 46 )
    {
        for( int i; i < nGrans; i++ )
        {
            Math.min(myGPS[i].samples, myGPS[i].position + 11000) => myGPS[i].position_target;
            if( print ) <<< "position: ", myGPS[i].position_target >>>;
            /*
            if( keyArray[i] != 0 )
            {
                Math.min`(myGPS[i].samples, myGPS[i].position + 11000) => myGPS[i].position_target;
                if( print ) <<< "position: ", myGPS[i].position_target >>>;
            }
            */
        }
    }
    // and step back via -
    else if( key == 45 )
    {
        for( int i; i < nGrans; i++ )
        {
            Math.max(1, myGPS[i].position - 11000) => myGPS[i].position_target;
            if( print ) <<< "position: ", myGPS[i].position_target >>>;
            /*
            if( keyArray[i] != 0 )
            {
                Math.max(1, myGPS[i].position - 11000) => myGPS[i].position_target;
                if( print ) <<< "position: ", myGPS[i].position_target >>>;
            }
            */
        }
    }
    // random grain duration
    else if( key == 229 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                // shift to decrease random grain duration
                Math.max(0.01, ( myGPS[i].rand_grain_duration / 1.3 )) => myGPS[i].rand_grain_duration;
                if( myGPS[i].rand_grain_duration <= 0.01 ) 0.01 => myGPS[i].rand_grain_duration;
                if( print ) <<< "- randomness grain length: ", myGPS[i].rand_grain_duration >>>;
            }
        }
    }
    else if( key == 40 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                if( myGPS[i].rand_grain_duration <= 0.01 ) 0.01 => myGPS[i].rand_grain_duration;
                Math.min( 2000.0, (myGPS[i].rand_grain_duration * 1.3 )) => myGPS[i].rand_grain_duration;
                if( print ) <<< "+ randomness grain length: ", myGPS[i].rand_grain_duration >>>;
            }
        }
    }
    // reduce rand position via [
    else if( key == 47 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                (Math.max(0.0, myGPS[i].rand_position - 500.0)) $ int => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    // increase rand position via ]
    else if( key == 48 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                (Math.min(myGPS[i].samples, myGPS[i].rand_position + 500)) $ int => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    // set random position via qwertyuiop
    else if( key == 20 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 26 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                200 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 8 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                2000 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 21 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                20000 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 23 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                40000 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 28 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                80000 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 24 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                100000 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 12 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].samples * 7 / 9 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 18 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].samples * 8 / 9 => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    else if( key == 19 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].samples => myGPS[i].rand_position;
                if( print ) <<< "randomness of position: ", myGPS[i].rand_position >>>;
            }
        }
    }
    // pitch of granulator via asdfghjkl;' 
    else if( key == 10 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                1.0 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 9 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0.75 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 7 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0.5 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 22 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0.25 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 4 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0.000083 => myGPS[i].pitch_target; // 4 samples per second at 48000
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 11 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                2.0 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 13 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                4.0 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 14 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                8.0 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 15 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                16.0 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 51 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].pitch - .05 / 12 => myGPS[i].pitch_target => myGPS[i].pitch;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 52 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].pitch + .05 / 12 => myGPS[i].pitch_target => myGPS[i].pitch;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    // rand pitch via < and >
    else if( key == 54 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].rand_pitch - 0.025 => myGPS[i].rand_pitch;
                if( print ) <<< "rando of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 55 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].rand_pitch + 0.025 => myGPS[i].rand_pitch;
                if( print ) <<< "rando of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    // random pitch via zxcvbnm
    else if( key == 29 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                0.0 => myGPS[i].rand_pitch;      
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 27 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                1.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 6 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                2.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 25 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                3.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 5 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                4.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 17 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                5.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 16 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                6.0 => myGPS[i].rand_pitch;
                if( print ) <<< "randomness of pitch: ", myGPS[i].rand_pitch >>>;
            }
        }
    }
    else if( key == 43 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                Math.clampf(((myGPS[i].target_revmix/5 + 0.02) + myGPS[i].target_revmix),0.0,1.0) => myGPS[i].target_revmix;
                revWait[i].signal();
                if( print ) <<< "+ reverb mix: ", myGPS[i].target_revmix >>>;
            }
        }
    }
    else if( key == 225 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                Math.clampf((-1*(myGPS[i].target_revmix/5 + 0.02) + myGPS[i].target_revmix),0.0,1.0) => myGPS[i].target_revmix;
                revWait[i].signal();
                if( print ) <<< "- reverb mix: ", myGPS[i].target_revmix >>>;
            }
        }
    }
}

fun void keyOnListen() // listens to the stream of keypresses down
{
    int key;
    while( true )
    {
        // wait for mail
        mailBox[0] => now;

        // did you get mail?
        while( mailBox[0].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getInt(i) => key;
                spork ~ gpsEditor(key);
                if( key <= 97 && key >= 84 ) spork ~ arrayOnChanger(key);
                // print them out
                // cherr <= key <= " on" <= IO.newline();
            }
        }
    }
}

fun void keyOffListen() // listens to the stream of keylifts up
{
    int key;
    while( true )
    {
        // wait for mail
        mailBox[1] => now;

        // did you get mail?
        while( mailBox[1].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getInt(i) => key;
                if( key <= 97 && key >= 84 ) spork ~ arrayOffChanger(key);
                // print them out
                // cherr <= key <= " off" <= IO.newline();
            }
        }
    }
}

fun void mouseXListen() // listens to the stream of trackpad x position
{
    float mouseX;
    while( true )
    {
        // wait for mail
        mailBox[2] => now;

        // did you get mail?
        while( mailBox[2].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => mouseX;
                // print them out
                // cherr <= mouseX <= " mouse x" <= IO.newline();
            }
            for( int i; i < nGrans; i++ )
            {
                if( keyArray[i] != 0 ) // scaled_value = ((input_value - in_min) / (in_max - in_min)) * (out_max - out_min) + out_min
                {
                    ((Math.pow((mouseX - 0.0),4) * (grainSizeMax - grainSizeMin) + grainSizeMin)) => myGPS[i].grain_duration;
                    // cherr <= myGPS[i].grain_duration <= " grain duration" <= IO.newline();
                }
            }
        }
    }
}

fun void mouseYListen() // listens to the stream of trackpad y position
{
    float mouseY;
    while( true )
    {
        // wait for mail
        mailBox[3] => now;

        // did you get mail?
        while( mailBox[3].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => mouseY;
                // print them out
                // cherr <= mouseY <= " mouse y" <= IO.newline();
            }
            for( int i; i < nGrans; i++ )
            {
                if( keyArray[i] != 0 )
                {
                    mouseY => myGPS[i].gain_target;
                    // ((mouseY - 0.0) * (0.0 - 0.5) + 0.5) => myGPS[i].target_revmix;
                    // cherr <= myGPS[i].target_revmix <= IO.newline();
                    // cherr <= myGPS[i].grain_duration <= " grain duration" <= IO.newline();
                }
            }
        }
    }
}

fun void arrayOnChanger(int key) // changes the storage array from what keypress is recieved
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

fun void arrayOffChanger(int key) // adjusts based on what keylift is recieved
{
    if( key <= 97 && key >= 95 ) 0 => keyArray[(key-95)];
    else if( key == 92 ) 0 => keyArray[7];
    else if( key == 94 ) 0 => keyArray[3];
    else if( key <= 91 && key >= 89 ) 0 => keyArray[(-1 * key) + 95];
    else if( key == 93 ) keyArray.zero(); // clears array
    else if( key == 85 ) keyArray.zero(); // clears array
    else if( key == 87 ) keyArray.zero(); // clears array
    <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
}

fun void ambiGrani()
{
    float srcCoordinates[nGrans][9]; // temp storage for coordinate data
    while( true )
    {
        mailBox[4] => now;
        // did you get mail?
        while( mailBox[4].recv(letterOpener) )
        {
            // read your letter
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => srcCoordinates[i/9][i%9]; // assigns massive message of coefficients to temporary array
                srcCoordinates[i/9][i%9] => encoder[i/9][i%9].gain; // copies array over to encoder gains
                // <<< "encoder: ", encoder[i/9][i%9].gain() >>>;
            }
        }
    }
}

fun void angleRecv()
{
    float tempAngles[nGrans][2];
    while( true )
    {
        mailBox[5] => now;
        while( mailBox[5].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => myGPS[i/nGrans].angles[i%2];
                cherr <= myGPS[i/nGrans].angles[0] <= myGPS[i/nGrans].angles[1] <= IO.newline();
            }
        }
    }
}

fun void speakerCoeff() // assigns speaker coefficients then waits for new encoder coefficients
{
    float speakCoeff[8][9]; // where the speaker coefficients are stored, this will die when the shred does
    mailBox[6] => now;
    // did you get mail?
    while( mailBox[6].recv(letterOpener) )
    {
        // read your letter
        for( int i; i < letterOpener.numArgs(); i++ )
        {
            letterOpener.getFloat(i) => speakCoeff[i/9][i%9]; // assigns massive message of coefficients to temporary array
            speakCoeff[i/9][i%9] => decoder[i/9][i%9].gain; // copies array over to decoder gains
            // <<< "decoder: ", i/9, i%9, decoder[i/9][i%9].gain() >>>;
        }
    }
    ready.signal();
    me.exit();
}

for( int i; i < encoder.size(); i++ ) // really annoying three layer for loop that sends encoder blocks to their respective decoder blocks
{
    for( int j; j < encoder[0].size(); j++ )
    {
        fader[i] => encoder[i][j];
        for( int g; g < decoder.size(); g++ )
        {
            encoder[i][j] => decoder[g][j];
            // cherr <= "fader: " <= i <= " into encoder: " <= i <= " section/coordinate: " <= coordinateMarkers[j] <= IO.newline();
            // cherr <= "encoder: " <= i <= " coordinate: " <= coordinateMarkers[j] <= " into decoder: " <= g <= " coordinate: " <= coordinateMarkers[j] <= IO.newline();
        }   
    }
}

for( int i; i < speakSum.size(); i++ ) // sends decode blocks to their respective speaker sums
{
    for( int j; j < decoder[0].size(); j++ )
    {
        decoder[i][j] => speakSum[i];
        // cherr <= "decoder: " <= i <= " coordinate: " <= coordinateMarkers[j] <= " into speaker sum: " <= i <= IO.newline();
    }
}

for( int i; i < dac.channels(); i++ ) // attaches the final speaker sums to their corresponding speakers
{
    speakSum[i] => dac.chan(i);
    // cherr <= "speak sum " <= i <= " connected to channel " <= i <= IO.newline();
}

// spork however many functions needed
for( int i; i < myGPS.size(); i++) // spork a set of interpolators/main grain functions for each GPS
{
    spork ~ grain(i);
    spork ~ ramp_position(i);
    spork ~ ramp_pitch(i);
    spork ~ ramp_gain(i);
    spork ~ ramp_reverb(i);
}

// spork off OSC recievers
spork ~ keyOnListen();
spork ~ keyOffListen();
spork ~ mouseXListen();
spork ~ mouseYListen();
spork ~ speakerCoeff(); 

// open keyboard 
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// print your identity
cherr <= "Your name is " <= hostname <= IO.newline()
      <= "You're getting mail on port " <= port <= IO.newline();

ready => now;

cherr <= "Decoder gains are set and ready" <= IO.newline();

spork ~ ambiGrani();

// go!
while( true ) // the main thread is simply responsible for when to close, it just sits and waits for you to press the esc key
{
    hi => now;
    while( hi.recv( msg ))
    {
        if( msg.isButtonDown() )
        { 
            // get out of here (escape)
            if( msg.ascii == 27 )
            {
                cherr <= "exiting the Dopethrone" <= IO.newline();
                400::ms => now;
                me.exit();
            }
        }
    }
    10::ms => now;
}