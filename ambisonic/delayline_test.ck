@import "delayline_class.ck"

Impulse click;
DelayLine line(20::ms, 22::ms);
Gain vol(0.25);

click => line => vol => dac;

line.feedback(0.9);

while(true)
{
    1 => click.next;
    100::ms => now;
}