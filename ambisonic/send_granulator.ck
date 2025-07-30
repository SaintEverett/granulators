/*
    name: 'send_ambigrani.ck'
    Author: Everett M. Carpenter, written Spring 2025
    Credits: Rob Hamilton, Ge Wang, Baek San Chang and Kyle Spratt -- The sound source used in this script is a modification of Spratt's 'granular.ck'
    
    #----- [HOW TO USE] -----#
    This is the send  end of an OSC communication pair. Simply launch this script along with it's partner 'recv_ambigrani.ck'
    This script will recieve control data from the other end of the OSC pipe. Just ensure they are sending and recieving on the same address.
    To see the arguments required for this script, attempt to run it in MiniAudicle or the cmd line. 
    #------------------------#

    This script acts as an audio source and ambisonic processor (encoder and decoder). The sound source is a granulator controlled by the keyboard and mouse. 
    Controls for the granulator are as follows...

        "`1234567890" row -- This row is for where the "play head" of the granulator is located in the file. "`" is the beginning of the file, where the further to the right being later in the file.
        "QWERTYUIOP" row -- This row controls the randomization of grain position in the audio file, with the magnitude of randomization increasing the further you go towards "P".
        "ASDFGHJKL" row -- This row controls the pitch of the grains, with "A" being 0.000083, "S" being 0.25, then 0.5, 0.75,1,2,4,6,8,16 respectively.
        "ZXCVBNM" row -- This row is the randomization of grain pitch, following the same route as the QWERTY row, with randomization increasing as you move to the right.
        "-=" -- "=" steps forward in the audio file, where "-" steps backwards.
        "[]" -- incremental control of randomized position.
        ";'" -- incremental control of the pitch. 
        ",." -- incremental control of randomized pitch.
        "ENTER" and right "SHIFT" -- ENTER increases randomized grain length, and SHIFT reduces it.
        "TAB" and left "SHIFT" -- TAB increases reverb mix, and SHIFT reduces it.
        left "ALT" -- activates a "spacer" which places randomized gaps in between grains (works well with long grain sizes)
        "↑↓←→" (arrow keys) -- control the direction & height velocities of the ring of granulators, where left arrow increases, right decreases (negative velocities supported) and the same with up and down (up positive, down negative).
        "Cursor X-Axis" -- the x-axis placement of the cursor controls the grain size. (Only active when a granulator is selected)
        "Cursor Y-Axis" -- the y-axis placement controls the volume of the granulator. (Only active when a granulator is selected)

    When launching this script, you will specify whether you want 2 or 4 granulators (the second argument appropriately titled "howMany"). 
    If you have 8 channels, the granulators should be assigned in a circular motion around your num pad. 
    If you have 4 channels in a perpendicular fashion, set the "mode" variable to "0" and they will be assigned in a "cross" formation.
    If you have 4 channels in an angled fashion, set the "mode" variable to "1" and they will be assigned in a "X" formation.
    If you have 2 channels, they will be assigned to "4" and "6".
    If you would like to edit a parameter of a specific granulator, hold down it's num pad key and the keyboard will act as a control on that granulator. You can edit more than only granulator at a time. 
    If you would like to edit ALL granulators, hold down "5". The "*" key edits "7" & "9" (diagonal to "5") and "+" edits "8" and "6" (perpendicular to "5").

    If you wish to modify this script, each variable, class, UGen, Event or function is labelled, so hot-rodding this script should be easy. 

    Direct any questions to carpee2 @ rpi.edu

*/

// instantiation
OscOut mailMan[4]; // send out 
Hid hi; // keyboard
HidMsg msg; // keyboard decrypt
Event move; // more sync
// identify yourself
string address; // OSC address
int port; // OSC port

// device #
0 => int device; // hid device

if( !me.args() ) 
{
    cherr <= "Input required, format is [address]:[port]:[hid]" <= IO.newline()
          <= "If no host specified, default to Meursault" <= IO.newline()
          <= "If no port specified, default to 6449" <= IO.newline()
          <= "If no HID specified, default to 0";
    me.exit();
}
else if( me.args() == 1 )
{
    "Meursault" => address;
    6449 => port;
}
else if( me.args() == 2 )
{
    me.arg(0) => address;
    6449 => port;
}
else if( me.args() == 3 )
{
    me.arg(0) => address;
    me.arg(1) => Std.atoi => port;
}
else if( me.args() == 4 )
{
    me.arg(0) => address;
    me.arg(1) => Std.atoi => port;
    me.arg(2) => Std.atoi => device;
}

// print your identity
cherr <= "You're sending mail to " <= address <= IO.newline()
      <= " on port " <= port <= IO.newline();

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
cherr <= "keyboard '" <= hi.name() <= "' ready" <= "" <= IO.newline();

for( int i;i < mailMan.size(); i++ )
{
    mailMan[i].dest(address,port);
}

fun void shipHID()
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

spork ~ shipHID();
spork ~ trackpadTracker();

while( true )
{
    if( msg.isButtonDown() )
    {
        if( msg.ascii == 27 )
        {
            cherr <= IO.newline() <= "exiting";
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
