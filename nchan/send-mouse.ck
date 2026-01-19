//----------------------------------------------------------------------------
// name: osc-dump.ck
// desc: listen to and print all OSC messages on specified port
//       for example, launch this with s.ck
//       (make sure port is the same in both sender and receiver)
//----------------------------------------------------------------------------

// OSC in
OscOut oout;
Hid mouse;
HidMsg momsg;

if(!mouse.openMouse(0)) me.exit();

string hostname;
int port;

// check command line
if( me.args() ) me.arg(0) => hostname;
if( me.args() > 1 ) me.arg(1) => Std.atoi => port;

// aim the transmitter at destination
oout.dest( hostname, port );

// infinite time loop
while( true )
{
    mouse => now;
    while(mouse.recv(momsg))
    {
        oout.start("/mouse");
        momsg.scaledCursorX => oout.add;
        1.0 - momsg.scaledCursorY => oout.add;
        oout.send();
        10::ms => now;
    }
}
