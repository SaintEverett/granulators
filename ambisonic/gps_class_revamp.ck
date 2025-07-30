class Granulator extends Chugraph
{
    SndBuf buffer;
    WinFuncEnv env;
    int id; // unique id
    string filename; // audio file
    // parameters of the granulator 
    800.0 => float grainSizeMax; // used as max grain size value in cursor scaling
    25.0 => float grainSizeMin; // used as min grain size value in cursor scaling
    1.0 => float grain_duration; // initial value to prevent starting at 0
    1.0 => float rand_grain_duration; // amt of random grain length
    1.0 => float pitch; // pitch
    0.0 => float rand_pitch; // amt of random pitch
    1 => int position; // this is in samples
    0 => int rand_position; // so is this
    10::ms => dur pause;
    float grain_length;
    int samples;
    int spacer;
    // targets
    float position_target; // where the position slew wants to go
    1.0 => float pitch_target; // where the pitch slew wants to go
    0.0 => float gain_target; // where the volume slew wants to go
    0.0 => float temp_gain;

    fun void Granulator(string file, int identity)
    {
        file => filename;
        identity => id;
        buffer.read(filename);
        if(buffer.ready() == 0) <<< "buffer #", id, "encountered issues" >>>;
        // patchbay
        buffer => env => outlet;
    }

    fun void fileChange(string n_filename)
    {
        env.keyOff(); // ensure we are silent
        buffer.read(n_filename); // try to read
        if(buffer.ready() == 0 ) <<< "buffer #", id, "encountered issues after trying change source file" >>>; // if it didn't read well then say so
        n_filename => filename; // assuming this is now the currently playing file, officially change the variable
    }

    fun void begin()
    {
        spork ~ ramp_position();
        spork ~ ramp_gain();
        spork ~ ramp_position();
    }

    // position interpolation
    fun void ramp_position()
    {
        // compute rough threshold
        2.0 * (samples) $ float / 10.0 => float thresh;
        // choose slew
        0.005 => float slew;

        // go
        while( true )
        {
            // really far away from target?
            if(Std.fabs(position - position_target) > (samples / 5))
            {
                1.0 => slew;
            }
            else
            {
                0.005 => slew;
            }
            // slew towards position
            ( (position_target - position) * slew + position ) $ int => position;
            // wait time
            1::ms => now;
        }
    }

    // pitch interpolation
    fun void ramp_pitch()
    {
        // the slew
        0.01 => float slew;
        // go
        while( true )
        {
            // slew
            ((pitch_target - pitch) * slew + pitch) => pitch;
            // wait
            5::ms => now;
        }
    }

    // volume interpolation
    fun void ramp_gain()
    { 
        // the slew
        0.05 => float slew;
        // go
        while( true )
        {
            // slew
            ( (gain_target - buffer.gain()) * slew + buffer.gain() ) => buffer.gain;
            // wait
            10::ms => now;
        }
    }

    // grain function
    fun void grain()
    { 
        0.0 => grain_length; // can be changed to acheive a more varying asynchronous envelope for each grain duration
        grain_duration*0.5::ms => env.attackTime; 
        grain_duration*0.5::ms => env.releaseTime;
        // go!
        while( true )
        {   
            // compute grain length
            Std.rand2f( Math.max(1.0, grain_duration - rand_grain_duration),
            grain_duration + rand_grain_duration) => grain_length;
            // compute grain duration for envelope
            grain_duration*0.5::ms => env.attackTime; 
            grain_duration*0.5::ms => env.releaseTime;
            // set buffer playback rate
            Std.rand2f( Math.max(0.0625, pitch - rand_pitch), pitch + rand_pitch ) => buffer.rate;
            // set buffer position
            Std.rand2( Math.max(1, position - rand_position ) $ int,
            Math.min( samples, position + rand_position ) $ int ) => buffer.pos;
            env.keyOn(); // enable envelope
            grain_length*0.5::ms => now; // wait for rise
            env.keyOff(); // close envelope
            grain_length*0.5::ms => now; // wait
            pause => now; // until next grain
            if( spacer%2 ) Std.rand2f(200,1000)::ms => now; // if the spacer is enabled, it will cause random pauses between grains
        }
    }
}

