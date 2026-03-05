import os
import argparse
import math
import itk
from itk import RTK as rtk
import numpy as np
import sys

from numpy import angle

#if sys.version_info.major == 3 and sys.version_info.minor == 8:
#    os.add_dll_directory("C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v10.1/bin")


parser = argparse.ArgumentParser(description='interpolate between subsampled scatter simulated points')
parser.add_argument('geofn', help='filename for full geometry .xml', default='')
parser.add_argument('subgeofn', help='filename for subsampled geometry .xml', default='')

def interpolate(z1, z2, idx1, idx2, idxnew, subangles, angles):
    if subangles[idx1] == subangles[idx2]:
        # no interpolation needed, just take z1 (or z2, they should be the same index)
        return np.expand_dims(z1, axis=0).astype(np.single)

    perc = (angles[idxnew] - subangles[idx1]) / (subangles[idx2] - subangles[idx1])
    zest = z1 + (z2 - z1) * perc
    return np.expand_dims(zest, axis=0).astype(np.single)

def main():   
    args = parser.parse_args() 
    print("Current working directory:", os.getcwd())

    rescaleddir = [filename for filename in os.listdir('.') if filename.startswith("secondary_rescaled")]
    print("Rescaled folder(s):", rescaleddir)
    if not rescaleddir:
        print("No folder starting with 'secondary_rescaled' found")
        exit(1)

    rescaledfns = [filename for filename in os.listdir(rescaleddir[0]) if filename.startswith("secondary")] # list file names in rescaleddir that start with "secondary"
    print("Found", len(rescaledfns), "files in", rescaleddir[0])

    if not rescaledfns:
        print("No 'secondary...' files found inside", rescaleddir[0])
        exit(1)
    # maindir = os.listdir('.')
    rescaleddir = [filename for filename in os.listdir('.') if filename.startswith("secondary_rescaled")]
    rescaledfns = [filename for filename in os.listdir(rescaleddir[0]) if filename.startswith("secondary")]
    outputdir = ".//secondary_interpolated"

    rescaledfns.sort() # order files in rescaled directory
    print(rescaledfns)

    if not os.path.exists(outputdir):
        os.mkdir(outputdir)
    # print(rescaledfns)
    totinput = np.zeros((len(rescaledfns),1024,768)) # 1024, 768 = resolution detector primary/attenuation volumes
    for ii in range(0,len(rescaledfns)):
        # input[ii] = itk.Image(itk.F,2)
        input = itk.imread(rescaleddir[0]+'//'+rescaledfns[ii])
        inputarray = itk.array_from_image(input)
        # print(np.shape(input))
        totinput[ii]=inputarray
    print(np.shape(totinput))

    readerfull = rtk.ThreeDCircularProjectionGeometryXMLFileReader.New()
    readerfull.SetFilename(args.geofn)
    readerfull.GenerateOutputInformation()

    fullGeo = readerfull.GetOutputObject()
    angles = fullGeo.GetGantryAngles()

    reader = rtk.ThreeDCircularProjectionGeometryXMLFileReader.New()
    reader.SetFilename(args.subgeofn)
    reader.GenerateOutputInformation()

    subGeo = reader.GetOutputObject()
    subangles= subGeo.GetGantryAngles()

    print(len(angles), len(subangles))

    resto = len(angles)%10

    for ii in range(0,len(angles)-resto,1):#-resto
        
        # choosing the correct secondary (one secondary for the same 10 primaries)
        # Interpolate between two consecutive secondary images to generate
        # scatter estimates for each of the 10 corresponding primary projections.
        nsecondary = int(math.floor(ii/10)) # e.g. for ii in 0, 9 --> nsecondary = 0 --> for the first 10 primaries, 
        # the corresponding secondaries will be the interpolation between secondary 0 and secondary 1
        tmparray=interpolate(totinput[nsecondary,:,:], totinput[nsecondary+1,:,:],nsecondary,nsecondary+1,ii,subangles,angles)
        outfn = f"{outputdir}//secondary{ii:04}.mha"
        print(outfn)
        tmp = itk.image_from_array(tmparray)
        tmp.CopyInformation(input)
        itk.imwrite(tmp,filename=outfn)
    
    #IF EVEN
    for ii in range(len(angles)-resto, len(angles),1):#-resto
        tmparray = np.expand_dims(totinput[-1,:,:], axis=0).astype(np.single)
        outfn = f"{outputdir}//secondary{ii:04}.mha"
        print(outfn)
        tmp = itk.image_from_array(tmparray)
        tmp.CopyInformation(input)
        itk.imwrite(tmp,filename=outfn)


    # outfn = f"{outputdir}\\secondary{ii+1:04}.mha"
    # tmp = itk.image_from_array(np.expand_dims(totinput[nsecondary+1,:,:],axis=0).astype(np.single))
    # tmp.CopyInformation(input)
    # itk.imwrite(tmp,filename=outfn)
    
    # for ii in range(len(angles)-resto,len(angles),1):#500
    #     nsecondary = int(math.floor(ii/10))
    #     tmparray=interpolate(totinput[nsecondary,:,:], totinput[nsecondary+1,:,:],nsecondary,nsecondary+1,ii,subangles,angles)
    #     outfn = f"{outputdir}//secondary{ii:04}.mha"
    #     print(outfn)
    #     tmp = itk.image_from_array(tmparray)
    #     tmp.CopyInformation(input)
    #     itk.imwrite(tmp,filename=outfn)

    # for ii in range(469,940,1):
    #     #choosing the correct secondary (one secondary for the same 10 primaries)
    #     nsecondary = int(math.floor(ii/10))
    #     tmparray=interpolate(totinput[nsecondary,:,:], totinput[nsecondary+1,:,:],nsecondary,nsecondary+1,ii,subangles,angles)
    #     outfn = f"{outputdir}\\secondary{ii:04}.mha"
    #     print(outfn)
    #     tmp = itk.image_from_array(tmparray)
    #     tmp.CopyInformation(input)
    #     itk.imwrite(tmp,filename=outfn)

if __name__ == "__main__":
    main()