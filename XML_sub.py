#FILE XML   
import os
import xml.etree.ElementTree as ET
import SimpleITK as sitk
import numpy as np
import glob
import tensorflow as tf


def write_image(read,write,filetosave):

    reader = sitk.ImageFileReader()
    reader.SetImageIO("MetaImageIO")
    reader.SetFileName(read)
    refImage = reader.Execute()
    writer = sitk.ImageFileWriter()
    writer.SetFileName(write)
    imageNp = np.moveaxis(filetosave, 2, 0)
    imageSitk = sitk.GetImageFromArray(imageNp)
    origin = [refImage.GetOrigin()[0], refImage.GetOrigin()[1], refImage.GetOrigin()[2]]
    # origin = [-255.5, -135.5, -255.5]
    imageSitk.SetOrigin(origin)
    spacing = [refImage.GetSpacing()[0], refImage.GetSpacing()[1], refImage.GetSpacing()[2]]
    # spacing = [1.0, 1.0, 1.0]
    imageSitk.SetSpacing(spacing)
    direction = refImage.GetDirection()
    # direction = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    imageSitk.SetDirection(direction)
    writer.Execute(imageSitk)

def load(fileName):
    reader = sitk.ImageFileReader()#reads an image file and returns an SItkimage
    reader.SetImageIO("MetaImageIO")
    reader.SetFileName(fileName)
    imageSitk = reader.Execute()
    imageNp = sitk.GetArrayViewFromImage(imageSitk)
    imageNp = np.moveaxis(imageNp, 0, 2)
    tensorImg = tf.convert_to_tensor(imageNp, dtype=tf.float32)

    return tensorImg

# Input and output filenames
path = 'D:\\gate\\geos\\'
input_file = os.path.join(path, "gGeometry_H1.xml")
output_file = os.path.join(path, "gGeometry_H1sub10_prova.xml")

tree = ET.parse(input_file)
root = tree.getroot()

subsampled = []
projections = root.findall("Projection")
for i in range(0,len(projections),10):
    if i != 0:
        subsampled.append(projections[i-1])
    else:
        subsampled.append(projections[i])

subsampled.append(projections[-1])

for proj in projections:
    root.remove(proj)

for proj in subsampled:
    root.append(proj)

ET.indent(tree, space="  ")
tree.write(output_file, encoding="utf-8", xml_declaration=True)

print(f"Saved subsampled XML ({len(subsampled)} projections) to {output_file}")



#PUT HF VOLUMES TOGETHER

path = 'D:\\gate\\volumes\\'

volume=glob.glob(path + '*.mha')
vol1=load(volume[0])
vol2=load(volume[1])

sum= vol1+vol2
sum = sum/2

write_image(volume[0], os.path.join(path,'ct_all.mha'), sum)
