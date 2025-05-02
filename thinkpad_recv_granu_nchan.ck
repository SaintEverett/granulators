/*
    name: thinkpad_recv_granu_nchan.ck
    authors: 
        original: Kyle Spratt (Spring 2008, Stanford Laptop Orchestra)
        modified: Baek San Chang (Spring 2008)
        modified: Rob Hamilton (Spring 2009)
        modified: Ge Wang (Spring 2009)
        modified: Everett Carpenter (Spring 2025)

    This is an adaptation of Kyle Spratt's "granular.ck" script, a simple granular synth with typical parameters and adjustable randomization.
    The script works best in numbers, typically with one instance for each speaker/channel (but you can definitely do more than one per channel, just watch your gain!)
    This script allows your to address the variables of each instance, via the numpad, starting at 1. 
    As for arguments, give this guy how many instances of the script you want, and an audio file. Based on the numbers of instances, these granulators will populate your audio outputs.
    If you want to add the ability to specify which channel you want each granulator, that is easily added with some tweaking, the same can be said about different audio files per granulator.
    The various parameters regarding the sound of the granualator, are stored in a class that is defined below, the GPS (Granular Parameter Storage).
    When you edit parameters of a GPS, that is what you are editing, each granulator has a unique GPS and ID. This allows the granulator to read the parameters of a certain GPS, and only that GPS.
    Enjoy! 

    Reach out with any questions at carpee2@rpi.edu

*/

// Declare GPS
class GPS
{
    // can be changed to acheive a more varying
    // asynchronous envelope for each grain duration
    0.0 => float grain_length;
    // unique id to GPS
    int id;
    // buffer file
    string filename;
    // parameters of the function 
    72 => float grain_duration; // initial value to prevent starting at 0
    5.0 => float rand_grain_duration;
    1.0 => float pitch;
    0.0 => float rand_pitch;
    int samples;
    int spacer;
    1 => int position;
    0 => int rand_position;
    // targets
    float position_target;
    1.0 => float pitch_target;
    0.0 => float gain_target;
    //
    0.0 => float temp_gain;
    0.0 => float pause;
    0.0 => float revmix; // reverb mix of GPS
    0.2 => float target_revmix;

    // functions
    fun void setId( int y )
    {
        y => id;
    }
}

// instantiation
500.0 => float grainSizeMax;
15.0 => float grainSizeMin;
int nChans;
int nGrans;
string filename;
string hostname;
int port;
1 => int print;
0 => int device;
Hid hi;
HidMsg msg;

OscIn mailBox[4];
OscMsg letterOpener;
0 => int whichGPS;
int keyArray[4];
[0,0,0,0] @=> int keyCount[];
dac.channels() => nChans;
nChans => nGrans;
SndBuf buffs[nGrans];
Envelope env[nGrans];
Gain fader(1)[nGrans];
WvOut recorders[nChans];
for( int i; i < buffs.size(); i++ )
{
    buffs[i].interp(2);
}
// check the command line
if( !me.args() ) 
{
    cherr <= "Input required, format is [audiofile]:[hostname]:[port]" <= IO.newline()
          <= "If no port specified, default to 6449";
    me.exit();
}
else if( me.args() == 1 )
{
    cherr <= "Need audio file" <= IO.newline();
}
else if( me.args() == 2 )
{
    me.arg(0) => filename;
    me.arg(1) => hostname;
    6449 => port;
}
else if( me.args() == 3 )
{
    me.arg(0) => filename;
    me.arg(1) => hostname;
    me.arg(2) => Std.atoi => port;
}
// GPS nGrans
GPS myGPS[nGrans];
Gain wet[nGrans];
Gain dry[nGrans];
JCRev rev[nGrans]; // reverb
HPF highpass[nGrans]; // hipass for reverb
Event revWait[nGrans]; // for interpolation of volume to rev
for( int i; i < rev.size(); i++ )
{
    65.0 => highpass[i].freq;
    0.1 => highpass[i].Q;
    1.0 => rev[i].mix;
}
// state you're address
for( auto x : mailBox )
{
    port => x.port;
}
// print your identity
cherr <= "Your name is " <= hostname <= IO.newline()
      <= "You're getting mail on port " <= port <= IO.newline();

