@import "FakeCursor.ck"
@import "granular_class"

Granulator grains("../audio/american.wav")[4];
Gain lr(1.0/grains.size())[2];
FakeCursor curse(0);
NRev rev[2];

rev[0].mix(0.125);
rev[1].mix(0.125);

lr[0] => rev[0] => dac.chan(0);
lr[1] => rev[1] => dac.chan(1);

for(int i; i < grains.size(); i++)
{
    grains[i] => lr[i%2];
    grains[i].instantPosition(Math.random2f(0.0, 1.0));
    grains[i].grainSize(Math.random2f(1.0, 15.0));
    grains[i].setVolume(1.0);
    grains[i].play();
}

fun void update()
{
    while(true)
    {
        10::ms => now;
        for(int i; i < grains.size(); i++)
        {
            curse.y() * 2000.0 => grains[i].rand_grain_duration;
            grains[i].setPosition(curse.x());
            grains[i].grainSize(Std.scalef(curse.scroll(), 0.0, 1.0, 1.0, 36.0));
        }
    }
}

spork ~ update();

while(true)
{
    1000::ms => now;
    for(int i; i < grains.size(); i++)
    {
        cherr <= grains[i].grainSize() <=  ", " <= grains[i].getPosition() <= " ; ";
    }
    cherr <= IO.nl() <= "x: " <= curse.x() <= " y: " <= curse.y() <= " scroll: " <= curse.scroll() <= IO.nl();
}