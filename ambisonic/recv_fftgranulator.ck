/*
    name: 'recv_ambigrani.ck'
    Author: Everett M. Carpenter, written Spring 2025
    Credits: Rob Hamilton, Ge Wang, Baek San Chang and Kyle Spratt -- The sound source used in this script is a modification of Spratt's 'granular.ck'
    
    #----- [HOW TO USE] -----#
    This is the recieving end of an OSC communication pair. Simply launch this script along with it's partner 'send_ambigrani.ck'
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
    If you have 4 granulators in a perpendicular fashion, set the "mode" variable to "0" and they will be assigned in a "cross" formation, if you want an "X" formation, set the "mode" to "1".
    If you have 2 granulators, they will be assigned to "4" and "6".
    If you would like to edit a parameter of a specific granulator, hold down it's num pad key and the keyboard will act as a control on that granulator. You can edit more than only granulator at a time. 
    If you would like to edit ALL granulators, hold down "5". The "*" key edits "7" & "9" (diagonal to "5") and "+" edits "8" and "6" (perpendicular to "5").

    If you wish to modify this script, each variable, class, UGen, Event or function is labelled, so hot-rodding this script should be easy. 

    Direct any questions to carpee2 @ rpi.edu

*/

@import "granular_class.ck"
@import "granular_support.ck"

// instantiation
int nGrans; // number of desired grains (specified in command line)
int mode; // 0 if perpendicular quad setup 1 if angled quad setup
float cursorLocation[2];
second / samp => float srate; // get the sample rate
string filename; // audio file used as source
string hostname; // address to recieve OSC messages
int port; // port to recieve OSC messages
0 => int device; // where are you getting HID messages
Hid hi; // keyboard 
HidMsg msg; // keyboard reader
OscIn mailBox[4]; // recieves OSC messages
OscMsg letterOpener; // OSC reader

int keyArray[8]; // stores the current granulator you want to edit

Event ready; // confirms everything is ready

// check the command line
if( !me.args() || me.args() == 2 ) // take arguments
{
    cherr <= "Input required, format is [audiofile]:[howmany]:[hostname]:[port]" <= IO.newline()
          <= "If no port specified, default to 6449";
    me.exit();
}
else if( me.args() == 3 )
{
    me.arg(0) => filename;
    me.arg(1) => Std.atoi => nGrans;
    me.arg(2) => hostname;
    6449 => port;
}
else if( me.args() == 4 )
{
    me.arg(0) => filename;
    me.arg(1) => Std.atoi => nGrans;
    me.arg(2) => hostname;
    me.arg(3) => Std.atoi => port;
}

// state you're address
for( auto x : mailBox ) // set your port for OSC
{
    port => x.port; // set port
}

GranularSupport assistant;
Granulator grain(filename)[nGrans];
FFT fft[nGrans];
Gain sum(1.0/nGrans)[nGrans];
Event sync[nGrans];

for(int i; i < fft.size(); i++)
{
    1024 => fft[i].size;
}

// all the OSC addresses
mailBox[0].addAddress("/keypresses/down");
mailBox[1].addAddress("/keypresses/up");
mailBox[2].addAddress("/trackpad/x");
mailBox[3].addAddress("/trackpad/y");

fun void spectrum(FFT n_fft, Granulator n_gran)
{
    n_gran => n_fft => blackhole;
    Event go;
    spork ~ printFFT(n_fft, go);
    while(true)
    {
        n_fft.size()*0.5::samp => now;
        n_fft.upchuck();
        go.broadcast();
    }
}

fun void printFFT(FFT m_fft, Event m_go )
{
    polar temp;
    while(true)
    {
        m_fft.size()::ms => now;
        m_go => now;
        for(int i; i < m_fft.size()*0.5; i++)
        {
            m_fft.cval(i) $ polar => temp;
            cherr <= temp.mag <= " ";
            if(i == ((m_fft.size()*0.5)-1)) cherr <= IO.newline();
        }
    }
}

fun void keyOnListen() // listens to the stream of keypresses down
{
    int key;
    while( true )
    {
        // wait for mail
        mailBox[0] => now;

        // did you get mail?
        while( mailBox[0].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getInt(i) => key;
                for(int i; i < grain.size(); i++)
                {
                    if( keyArray[i] != 0 )
                    {
                        // cherr <= ".key called" <= IO.newline();
                        assistant.key(key, grain[i]);
                    }
                }
                if( key <= 97 && key >= 84 ) spork ~ arrayOnChanger(key);
                // print them out
                // cherr <= key <= " on" <= IO.newline();
            }
        }
    }
}

fun void keyOffListen() // listens to the stream of keylifts up
{
    int key;
    while( true )
    {
        // wait for mail
        mailBox[1] => now;

        // did you get mail?
        while( mailBox[1].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getInt(i) => key;
                if( key <= 97 && key >= 84 ) spork ~ arrayOffChanger(key);
                // print them out
                // cherr <= key <= " off" <= IO.newline();
            }
        }
    }
}

