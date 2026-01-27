@import "oscHID.ck"

OscHID listener(4526);

while(true)
{
    listener.signal => now;
    cherr <= listener.lastMsgType <= " " <= listener.lastKeyOn <= " " <= listener.lastKeyOff <= " " <= listener.lastMouseX <= " " <= listener.lastMouseY <= IO.nl();
}