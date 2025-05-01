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

    If you wish to modify this script, each variable, class, UGen, Event or function is labelled, so hot rodding this script should be easy. 

    Direct any questions to carpee2 @ rpi.edu

*/
// instantiation
OscOut mailMan[7]; // send out 
Hid hi; // keyboard
HidMsg msg; // keyboard decrypt
Event wakeUp; // coordination
Event startShipping; // sync when to ship
Event move; // more sync
// identify yourself
string address; // OSC address
int port; // OSC port
int nGrans; // how many things to compute
["X","Y","Z","W","R","S","T","U","V"] @=> string coordinateMarkers[]; // simply for print messages
// device #
0 => int device; // hid device
// hardcoded speaker angles, adjust if needed.
[45.0,0.0,-315.0,-270.0,-225.0,-180.0,-135.0,-90.0] @=> float speakAngles[]; // SPEAKER ANGLES
float speakCoeff[8][9]; // eight speakers, each have nine coefficients

if( !me.args() ) 
{
    cherr <= "Input required, format is [nGrans]:[address]:[port]:[hid]" <= IO.newline()
          <= "If no host specified, default to Meursault" <= IO.newline()
          <= "If no port specified, default to 6449" <= IO.newline()
          <= "If no HID specified, default to 0";
    me.exit();
}
else if( me.args() == 1 )
{
    me.arg(0) => Std.atoi => nGrans;
    "Meursault" => address;
    6449 => port;
}
else if( me.args() == 2 )
{
    me.arg(0) => Std.atoi => nGrans;
    me.arg(1) => address;
    6449 => port;
}
else if( me.args() == 3 )
{
    me.arg(0) => Std.atoi => nGrans;
    me.arg(1) => address;
    me.arg(2) => Std.atoi => port;
}
else if( me.args() == 4 )
{
    me.arg(0) => Std.atoi => nGrans;
    me.arg(1) => address;
    me.arg(2) => Std.atoi => port;
    me.arg(3) => Std.atoi => device;
}

float myAmbi[nGrans][9]; // multi dimensional array of coordinates
                         // each row is a GPS and each entry is a coordinate
