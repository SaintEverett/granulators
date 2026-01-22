public class Granulator extends Chugraph
{
    SndBuf buffer;
    WinFuncEnv env[2];
    string filename; // audio file
    // parameters of the granulator 
    800.0 => float grainSizeMax; // used as max grain size value in cursor scaling
    25.0 => float grainSizeMin; // used as min grain size value in cursor scaling
    1.0 => float grain_duration; // the internalized length of the grains (set this)
    1.0 => float rand_grain_duration; // amt of random grain length
    1.0 => float pitch; // pitch
    0.0 => float rand_pitch; // amt of random pitch
    1 => int position; // this is in samples
    0 => int rand_position; // so is this
    0 => int pitchscale; // this will make randomized pitch more or less significant (its fun)
    5::ms => dur pause;
    float grain_length; // the value that is calculated using grain_duration (do not set this)
    int samples; // how long is the current file in samples
    int spacer; // are there spaces
    15.0 => float space_length; // how long are the spaces
    // targets
    float position_target; // where the position slew wants to go
    1.0 => float pitch_target; // where the pitch slew wants to go
    1.0 => float gain_target; // where the volume slew wants to go
    0.0 => float temp_gain;
    1 => int go; // by default, grain will play, go is used to silence the granulator

    fun void Granulator(string file)
    {
        file => filename;
        buffer.read(filename);
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

    fun void fileChange(string n_filename)
    {
        0 => go; // stop granulation
        env[0].keyOff(); // ensure we are silent
        env[1].keyOff();
        buffer.read(n_filename); // try to read
        if(!buffer.ready()) <<< "buffer #", "encountered issues after trying to change source file" >>>; // if it didn't read well then say so
        n_filename => filename; // assuming this is now the currently playing file, officially change the variable
        1 => go; // alright we're ready to start back up
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
            Math.clampf((Std.rand2f( Math.max(1.0, grain_duration - rand_grain_duration), grain_duration + rand_grain_duration)), 0, samples) => grain_length;
            // compute grain duration for envelope
            for(int i; i < env.size(); i++)
            {
                grain_length*0.5::ms => env[i].attackTime; 
                grain_length*0.5::ms => env[i].releaseTime;
            }
            // set buffer playback rate
            if(rand_pitch) Std.rand2f( Math.max(0.0625, pitch - (rand_pitch/(pitchscale+1))), pitch + (rand_pitch/(pitchscale+1)) ) => buffer.rate;
            else pitch => buffer.rate;
            // set buffer position
            if(rand_position) Std.rand2( Math.max(1, position - rand_position ) $ int, Math.min( samples, position + rand_position ) $ int ) => buffer.pos;
            else position => buffer.pos;
            if(go)
            {    env[0].keyOn(); // enable envelope
                grain_length*0.5::ms => now; // wait for rise
                env[0].keyOff(); // close envelope
                grain_length*0.5::ms => now; // wait
                pause => now; // until next grain
                if( spacer%2 ) Std.rand2f( space_length*Math.max(1.0, grain_duration - rand_grain_duration), grain_duration + rand_grain_duration)::ms => now; // if the spacer is enabled, it will cause random pauses between grains
            }
        }
    }

    fun void setPitch(float n_pitch) // slew to position
    {
        if(n_pitch > 0.0) n_pitch => pitch_target;
    }

    fun void instantPitch(float n_pitch) // jump to position
    {
        if(n_pitch > 0.0) n_pitch => pitch;
    }

    fun void setPosition(float n_position) // normalized to [0.0,1.0]
    {
        if(n_position > 0.0) n_position * samples => position_target;
    }

    fun void instantPosition(float n_position) // jump to position
    {
        if(n_position > 0) (n_position * samples) $ int  => position;
    }

    fun void setVolume(float n_gain)
    {
        n_gain => gain_target;
    }

    fun void instantGain(float n_gain)
    {
        n_gain => gain => buffer.gain;
    }

    fun void setGrainSize(float n_size)
    {
        if(n_size > 0) n_size => grain_duration;
    }
}
