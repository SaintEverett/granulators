/*
    name: recv_granular_nchan.ck
    authors: 
        original: Kyle Spratt (Spring 2008, Stanford Laptop Orchestra)
        modified: Baek San Chang (Spring 2008)
        modified: Rob Hamilton (Spring 2009)
        modified: Ge Wang (Spring 2009)
        modified: Everett Carpenter (Spring 2025)

    #----- [HOW TO USE] -----#
    This is the recieving end of an OSC communication pair. To control this script, launch it's partner 'send_granu_nchan.ck'. Make sure they are sending and recieving on the same address
    and all should be good. This script will show you the arguments required when you try to run it in MiniAudicle or the cmd line. 
    #------------------------#

    This is an adaptation of Kyle Spratt's "granular.ck" script, a simple granular synth with typical parameters and adjustable randomization.
    This script takes the # of addressable DAC channels and populates a granulator across each one. Granulators are accessed via the numpad, with each instance assigned to a number.
    If you have 8 channels, the granulators should be assigned in a circular motion around your num pad. 
    If you have 4 channels in a perpendicular fashion, set the "mode" variable to "0" and they will be assigned in a "cross" formation.
    If you have 4 channels in an angled fashion, set the "mode" variable to "1" and they will be assigned in a "X" formation.
    If you have 2 channels, they will be assigned to "4" and "6".
    The various parameters regarding the sound of the granualator, are stored in a class that is defined below, the GPS (Granular Parameter Storage).
    When you edit parameters of a GPS, that is what you are editing, each granulator has a unique GPS and ID. This allows the granulator to read the parameters of a certain GPS, and only that GPS.
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
800.0 => float grainSizeMax; // used as max grain size value in cursor scaling
25.0 => float grainSizeMin; // used as min grain size value in cursor scaling
int nChans; // number of dac channels
int nGrans; // number of desired grains (specified in command line)
int mode; // 0 if perpendicular quad setup 1 if angled quad setup
string filename; // audio file used as source
string hostname; // address to recieve OSC messages
int port; // port to recieve OSC messages
1 => int print; // print granulator changes or not
0 => int device; // where are you getting HID messages
Hid hi; // keyboard
HidMsg msg; // keyboard reader
SndBuf buffs[8]; // buffer
OscIn mailBox[4]; // recieves OSC messages
OscMsg letterOpener; // OSC reader
for( int i; i < buffs.size(); i++ ) // set buffer interpretation
{
    buffs[i].interp(2); // set buffer interpolation
}
0 => int whichGPS; // which GPS are you editing
dac.channels() => nChans; // set how many outputs
nChans => nGrans; // one granulator per channel
WvOut recorders[nChans]; // recorders
Envelope env[nChans]; // envcelope for sound buffers
Gain fader(0.8)[nChans]; // master faders
int keyArray[nChans]; // keyarray for what you're editing
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
GPS myGPS[nGrans]; // class instantiation 
Gain wet[nGrans]; // wet send
Gain dry[nGrans]; // dry send
JCRev rev[nGrans]; // reverb
HPF highpass[nGrans]; // hipass for reverb
Event revWait[nGrans]; // for interpolation of volume to rev
for( int i; i < rev.size(); i++ )
{
    105.0 => highpass[i].freq; // keep low mids out of the reverb
    0.1 => highpass[i].Q; // low Q
    1.0 => rev[i].mix; // full reverb
}
// state you're address
for( auto x : mailBox )
{
    port => x.port; // set port to OSC recievers
}
// print your identity
cherr <= "Your name is " <= hostname <= IO.newline()
      <= "You're getting mail on port " <= port <= IO.newline();

mailBox[0].addAddress("/keypresses/down");
mailBox[1].addAddress("/keypresses/up");
mailBox[2].addAddress("/trackpad/x");
mailBox[3].addAddress("/trackpad/y");

// back and forth between GPS and buffs
for( int i; i < nGrans; i++ ) // assign GPS id, set, exchange and read filename, give sample count and set buffer gain
{
    i+1 => myGPS[i].id; // id assignment
    filename => myGPS[i].filename; // filename assignment
    buffs[i].read(myGPS[i].filename); // have buffer read file
    buffs[i].samples() => myGPS[i].samples; // give GPS sample count from associated buffer
    myGPS[i].gain_target => buffs[i].gain; // set buffer gain
    <<< "GPS #", myGPS[i].id, "has", myGPS[i].samples, " samples" >>>; // announcement
    0.3 => myGPS[i].revmix;
    myGPS[i].revmix => rev[i].mix;
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
    0.005 => float slew;
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
        if( myGPS[id].spacer%2 ) Std.rand2f(myGPS[id].grain_duration,(myGPS[id].grain_duration*5))::ms => now;
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


fun void gpsEditor(int key)
{
    // position setting via numerics
    if( key < 40 && key > 29 )
    {
        for( int i; i < nGrans; i++ ) // run through array, if a keyArray entry is non-zero, perform that parameter change to the/those GPS(s).
        {                                      // The idea was that this for loop would happen for each parameter function in this spork.
            if( keyArray[i] != 0 )
            {
                (key - 29)*myGPS[i].samples/(10) => myGPS[i].position_target;
                <<< "position: ", myGPS[i].position_target >>>;
            }
        }
    }
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
    // up arrow to increase gain
    else if( key == 82 )
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
    else if( key == 81 )
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
    else if( key == 79 )
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
    
    else if( key == 80 )
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
    // rand position
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
    // pitch target
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
    // pitch
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
    // rand pitch
    else if( key == 54 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].pitch - 0.0000025 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
    else if( key == 55 )
    {
        for( int i; i < nGrans; i++ )
        {
            if( keyArray[i] != 0 )
            {
                myGPS[i].pitch + 0.0000025 => myGPS[i].pitch_target;
                if( print ) <<< "pitch: ", myGPS[i].pitch_target >>>;
            }
        }
    }
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

fun void keyOnListen()
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
                if( key == 98 ) spork ~ copierMachine();
                letterOpener.getInt(i) => key;
                spork ~ gpsEditor(key);
                if( key <= 97 && key >= 84 ) spork ~ arrayOnChanger(key);
                // print them out
                // cherr <= key <= " on" <= IO.newline();
            }
        }
    }
}

fun void keyOffListen()
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

fun void mouseXListen()
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

fun void mouseYListen()
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
                if( keyArray[i] != 0 ) // scaled_value = ((input_value - in_min) / (in_max - in_min)) * (out_max - out_min) + out_min
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

fun void arrayOnChanger(int key)
{
    if( nGrans == 8 ) // 8 speakers
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
    else if( nGrans == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) (key-95) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 94 ) (key-92) => keyArray[1];
        else if( key == 90 ) (key-87) => keyArray[2];
        else if( key == 92 ) (key-88) => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) (key-94) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 97 ) (key-95) => keyArray[1];
        else if( key == 91 ) (key-98) => keyArray[2];
        else if( key == 89 ) (key-85) => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) (key-91) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if ( key == 94 ) (key-92) => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

fun void arrayOffChanger(int key)
{
    if( nGrans == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) 0 => keyArray[(key-95)];
        else if( key == 92 ) 0 => keyArray[7];
        else if( key == 94 ) 0 => keyArray[3];
        else if( key <= 91 && key >= 89 ) 0 => keyArray[(-1 * key) + 95];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 85 ) keyArray.zero();// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) keyArray.zero();// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( nGrans == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 94 ) 0 => keyArray[1];
        else if( key == 90 ) 0 => keyArray[2];
        else if( key == 92 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 97 ) 0 => keyArray[1];
        else if( key == 91 ) 0 => keyArray[2];
        else if( key == 89 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if ( key == 94 ) 0 => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

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
    ("call this" + i, IO.INT24) => recorders[i].wavFilename;
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