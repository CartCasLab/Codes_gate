import glob
import os 
import SimpleITK as sitk
import tensorflow as tf
import numpy as np

def load(fileName):
    reader = sitk.ImageFileReader()#reads an image file and returns an SItkimage
    reader.SetImageIO("MetaImageIO")
    reader.SetFileName(fileName)
    imageSitk = reader.Execute()
    imageNp = sitk.GetArrayViewFromImage(imageSitk)
    imageNp = np.moveaxis(imageNp, 0, 2)
    tensorImg = tf.convert_to_tensor(imageNp, dtype=tf.float32)
 
    return tensorImg

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
    # origin = [-199.5, -199.5, -199.5]
    imageSitk.SetOrigin(origin)
    spacing = [refImage.GetSpacing()[0], refImage.GetSpacing()[1], refImage.GetSpacing()[2]]
    # spacing = [1.0, 1.0, 1.0]
    imageSitk.SetSpacing(spacing)
    direction = refImage.GetDirection()
    # direction = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    imageSitk.SetDirection(direction)
    writer.Execute(imageSitk)


#PUT HF VOLUMES TOGETHER

path = '/mnt/ext1/fcasaccio/1_mha_data/ES/test1'
path1 = '/mnt/ext1/fcasaccio/1_mha_data/ES/test1/simCBCT_1_512.mha'
path2 = '/mnt/ext1/fcasaccio/1_mha_data/ES/test1/simCBCT_2_512.mha'
 
# volume=glob.glob(path + '*.mha')
# vol1=load(volume[0])
# vol2=load(volume[1])

vol1 = load(path1)
vol2 = load(path2)
 
sum= vol1+vol2
sum = sum/2
 
write_image(path1, os.path.join(path,'ct_all.mha'), sum)