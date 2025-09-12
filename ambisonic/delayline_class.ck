public class DelayLine extends Chugraph
{
    Delay line; // delay
    Gain feed(0.0); // feedback
    PoleZero allpass; // all pass
    inlet => line => allpass => outlet;
    allpass => feed => line;

    fun void DelayLine(dur length, dur max)
    {
        line.set(length, max);
        allpass.allpass(-0.99866894658);
    }

    fun void feedback(float coeff)
    {
        if(coeff < 1.0 && coeff > -1.0) feed.gain(coeff);
        else cherr <= IO.newline() <= "Feedback coefficient too crazy" <= IO.newline();
    }
}