mailBox[2].addAddress("/trackpad/x");
mailBox[3].addAddress("/trackpad/y");
mailBox[0].addAddress("/keypresses/down");
mailBox[1].addAddress("/keypresses/up");
// back and forth between GPS and buffs
int count;
while( count < nGrans )
{
    count+1 => myGPS[count].id;
    filename => myGPS[count].filename;
    buffs[count].read(myGPS[count].filename);
    buffs[count].samples() => myGPS[count].samples;
    myGPS[count].gain_target => buffs[count].gain;
    <<< "GPS #", myGPS[count].id, "has", myGPS[count].samples, " samples" >>>;
    0.3 => rev[count].mix;
    count++;
}

fun float decimalPrecision( int precision, float value ) // get decimal precision, function courtesy of user cviejo on the ChucK discord
{
    Math.pow( 10, precision ) => float scale;
    return Math.round( value * scale ) / scale;
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
            // cherr <= myGPS[id].revmix <= IO.newline();
            myGPS[id].revmix => wet[id].gain;
            0.8 - wet[id].gain() => dry[id].gain;
            // cherr <= wet[id].gain() <= " " <= dry[id].gain() <= IO.newline();
            5::ms => now;
        }
        else { revWait[id] => now; }
    }
}

// position interpolation (event[id-0])
fun void ramp_position( int posId )
{
    posId => int id;
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
    pitId => int id;
    // the slew
    0.005 => float slew;
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
    gainId => int id; 
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
    grainId => int id;
    // can be changed to acheive a more varying
    // asynchronous envelope for each grain duration
    0.0 => myGPS[id].grain_length;
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
        // enable envelope
        env[id].keyOn();
        // wait for rise
        myGPS[id].grain_length*0.5::ms => now;
        // close envelope
        env[id].keyOff();
        // wait
        myGPS[id].grain_length*0.5::ms => now;
        // until next grain
        myGPS[id].pause::ms => now;
        if( myGPS[id].spacer%2 ) Std.rand2f(200,3000)::ms => now;
    }
}


fun void copierMachine()
{
    for( 1 => int i; i < myGPS.size(); i++ )
    {
        myGPS[0].grain_length => myGPS[i].grain_length;
        myGPS[0].grain_duration => myGPS[i].grain_duration;
        myGPS[0].rand_grain_duration => myGPS[i].rand_grain_duration;
        myGPS[0].rand_pitch => myGPS[i].rand_pitch;
        myGPS[0].rand_position => myGPS[i].rand_position;
        myGPS[0].position_target => myGPS[i].position_target;
        myGPS[0].pitch_target => myGPS[i].pitch_target;
        myGPS[0].gain_target => myGPS[i].gain_target;
        myGPS[0].revmix => myGPS[i].revmix;
        myGPS[i].revmix => rev[i].mix;
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
    // up arrow to increase gain
    else if( key == 66 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                if( myGPS[i].gain_target <= 0.05 )
                {
                    0.05 + myGPS[i].gain_target => myGPS[i].temp_gain;
                }
                else 
                {
                    myGPS[i].gain_target * 1.1 => myGPS[i].temp_gain;
                }
                Math.min( 6.0, myGPS[i].temp_gain ) => myGPS[i].temp_gain;
                myGPS[i].temp_gain => myGPS[i].gain_target;
                if( print ) <<< "gain: ", buffs[i].gain() >>>;
            }
        }
    }
    // down arrow to reduce gain
    else if( key == 67 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                if( myGPS[i].gain_target <= 0.05 )
                {
                    myGPS[i].gain_target - 0.05 => myGPS[i].temp_gain;
                }
                else
                {
                    myGPS[i].gain_target/1.1 => myGPS[i].temp_gain;              
                }
                Math.max( 0.0, myGPS[i].temp_gain ) => myGPS[i].temp_gain;
                myGPS[i].temp_gain => myGPS[i].gain_target;
                if( print ) <<< "gain: ", buffs[i].gain() >>>;
            }
        }
    }
    // grain duration with arrow keys
    else if( key == 69 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                // right arrow (longer duration)
                Math.min( 5000.0, (myGPS[i].grain_duration * 1.06 )) => myGPS[i].grain_duration;
                myGPS[i].grain_duration * 0.5::ms => env[i].duration;
                if( print ) <<< "grain.length: ", myGPS[i].grain_duration >>>;
            }
        }
    }
    else if( key == 68 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                // left arrow (shorter duration)
                Math.max( 1.0, ( myGPS[i].grain_duration / 1.06 )) => myGPS[i].grain_duration;
                myGPS[i].grain_duration * 0.5::ms => env[i].duration;
                if( print ) <<< "grain length: ", myGPS[i].grain_duration >>>;
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
            if( keyArray[i] != 0 )
            {
                Math.min(myGPS[i].samples, myGPS[i].position + 11000) => myGPS[i].position_target;
                if( print ) <<< "position: ", myGPS[i].position_target >>>;
            }
        }
    }
    // and step back via -
    else if( key == 45 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                Math.max(1, myGPS[i].position - 11000) => myGPS[i].position_target;
                if( print ) <<< "position: ", myGPS[i].position_target >>>;
            }
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
    else if( key == 91 )
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
    else if( key == 93 )
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
                if( key <= 65 && key >= 58 ) spork ~ arrayOnChanger(key);
                else spork ~ gpsEditor(key);
                // print them out
                cherr <= key <= " on" <= IO.newline();
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
                if( key <= 65 && key >= 58 ) spork ~ arrayOffChanger(key);
                // print them out
                cherr <= key <= " off" <= IO.newline();
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
                }
            }
        }
    }
}

