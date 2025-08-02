public class Spectra
{
    float highAvg[];
    float lowAvg[];
    polar magphas[];
    float flux[];
    float centroid;

    fun void Spectra(int size)
    {
        size => highAvg.size => lowAvg.size => magphas.size => flux.size;
    }
}