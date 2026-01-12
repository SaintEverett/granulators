public class AmbisonicSupport // emotional support for users working with ambisonics in chuck
{
    fun void position(UGen input, Encode2 encoder, float azi, float zeni)
    {
        if(input.isConnectedTo(encoder)) encoder.pos(azi, zeni);
        else 
        {
            input => encoder;
            encoder.pos(azi, zeni);
        }
    }

    
}