fun void arrayOnChanger(int key) // changes the storage array from what keypress is recieved
{
    if( key <= 61 && key >= 58 ) 
    {
        if( keyCount[(key-58)]%2 == 0 )
        {
            (key-58)+1 => keyArray[(key-58)];
        }
        else if( keyCount[(key-58)]%2 == 1 )
        {
            0 => keyArray[(key-58)];
        }
    }
    else if( key == 62 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
    else if( key == 63 ) [1,0,3,0] @=> keyArray;// key * edits all GPS DIAGONAL to listener 
    else if( key == 64 ) [0,2,0,4] @=> keyArray;// key + edits all GPS ADJACENT to listener
    for( int i; i < keyArray.size(); i++ )
    {
        if( keyArray[i] != 0 ) 1 => keyCount[i];
        else 0 => keyCount[i];
    }
    <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
}

fun void arrayOffChanger(int key) // adjusts based on what keylift is recieved
{
    if( key == 65 ) keyArray.zero();
    for( int i; i < keyArray.size(); i++ )
    {
        if( keyArray[i] != 0 ) 1 => keyCount[i];
        else 0 => keyCount[i];
    }
    <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
}

// spork however many functions needed
0 => count;

for( int i; i < nGrans; i++)
{
    spork ~ grain(i);
    spork ~ ramp_position(i);
    spork ~ ramp_pitch(i);
    spork ~ ramp_gain(i);
    spork ~ ramp_reverb(i);
}

//spork ~ trackpadTracker();
spork ~ keyOnListen();
spork ~ keyOffListen();
spork ~ mouseXListen();
spork ~ mouseYListen();

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

for( int i; i < nChans; i++ )
{
    fader[i] => dac.chan(i);
    dac.chan(i) => recorders[i] => blackhole;
    ("3.31.2025.9.45 " + i, IO.INT24) => recorders[i].wavFilename;
    cherr <= "fader " <= i <= " connected to channel " <= i <= IO.newline();
}

for( int i; i < recorders.size(); i++ )
{
    1 => recorders[i].record;
}

// go!
while( true ) 
{
    hi => now;
    while( hi.recv( msg ))
    {
        if( msg.isButtonDown() )
        { 
            if( msg.key == 98 )
            {
                spork ~ copierMachine();
                <<< "copy!" >>>;
            }
            // get out of here (escape)
            if( msg.ascii == 27 )
            {
                <<< "exiting!", "" >>>;
                for( int i; i < recorders.size(); i++ )
                {
                    recorders[i].closeFile();
                }
                me.exit();
            }
        } 
    }
}