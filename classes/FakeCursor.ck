public class FakeCursor 
{
    Hid mouse;
    HidMsg mmsg;
    float cursorX;
    float cursorY;
    float scrollWheel;
    [0.0, 0.0, 0.0] @=> float state[];
    0.0001 => float sens;

    fun void FakeCursor()
    {
        if( !mouse.openMouse( 0 ) ) me.exit();
        cherr <= "FakeCursor: trackpad/mouse '" <= mouse.name() <= "' ready" <= "" <= IO.newline();
        spork ~ update();
    }

    fun void FakeCursor(int device_n)
    {
        if( !mouse.openMouse( device_n ) ) me.exit();
        cherr <= "FakeCursor: trackpad/mouse '" <= mouse.name() <= "' ready" <= "" <= IO.newline();
        spork ~ update();
    }

    fun void update()
    {
        while( true )
        {    
            20::ms => now;    
            while( mouse.recv( mmsg ) )
            {
                if( mmsg.isMouseMotion() )
                {
                    if(Math.fabs(mmsg.deltaX) > 60) Math.clampf(state[0] - sens * 5.0 * mmsg.deltaX, 0.0, 1.0) => cursorX => state[0];
                    else Math.clampf(state[0] - sens * mmsg.deltaX, 0.0, 1.0) => cursorX => state[0];
                    if(Math.fabs(mmsg.deltaY) > 60) Math.clampf(state[1] - sens * 5.0 * mmsg.deltaY, 0.0, 1.0) => cursorY => state[1];
                    else Math.clampf(state[1] - sens * mmsg.deltaY, 0.0, 1.0) => cursorY => state[1];
                }
                else if( mmsg.isWheelMotion() )
                {
                    Math.clampf(state[2] - sens * (mmsg.deltaY), 0.0, 1.0) => scrollWheel => state[2];
                }
            }
        }
    }

    fun float x()
    {
        return cursorX;
    }

    fun float y()
    {
        return cursorY;
    }

    fun float scroll()
    {
        return scrollWheel;
    }
}