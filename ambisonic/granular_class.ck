public class Granulator extends Chugraph
{
    SndBuf buffer;
    WinFuncEnv env[2];
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
    0 => int pitchscale; // this will make randomized pitch more or less significant (its fun)
    10::ms => dur pause;
    float grain_length;
    int samples;
    int spacer;
    // targets
    float position_target; // where the position slew wants to go
    1.0 => float pitch_target; // where the pitch slew wants to go
    1.0 => float gain_target; // where the volume slew wants to go
    0.0 => float temp_gain;

    fun void Granulator(string file)
    {
        file => filename;
        buffer.read(filename);
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

    fun void fileChange(string n_filename)
    {
        env[0].keyOff(); // ensure we are silent
        env[1].keyOff();
        buffer.read(n_filename); // try to read
        if(buffer.ready() == 0 ) <<< "buffer #", "encountered issues after trying to change source file" >>>; // if it didn't read well then say so
        n_filename => filename; // assuming this is now the currently playing file, officially change the variable
    }

    fun void play()
    {
        spork ~ ramp_position();
        spork ~ ramp_gain();
        spork ~ ramp_pitch();
        spork ~ grain();
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
        for(int i; i < env.size(); i++)
        {
            grain_duration*0.5::ms => env[i].attackTime; 
            grain_duration*0.5::ms => env[i].releaseTime;
        }
        // go!
        while( true )
        {   
            // compute grain length
            if(rand_grain_duration) Std.rand2f( Math.max(1.0, grain_duration - rand_grain_duration), grain_duration + rand_grain_duration) => grain_duration;
            // compute grain duration for envelope
            for(int i; i < env.size(); i++)
            {
                grain_duration*0.5::ms => env[i].attackTime; 
                grain_duration*0.5::ms => env[i].releaseTime;
            }
            // set buffer playback rate
            if(rand_pitch) Std.rand2f( Math.max(0.0625, pitch - (rand_pitch/(pitchscale+1))), pitch + (rand_pitch/(pitchscale+1)) ) => buffer.rate;
            else pitch => buffer.rate;
            // set buffer position
            if(rand_position) Std.rand2( Math.max(1, position - rand_position ) $ int, Math.min( samples, position + rand_position ) $ int ) => buffer.pos;
            else position => buffer.pos;
            env[0].keyOn(); // enable envelope
            grain_duration*0.5::ms => now; // wait for rise
            env[0].keyOff(); // close envelope
            grain_duration*0.5::ms => now; // wait
            pause => now; // until next grain
            if( spacer%2 ) Std.rand2f( Math.max(1.0, grain_duration - rand_grain_duration), grain_duration + rand_grain_duration)::ms => now; // if the spacer is enabled, it will cause random pauses between grains
        }
    }
}
