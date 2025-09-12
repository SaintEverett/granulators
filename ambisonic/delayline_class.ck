public class DelayLine extends Chugraph
{
    Delay line; // delay
    Gain feed(0.0); // feedback
    PoleZero allpass; // all pass
    Bitcrusher blt;
    inlet => line => blt => allpass => outlet;
    allpass => feed => line;

    fun void DelayLine(dur length, dur max)
    {
        line.set(length, max);
        allpass.allpass(-0.99866894658);
        blt.bits(12);
        blt.downsampleFactor(6);
    }

    fun void feedback(float coeff)
    {
        if(coeff <= 1.0 && coeff >= -1.0) feed.gain(coeff);
        else cherr <= "Feedback coefficient too crazy" <= IO.newline();
    }

    fun float feedback()
    {
        return feed.gain();
    }
}