public class OscHID 
{
    4536 => int port;
    int lastKeyOn;
    int lastKeyOff;
    float lastMouseX;
    float lastMouseY;
    0.5 => float sens;
    int lastMsgType; // 0 keyOn, 1 keyOff, 2 mouseX, 3 mouseY
    Event signal;

    fun void OscHID(int n_port)
    {
        n_port => port;
        spork ~ listenKeyOn();
        spork ~ listenKeyOff();
        spork ~ listenMouseX();
        spork ~ listenMouseY();
    }

    fun void listenKeyOn()
    {
        OscIn keyOn;
        OscMsg kOmsg;
        port => keyOn.port;
        keyOn.addAddress("/keypresses/down");
        while( true )
        {
            keyOn => now;
            while( keyOn.recv(kOmsg) )
            {
                kOmsg.getInt(0) => lastKeyOn;
            }
            0 => lastMsgType;
            signal.broadcast();
        }
    }

    fun void listenKeyOff()
    {
        OscIn keyOff;
        OscMsg kOmsg;
        port => keyOff.port;
        keyOff.addAddress("/keypresses/up");
        while( true )
        {
            keyOff => now;
            while( keyOff.recv(kOmsg) )
            {
                kOmsg.getInt(0) => lastKeyOff;
            }
            1 => lastMsgType;
            signal.broadcast();
        }
    }

    fun void listenMouseX()
    {
        OscIn mouseX;
        OscMsg mOmsg;
        port => mouseX.port;
        mouseX.addAddress("/trackpad/x");
        while( true )
        {
            mouseX => now;
            while( mouseX.recv(mOmsg) )
            {
                mOmsg.getFloat(0) * sens => lastMouseX;
            }
            2 => lastMsgType;
            signal.broadcast();
        }
    }

    fun void listenMouseY()
    {
        OscIn mouseY;
        OscMsg mOmsg;
        port => mouseY.port;
        mouseY.addAddress("/trackpad/y");
        while( true )
        {
            mouseY => now;
            while( mouseY.recv(mOmsg) )
            {
                mOmsg.getFloat(0) * sens => lastMouseY;
            }
            3 => lastMsgType;
            signal.broadcast();
        }
    }
}