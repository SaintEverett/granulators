/*
    name: recv_granular_nchan.ck
    authors: 
        original: Kyle Spratt (Spring 2008, Stanford Laptop Orchestra)
        modified: Baek San Chang (Spring 2008)
        modified: Rob Hamilton (Spring 2009)
        modified: Ge Wang (Spring 2009)
        modified: Everett Carpenter (Spring 2025)
    
    #----- [HOW TO USE] -----#
    This is the sending end of an OSC communication pair. To send controls from this script, launch it's partner 'recv_granu_nchan.ck'. 
    Make sure they are sending and recieving on the same address and all should be good. 
    This script will show you the arguments required when you try to run it in MiniAudicle or the cmd line. 
    #------------------------#

    This is an adaptation of Kyle Spratt's "granular.ck" script, a simple granular synth with typical parameters and adjustable randomization.
    This script takes the # of addressable DAC channels and populates a granulator across each one. Granulators are accessed via the numpad, with each instance assigned to a number.
    If you have 8 channels, the granulators should be assigned in a circular motion around your num pad. 
    If you have 4 channels in a perpendicular fashion, set the "mode" variable to "0" and they will be assigned in a "cross" formation.
    If you have 4 channels in an angled fashion, set the "mode" variable to "1" and they will be assigned in a "X" formation.
    If you have 2 channels, they will be assigned to "4" and "6".
    The various parameters regarding the sound of the granualator, are stored in a class that is defined below, the GPS (Granular Parameter Storage).
    When you edit parameters of a GPS, that is what you are editing, each granulator has a unique GPS and ID. This allows the granulator to read the parameters of a certain GPS, and only that GPS.
    Enjoy! 

    Reach out with any questions at carpee2@rpi.edu

*/

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
          <= "If no HID specified, default to 0";
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
                if( mmsg.deltaX < 1 || mmsg.deltaX > -1 )
                {
                    mailMan[2].start("/trackpad/x");

                    mmsg.scaledCursorX => mailMan[2].add;

                    mailMan[2].send();

                }

                if( mmsg.deltaY < 1 || mmsg.deltaY > -1 )
                {
                    mailMan[3].start("/trackpad/y");

                    1 - mmsg.scaledCursorY => mailMan[3].add;

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
