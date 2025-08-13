public class Spectra
{
    float highAvg[];
    float lowAvg[];
    polar magphas[];
    float flux[];
    float centroid;
    int size;

    fun void Spectra(int n_size)
    {
        n_size => size;
        size => highAvg.size => lowAvg.size => flux.size;
        size*2 => magphas.size;
    }
}