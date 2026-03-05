#!/bin/bash -x
#SBATCH --nodes=1                   # nombre de noeude
#SBATCH --ntasks-per-node=1         # nombre de taches MPI par noeud
#SBATCH --time=20:00:00             # temps d execution maximum demande (HH:MM:SS)
#SBATCH --output=Seq%j.out       # nom du fichier de sortie
#SBATCH --error=Seq%j.out        # nom du fichier d'erreur (ici en commun avec la sortie)

gate_power_merge.sh .
