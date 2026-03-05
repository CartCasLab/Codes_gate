#!/usr/bin/env sh

# rtkfdk -g data/gGeometry_H1.xml --pad 0.3 -r attenuation.*.mha -p primary1/ -o fdkBH_new1.mha -v --dimension  400 --hardware cuda
# rtkfdk -g data/gGeometry_H2.xml --pad 0.3 -r attenuation.*.mha -p primary2/ -o fdkBH_new2.mha -v --dimension  400 --hardware cuda


# FINAL RECONSTRUCTION ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

# Run from base env (in main folder)


rtkfdk -g data/gGeometry_H1.xml --pad 0.3 -r attenuation.*.mha -p attenuation1/ -o simCBCT_1_512.mha -v --dimension  512 --hardware cuda
rtkfdk -g data/gGeometry_H2.xml --pad 0.3 -r attenuation.*.mha -p attenuation2/ -o simCBCT_2_512.mha -v --dimension  512 --hardware cuda

# "--geometry", "-g", help="XML geometry file name", type=str, required=True
# "--output", "-o", help="Output file name", type=str, required=True
# "--hardware", help="Hardware used for computation", choices=["cpu", "cuda"], default="cpu"
# "--pad", help="Data padding parameter to correct for truncation", type=float, default=0.0
# "--path", "-p", help="Path containing projections", required=True
# "--regexp", "-r", help="Regular expression to select projection files in path", required=True

# -r '^attenuation[0-9]+\.mha$'