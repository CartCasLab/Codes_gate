import itk
import numpy as np
import argparse

parser = argparse.ArgumentParser(description = 'Align CBCT to CT')
group = parser.add_mutually_exclusive_group()
group.add_argument('--ct', help = 'add this if you want to move from CT to CBCT', action = 'store_true')
group.add_argument('--cb', help = 'add this if you want to move from CBCT to CT', action = 'store_true')
parser.add_argument('fn', metavar = 'filename.mha', help = 'file .mha to be aligned', default='')
parser.add_argument('--iso', help = 'add the iso.txt to perform a traslation')

args = parser.parse_args()

def read_iso(txt):

    file = open(txt, 'r')
    line = file.readline()
    head, sep, line = line.partition('(')
    line = line.replace(')', "").replace(',', "")

    iso = line.split()
    iso = [float(x) for x in iso]

    return iso


#read CBCT to be aligned
img = itk.imread(args.fn)
cb = itk.array_from_image(img)

#get image information
offset = img['origin']
spacing = img['spacing']
direction = img['direction']
size_cb = cb.shape

if args.ct:
    if args.iso:

        print('\nReading the iso coordinates...')
        iso = read_iso(args.iso)

        print('\nStart alignment...')
        orig = np.zeros(3)
        offset[0] = offset[0] - iso[2]
        offset[1] = offset[1] - iso[1]
        offset[2] = offset[2] - iso[0]

        orig[0] = offset[1] - 2*(size_cb[1]/2 + offset[1]/spacing[1])*spacing[1]
        orig[1] = offset[0] - 2*(size_cb[0]/2 + offset[0]/spacing[0])*spacing[0]
        orig[2] = offset[2]

        img['origin'] = orig
        img['spacing'] = spacing

    print('\nStart permutation...')
    cb_perm = cb.transpose((1, 0, 2)) #cbct from coronal to axial
    cb_perm = np.rot90(cb_perm, 2)  #180° rotation

    out = itk.image_from_array(cb_perm)
    out.CopyInformation(img)

    fn = str(args.fn)
    print('\nSaving the image as', fn)
    itk.imwrite(out, fn)

elif args.cb:
    if args.iso:

        print('\nReading the iso coordinates...')
        iso = read_iso(args.iso)

        print('\nStart alignment...')
        orig = np.zeros(3)
        orig[0] = iso[2] - (offset[1] + size_cb[1]*spacing[1]) # correct origin for Z axis
        orig[1] = iso[1] - (offset[0] + size_cb[0]*spacing[0]) # correct origin for Y axis
        orig[2] = iso[0] + offset[2] # correct origin for X axis

        tmp = spacing[0]
        spacing[0] = spacing[1]
        spacing[1] = tmp

        img['origin'] = orig
        img['spacing'] = spacing

    print('\nStart permutation...')
    #permute cbct
    cb_perm = cb.transpose((1, 0, 2)) #cbct from coronal to axial
    cb_perm = np.rot90(cb_perm, 2)  #180° rotation

    out = itk.image_from_array(cb_perm)
    out.CopyInformation(img)

    fn = str(args.fn)
    print('\nSaving the image as', fn)
    itk.imwrite(out, fn)
    print('\nDone')