fun void mouseXListen() // listens to the stream of trackpad x position
{
    float mouseX;
    while( true )
    {
        // wait for mail
        mailBox[2] => now;

        // did you get mail?
        while( mailBox[2].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => cursorLocation[0];
            }
            for(int i; i < grain.size(); i++)
            {
                if( keyArray[i] != 0 )
                {
                   assistant.mouse(cursorLocation, grain[i]);
                }
            }
        }
    }
}

fun void mouseYListen() // listens to the stream of trackpad y position
{
    float mouseY;
    while( true )
    {
        // wait for mail
        mailBox[3] => now;

        // did you get mail?
        while( mailBox[3].recv(letterOpener) )
        {
            for( int i; i < letterOpener.numArgs(); i++ )
            {
                letterOpener.getFloat(i) => cursorLocation[1];
                // print them out
                // cherr <= mouseY <= " mouse y" <= IO.newline();
            }
            for(int i; i < grain.size(); i++)
            {
                if( keyArray[i] != 0 )
                {
                   assistant.mouse(cursorLocation, grain[i]);
                }
            }
        }
    }
}

fun void arrayOnChanger(int key)
{
    if( nGrans == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) (key-94) => keyArray[(key-95)];
        else if( key == 92 ) 8 => keyArray[7];
        else if( key == 94 ) 4 => keyArray[3];
        else if( key <= 91 && key >= 89 ) (-1 * key) + 96 => keyArray[(-1 * key) + 95];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 85 ) [1,0,3,0,5,0,7,0] @=> keyArray;// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) [0,2,0,4,0,6,0,8] @=> keyArray;// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( nGrans == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) (key-95) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 94 ) (key-92) => keyArray[1];
        else if( key == 90 ) (key-87) => keyArray[2];
        else if( key == 92 ) (key-88) => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) (key-94) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 97 ) (key-95) => keyArray[1];
        else if( key == 91 ) (key-98) => keyArray[2];
        else if( key == 89 ) (key-85) => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) (key-91) => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {i+1 => keyArray[i];} // key 5 edits all GPS at once
        else if ( key == 94 ) (key-92) => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

fun void arrayOffChanger(int key)
{
    if( nGrans == 8 ) // 8 speakers
    {
        if( key <= 97 && key >= 95 ) 0 => keyArray[(key-95)];
        else if( key == 92 ) 0 => keyArray[7];
        else if( key == 94 ) 0 => keyArray[3];
        else if( key <= 91 && key >= 89 ) 0 => keyArray[(-1 * key) + 95];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 85 ) keyArray.zero();// key * edits all GPS DIAGONAL to listener 
        else if( key == 87 ) keyArray.zero();// key + edits all GPS ADJACENT to listener
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3], keyArray[4], keyArray[5], keyArray[6], keyArray[7] >>>;
    }
    else if( nGrans == 4 && mode == 0 ) // if perpendicular speaker arrangment
    {
        if( key == 96 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 94 ) 0 => keyArray[1];
        else if( key == 90 ) 0 => keyArray[2];
        else if( key == 92 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 4 && mode == 1 ) // if angled speaker arrangment
    {
        if( key == 95 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if( key == 97 ) 0 => keyArray[1];
        else if( key == 91 ) 0 => keyArray[2];
        else if( key == 89 ) 0 => keyArray[3];
        <<< keyArray[0], keyArray[1], keyArray[2], keyArray[3] >>>;
    }
    else if( nGrans == 2 ) // stereo or 2 granulators
    {
        if( key == 92 ) 0 => keyArray[0];
        else if( key == 93 ) for( int i; i < keyArray.size(); i++ ) {0 => keyArray[i];} // key 5 edits all GPS at once
        else if ( key == 94 ) 0 => keyArray[1];
        <<< keyArray[0], keyArray[1] >>>;
    }
}

// spork off OSC recievers
spork ~ keyOnListen();
spork ~ keyOffListen();
spork ~ mouseXListen();
spork ~ mouseYListen();

for(int i; i < grain.size(); i++)
{
    spork ~ spectrum(fft[0], grain[0]);
    grain[i].play();
    grain[i] => sum[i] => dac;
    1 => assistant.print;
}

// open keyboard 
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// print your identity
cherr <= "Your name is " <= hostname <= IO.newline()
      <= "You're getting mail on port " <= port <= IO.newline();


// go!
while( true ) // the main thread is simply responsible for when to close, it just sits and waits for you to press the esc key
{
    hi => now;
    while( hi.recv( msg ))
    {
        if( msg.isButtonDown() )
        { 
            // get out of here (escape)
            if( msg.ascii == 27 )
            {
                cherr <= "exiting the Dopethrone" <= IO.newline();
                400::ms => now;
                me.exit();
            }
        }
    }
    10::ms => now;
}