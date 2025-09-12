public class GranularSupport
{
    int print;
    fun void key(int key, Granulator gran) // huge interface layer 
    {
        // position setting via numerics
        if( key < 40 && key > 29 )
        {
            (key - 29)*gran.samples/(10) => gran.position_target;
            if( print ) <<< "position: ", gran.position_target >>>;
        }
        // enable spacer via alt key
        else if( key == 226 )
        {
            (gran.spacer + 1) % 2 => gran.spacer;
            if( print ) <<< "spacer: ", gran.spacer >>>;
        }
        // go to beginning of the file via `
        else if( key == 53 )
        {
            0 => gran.position_target;
            if( print ) <<< "position: ", gran.position_target >>>;
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
        else if( key == 56 )
        {
            if(gran.pitchscale) 0 => gran.pitchscale;
            else 5 => gran.pitchscale;
            if( print && gran.pitchscale) cherr <= "scale of randomness: low" <= IO.newline();
            if( print && !gran.pitchscale) cherr <= "scale of randomness: high" <= IO.newline();
        }
    }

    fun void mouse(float placement[], Granulator gran)
    {
        ((Math.pow((placement[0] - 0.0),4) * (gran.grainSizeMax - gran.grainSizeMin) + gran.grainSizeMin)) => gran.grain_duration;
        placement[1] => gran.gain_target;
    }
}