// Declare GPS
class GPS
{
    int print;
    fun void key(int key, Granulator gran) // huge interface layer that edits all selected GPS in keyArray[] according to what keyboard USB key code is recieved
    {
        // position setting via numerics
        if( key < 40 && key > 29 )
        {
            (key - 29)*gran.samples/(10) => gran.position_target;
            <<< "position: ", gran.position_target >>>;
        }
        // enable spacer via alt key
        else if( key == 226 )
        {
            (gran.spacer + 1) % 2 => gran.spacer;
            <<< "spacer: ", gran.spacer >>>;
        }
        // go to beginning of the file via `
        else if( key == 53 )
        {
            0 => gran.position_target;
            <<< "position: ", gran.position_target >>>;
        }
        // advance via = 
        else if( key == 46 )
        {
            Math.min(gran.samples, gran.position + 11000) => gran.position_target;
            if( print ) <<< "position: ", gran.position_target >>>;
            /*

                Math.min`(gran.samples, gran.position + 11000) => gran.position_target;
                if( print ) <<< "position: ", gran.position_target >>>;
            }
            */
        }
        // and step back via -
        else if( key == 45 )
        {
            Math.max(1, gran.position - 11000) => gran.position_target;
            if( print ) <<< "position: ", gran.position_target >>>;
            /*

                Math.max(1, gran.position - 11000) => gran.position_target;
                if( print ) <<< "position: ", gran.position_target >>>;
            }
            */
        }
        // random grain duration
        else if( key == 229 )
        {
            // shift to decrease random grain duration
            Math.max(0.01, ( gran.rand_grain_duration / 1.3 )) => gran.rand_grain_duration;
            if( gran.rand_grain_duration <= 0.01 ) 0.01 => gran.rand_grain_duration;
            if( print ) <<< "- randomness grain length: ", gran.rand_grain_duration >>>;
        }
        else if( key == 40 )
        {
            if( gran.rand_grain_duration <= 0.01 ) 0.01 => gran.rand_grain_duration;
            Math.min( 2000.0, (gran.rand_grain_duration * 1.3 )) => gran.rand_grain_duration;
            if( print ) <<< "+ randomness grain length: ", gran.rand_grain_duration >>>;
        }
        // reduce rand position via [
        else if( key == 47 )
        {
            (Math.max(0.0, gran.rand_position - 500.0)) $ int => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        // increase rand position via ]
        else if( key == 48 )
        {
            (Math.min(gran.samples, gran.rand_position + 500)) $ int => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        // set random position via qwertyuiop
        else if( key == 20 )
        {
            0 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 26 )
        {
            200 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 8 )
        {
            2000 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 21 )
        {
            20000 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 23 )
        {
            40000 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 28 )
        {
            80000 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 24 )
        {
            100000 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 12 )
        {
            gran.samples * 7 / 9 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 18 )
        {
            gran.samples * 8 / 9 => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        else if( key == 19 )
        {
            gran.samples => gran.rand_position;
            if( print ) <<< "randomness of position: ", gran.rand_position >>>;
        }
        // pitch of granulator via asdfghjkl;' 
        else if( key == 10 )
        {
            1.0 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 9 )
        {
            0.75 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 7 )
        {
            0.5 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 22 )
        {
            0.25 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 4 )
        {
            0.000083 => gran.pitch_target; // 4 samples per second at 48000
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 11 )
        {
            2.0 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 13 )
        {
            4.0 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 14 )
        {
            8.0 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 15 )
        {
            16.0 => gran.pitch_target;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 51 )
        {
            gran.pitch - .05 / 12 => gran.pitch_target => gran.pitch;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        else if( key == 52 )
        {
            gran.pitch + .05 / 12 => gran.pitch_target => gran.pitch;
            if( print ) <<< "pitch: ", gran.pitch_target >>>;
        }
        // rand pitch via < and >
        else if( key == 54 )
        {
            gran.rand_pitch - 0.025 => gran.rand_pitch;
            if( print ) <<< "rando of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 55 )
        {
            gran.rand_pitch + 0.025 => gran.rand_pitch;
            if( print ) <<< "rando of pitch: ", gran.rand_pitch >>>;
        }
        // random pitch via zxcvbnm
        else if( key == 29 )
        {
            0.0 => gran.rand_pitch;      
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 27 )
        {
            1.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 6 )
        {
            2.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 25 )
        {
            3.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 5 )
        {
            4.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 17 )
        {
            5.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
        else if( key == 16 )
        {
            6.0 => gran.rand_pitch;
            if( print ) <<< "randomness of pitch: ", gran.rand_pitch >>>;
        }
    }
    
    fun void mouse(float placement[], Granulator gran)
    {
        ((Math.pow((placement[0] - 0.0),4) * (gran.grainSizeMax - gran.grainSizeMin) + gran.grainSizeMin)) => gran.grain_duration;
        placement[1] => myGPS[i].gain_target;
    }
}