float tempArray[9];
float myDirection;
float myHeight;
float directionVel;
float heightVel;
float myAngles[][]; // float myAngles[nGrans][2]; // each row is a GPS and each entry is an angle
if( nGrans == 2 )
{
    [ 
        [90.0,0.0],
        [270.0,0.0] 
    ] @=> myAngles;
    for( int i; i < myAngles.size(); i++ )
    {
        cherr <= myAngles[i][0] <= " " <= myAngles[i][1] <= IO.newline();
    }
}
else if( nGrans == 4 )
{
    [ 
        [0.0,0.0],
        [90.0,0.0],
        [180.0,0.0],
        [270.0,0.0]
    ] @=> myAngles;
    for( int i; i < myAngles.size(); i++ )
    {
        cherr <= myAngles[i][0] <= " " <= myAngles[i][1] <= IO.newline();
    }
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
                if( msg.key == 75 || msg.key == 78 )
                {
                    if( msg.key == 78 )
                    {
                        0 => myHeight;
                        0 => heightVel;
                        wakeUp.signal();
                    }
                    else if( msg.key == 75 )
                    {
                        0 => myDirection;
                        0 => directionVel;
                        wakeUp.signal();
                    }
                }
                if( msg.key >= 79 && msg.key <= 82 )
                {
                    if( msg.key == 82 )
                    {
                        heightVel + ((heightVel/6)+0.0025) => heightVel;
                    }
                    else if( msg.key == 81 )
                    {
                        heightVel - ((heightVel/6)+0.0025) => heightVel;
                    }
                    else if( msg.key == 80 )
                    {
                        directionVel + ((directionVel/6)+0.0025) => directionVel;
                    }
                    else if( msg.key == 79 )
                    {
                        directionVel - ((directionVel/6)+0.0025) => directionVel;
                    }
                    cherr <= "Directional velocity: "  <= directionVel*1000 <= " | " <= "Elevation velocity: " <= heightVel*1000 <= IO.newline();
                }
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

fun void convAmbi()
{
        while( true )
        {
            wakeUp => now;
            // Convert P & Q to radians
            myDirection * (pi/180) => float P;
            myHeight * (pi/180) => float Q;
            // Calculate X
            (Math.cos(P))*(Math.cos(Q)) => tempArray[0];
            // Calculate Y
            (Math.sin(P))*(Math.cos(Q)) => tempArray[1];
            // Calculate Z
            (Math.sin(Q)) => tempArray[2];
            // Add W
            0.707 => tempArray[3];
            // Calculate R
            (Math.sin(2*Q)) => tempArray[4];
            // Calculate S
            (Math.cos(P) * Math.cos(2*Q)) => tempArray[5];
            // Calculate T
            (Math.sin(P)) * (Math.cos(2*Q)) => tempArray[6];
            // Calculate U
            (Math.cos(2*P)) - (Math.cos(2*P) * Math.sin(2*Q)) => tempArray[7];
            // Calculate V
            (Math.sin(2*P)) - (Math.sin(2*P) * Math.sin(2*Q)) => tempArray[8];

            // Original
            for( int i; i < tempArray.size(); i++ )
            {
                tempArray[i] => myAmbi[0][i];    
            }
            // Z, W, R
            for( int i; i < myAmbi.size(); i++ )
            {
                for( int j; j < 3; j++ )
                {
                    tempArray[j+2] => myAmbi[i][j+2];
                }
            }
            if( myAmbi.size() >= 2 )
            {
                // + 180
                tempArray[1] => myAmbi[1][0]; // Y => X
                (tempArray[0]*-1) => myAmbi[1][1]; // -X => Y
                tempArray[6] => myAmbi[1][5]; // T => S
                (tempArray[5]*-1) => myAmbi[1][6]; // -S => T
                (tempArray[7]*-1) => myAmbi[1][7]; // -U => U
                (tempArray[8]*-1) => myAmbi[1][8]; // -V => V
            }
            if( myAmbi.size() >= 4 )
            {
                // + 90
                (tempArray[1]*-1) => myAmbi[1][0]; // -Y => X
                tempArray[0] => myAmbi[1][1]; // X => Y
                (tempArray[6]*-1) => myAmbi[1][5]; // -T => S
                tempArray[5] => myAmbi[1][6]; // S => T
                tempArray[7] => myAmbi[1][7]; // U => U
                tempArray[8] => myAmbi[1][8]; // V => V
                // + 180
                tempArray[1] => myAmbi[2][0]; // Y => X
                (tempArray[0]*-1) => myAmbi[2][1]; // -X => Y
                tempArray[6] => myAmbi[2][5]; // T => S
                (tempArray[5]*-1) => myAmbi[2][6]; // -S => T
                (tempArray[7]*-1) => myAmbi[2][7]; // -U => U
                (tempArray[8]*-1) => myAmbi[2][8]; // -V => V
                // + 270
                (tempArray[0]*-1) => myAmbi[3][0]; // -X => X
                (tempArray[1]*-1) => myAmbi[3][1]; // -Y => Y
                (tempArray[5]*-1) => myAmbi[3][5]; // -S => S
                (tempArray[6]*-1) => myAmbi[3][6]; //-T => T
                tempArray[7] => myAmbi[3][7]; // U => U
                tempArray[8] => myAmbi[3][8]; // V => V
            }
            // ship it off
            startShipping.signal();
    }
}

fun void shipCoords()
{
    while( true )
    {
        startShipping => now;
        // coordinates
        mailMan[4].start("/sound/location/coordinates");
        for( int i; i < myAmbi.size(); i++ )
        {
            for( int j; j < myAmbi[0].size(); j++ )
            {
                myAmbi[i][j] => mailMan[4].add;
            }
        }
        mailMan[4].send();

        // angles
        mailMan[5].start("/sound/location/angles");
        for( int i; i < myAngles.size(); i++ )
        {
            myDirection + (360/myAngles.size())*i => mailMan[5].add;
            myHeight => mailMan[5].add;
        }
        mailMan[5].send();

        // cherr <= "sent!" <= IO.newline();
        10::ms => now;
    }
}

// speaker coefficients
fun void mySpeakerCoeffs()
{
    for( int i; i < speakCoeff.size(); i++ )
    {
        speakAngles[i] => float speakP; // add directional speaker angle to variable for calculations
        // Convert P to radians
        speakP * (pi/180) => speakP;
        0 => float speakQ; // elevation angle is 0 in our case
        // Calculate X
        (Math.cos(speakP))*(Math.cos(speakQ)) => float X;
        // Calculate Y
        (Math.sin(speakP))*(Math.cos(speakQ)) => float Y;
        // Calculate Z
        (Math.sin(speakQ)) => float Z;
        // Calculate R
        (Math.sin(2*speakQ)) => float R;
        // Calculate S
        (Math.cos(speakP) * Math.cos(2*speakQ)) => float S;
        // Calculate T
        (Math.sin(speakP)) * (Math.cos(2*speakQ)) => float T;
        // Calculate U
        (Math.cos(2*speakP)) - (Math.cos(2*speakP) * Math.sin(2*speakQ)) => float U;
        // Calculate V
        (Math.sin(2*speakP)) - (Math.sin(2*speakP) * Math.sin(2*speakQ)) => float V;
        // Store them in array
        X => speakCoeff[i][0];
        Y => speakCoeff[i][1];       
        Z => speakCoeff[i][2];
        0.707 => speakCoeff[i][3]; // W (pressure signal)
        R => speakCoeff[i][4];
        S => speakCoeff[i][5];
        T => speakCoeff[i][6];
        U => speakCoeff[i][7];
        V => speakCoeff[i][8];
    } 
    // coordinates
    mailMan[6].start("/speakers/coefficients");
    for( int i; i < speakCoeff.size(); i++ )
    {
        for( int j; j < speakCoeff[0].size(); j++ )
        {
            speakCoeff[i][j] => mailMan[6].add;
        }
    }
    mailMan[6].send();
    me.exit();
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

fun void directionVelocity()
{
    float deltaTheta;
    while( true )
    {
        directionVel * (now/second) => deltaTheta;
        myDirection + deltaTheta => myDirection;
        if( myDirection > 360.0 ) myDirection - 360.0 => myDirection;
        if( myDirection < 0 ) myDirection + 360.0 => myDirection;
        // <<< "velocity: " , directionVel, " theta: ", Math.cos(myDirection) >>>;
        wakeUp.signal();
        100::ms => now;
    }
}

fun void heightVelocity()
{
    float deltaPsi;
    while( true )
    {
        heightVel * (now/second) => deltaPsi;
        myHeight + deltaPsi => myHeight;
        if( myHeight > 360.0 ) myHeight - 360.0 => myHeight;
        if( myHeight < 0 ) myHeight + 360.0 => myHeight;
        // <<< "velocity: " , directionVel, " theta: ", Math.cos(myDirection) >>>;
        100::ms => now;
    }
}

fun void printer()
{
    while( true )
    {
        cherr <= myDirection <= " | " <= myHeight <= IO.newline();
        1000::ms => now;
    }
}

spork ~ directionVelocity();
spork ~ heightVelocity();
spork ~ shipHID();
spork ~ shipCoords();
spork ~ mySpeakerCoeffs();
spork ~ trackpadTracker();
spork ~ convAmbi();
spork ~ printer();

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
