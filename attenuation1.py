import os
import itk
import numpy as np
import argparse

# This function computes the final projection as primary + secondary (scatter) (normalized w.r.t. the flatfield)

# Run from inside attenuation folder

parser = argparse.ArgumentParser(description='computes the final projection as primary + secondary')
parser.add_argument('primary_dir', help='name of primary folder', default='')
parser.add_argument('secondary_dir', help='name of secondary folder', default='')
args = parser.parse_args() 

parent = os.path.abspath(os.path.join(os.getcwd(), os.pardir)) 
# standard way to get the path of the parent directory w.r.t. the working directory (get main path)
# os.pardir is a constant string used by the operating system to refer to the parent directory
primary_path = os.path.abspath(os.path.join(parent, args.primary_dir))
secondary_path = os.path.abspath(os.path.join(parent, args.secondary_dir, "results//secondary_interpolated"))
flatfield_path = os.path.abspath(os.path.join(primary_path, 'flatField.mha'))

print(parent)
print(primary_path)
print(secondary_path)

# Read the images in input
primary = []
secondary = []
ff = itk.array_from_image(itk.imread(flatfield_path))

for file in os.listdir(primary_path):
	if file.startswith("primary"):
		primary.append(file)

for file in os.listdir(secondary_path):
	if file.startswith("secondary"):
		secondary.append(file)

primary.sort()
secondary.sort()

#print(secondary)
#print("\n")
#print(primary)

for i in range(len(primary)):
    print("\nNow processing:", primary[i], "and", secondary[i])

    prim = itk.array_from_image(itk.imread(primary_path + "//" + primary[i]))
    sec = itk.array_from_image(itk.imread(secondary_path + "//" + secondary[i]))

    eps = 1e-6  # stability constant

    # use abs to remove negative artifacts
    img_sum = np.sum([np.abs(prim), np.abs(sec)], axis=0)
    img_sum[img_sum <= 0] = eps

    img_int = ff / img_sum # compute normalized intensity with respect to the flatfield
    img_int[~np.isfinite(img_int)] = eps # 'isfinite' returns 1 for finite values, 0 for nan and +- inf values
    img_int[img_int <= 0] = eps

    img_log = np.log(img_int) # log as in Lambert-Beer law for CT reconstruction (-log(I/I0))
    img_log[~np.isfinite(img_log)] = 0  # replace any residual -inf or nan with 0

    if not np.isfinite(img_int).all():
        print("Warning: inf or NaN detected after flatfield operation.")
    if not np.isfinite(img_log).all():
        print("Warning: inf or NaN detected after log operation.")

    output = itk.image_from_array(img_log)
    output.CopyInformation(itk.imread(primary_path + "//" + primary[i]))
    itk.imwrite(output, "attenuation_F%s.mha" % str(i).zfill(4))
    print("Saved image n#", i + 1)
	
