// instantiation
OscOut mailMan[4];
Hid hi;
HidMsg msg;
// identify yourself
string address;
int port;
// device #
0 => int device;

if( !me.args() ) 
{
    cherr <= "Input required, format is [address]:[port]:[hid]" <= IO.newline()
          <= "If no port specified, default to 6449" <= IO.newline()
          <= "If no HID specified, default to 0" <= IO.nl();
    me.exit();
}
else if( me.args() == 1 )
{
    me.arg(0) => address;
    6449 => port;
}
else if( me.args() == 2 )
{
    me.arg(0) => address;
    me.arg(1) => Std.atoi => port;
}
else if( me.args() == 3 )
{
  me.arg(0) => address;
  me.arg(1) => Std.atoi => port;
  me.arg(2) => Std.atoi => device;
}
// print your identity
cherr <= "You're sending mail to " <= address 
      <= " on port " <= port <= IO.newline();

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
cherr <= "keyboard '" <= hi.name() <= "' ready" <= "" <= IO.newline();

for( int i;i < mailMan.size(); i++ )
{
    mailMan[i].dest(address,port);
}

fun void trackpadTracker()
{ 
    Hid mouse;
    HidMsg mmsg; 
    // open mouse/trackpad 
    if( !mouse.openMouse( 0 ) ) me.exit();
    cherr <= "trackpad/mouse '" <= mouse.name() <= "' ready" <= "" <= IO.newline();
    while( true )
    {
        mouse => now;        
        while( mouse.recv( mmsg ) )
        {
            if( mmsg.isMouseMotion() )
            {
            	MouseCursor.scaled() @=> vec2 xy;
                if( mmsg.deltaX < 1 || mmsg.deltaX > -1 )
                {
                    mailMan[2].start("/trackpad/x");

                    xy.x => mailMan[2].add;

                    mailMan[2].send();

                }

                if( mmsg.deltaY < 1 || mmsg.deltaY > -1 )
                {
                    mailMan[3].start("/trackpad/y");

                    1.0 - xy.y => mailMan[3].add;
					<<< xy.x, 1.0 - xy.y >>>;
                    mailMan[3].send();

                }
            }
        }
    }
}

fun void shipping()
{
    while( true )
    {
        hi => now;
        while( hi.recv(msg) )
        {
            if( msg.isButtonDown() )
            {
                mailMan[0].start("/keypresses/down");

                msg.key => mailMan[0].add;

                mailMan[0].send();

                // cherr <= "down sent" <= IO.newline();
            }   
            if( msg.isButtonUp() )
            {
                mailMan[1].start("/keypresses/up");

                msg.key => mailMan[1].add;

                mailMan[1].send();

                // cherr <= "up sent" <= IO.newline();
            }
        }
    }
}

spork ~ shipping();

spork ~ trackpadTracker();

while( true )
{
    hi => now;
    if( msg.isButtonDown() )
    {
        if( msg.ascii == 27 )
        {
            cherr <= "exiting";
            300::ms => now;
            cherr <= " . ";
            300::ms => now;
            cherr <= " . ";
            300::ms => now;
            cherr <= " . " <= IO.newline();
            me.exit();
        }
    }
    10::ms => now;
}
