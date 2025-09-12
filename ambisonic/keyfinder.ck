Hid hi;
HidMsg msg;

// which keyboard
0 => int device;

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

while( true ) 
{
    hi => now;
    while( hi.recv( msg ))
    {
        if( msg.isButtonDown() )
        {
            <<< "down:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
            if( msg.ascii == 27 )
            {
                <<< "exiting!", "" >>>;
                me.exit();
            }
        }
    }
}