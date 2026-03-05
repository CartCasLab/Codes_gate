#!/usr/bin/env sh

# FIRST RUN THIS IN TERMINAL
# conda activate tf_15

which gt_image_arithm
which python

# Move to the main directory "main_dir" (change the name accordingly)
# main_dir/mac --> macros (ray, scatter, noscatter, verbose)
# main_dir/data --> CT, materials for GATE, geometry

main_dir="$(pwd)"
echo "main directory = $main_dir"

~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
# GEOM 1
# PRIMARY PROJECTIONS ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
echo "run noscatterHF_1.mac for primaries 1"
gate_split_and_run.py mac/noscatterHF_1.mac -j 1
# NB: gate_split_and_run.py returns immediately after submission, not after simulation! Must add something to wait. 

# Find the run dir and job name from the latest run.*/run.log
run_dir=$(ls -dt "$main_dir"/run.* 2>/dev/null | head -n 1)
job_name=$(awk '/^sbatch /{for(i=1;i<=NF;i++) if($i=="-J"){print $(i+1); exit}}' "$run_dir/run.log")

echo "Run dir: $run_dir"
echo "Slurm job name: $job_name"

# Get the job id (may take a moment to appear)
job_id=""
while [ -z "$job_id" ]; do
  job_id=$(squeue -h -n "$job_name" -o "%i" 2>/dev/null | head -n 1)
  sleep 2
done

echo "Job id: $job_id. Waiting for completion..."

# Wait until the job is gone from the queue
while squeue -h -j "$job_id" 2>/dev/null | grep -q .; do
  sleep 30
done

echo "Slurm job finished. Continuing."

found=0
for run_dir in "$main_dir"/run.*; do
    if [ ! -d "$run_dir" ]; then
    continue
    fi
    echo "Checking: $run_dir"
    output_dir="$(find "$run_dir" -type d -name 'output.*' -print -quit)"
    # search inside "$run_dir", -type d to look only at directories
    # matches directory names starting with "output."
    # the full path of the found folder is stored in 'output_dir'
    if [ -n "$output_dir" ]; then
        echo "FOUND output dir: $output_dir"
        echo "Renaming to: $run_dir/primary1"
        mv "$output_dir" "$run_dir/primary1"
        echo "Moving to: $main_dir/primary1"
        mv "$run_dir/primary1" "$main_dir/primary1"
        found=1
        break
    fi
done
for run_dir in "$main_dir"/run.*; do
    if [ ! -d "$run_dir" ]; then
    continue
    fi
    echo "Delete: $run_dir"
    rm -r "$run_dir"
done
 
SECONDARY PROJECTIONS ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
echo "run scatterHF_1.mac for secondaries 1"
gate_split_and_run.py mac/scatterHF_1.mac -j 10 -o scatter1

# NB: gate_split_and_run.py returns immediately after submission, not after simulation! Must add something to wait. 

out_root="$main_dir/scatter1"
logfile="$out_root/run.log"

# Extract job name from the sbatch line (-J ...)
job_name=$(awk '/^sbatch /{for(i=1;i<=NF;i++) if($i=="-J"){print $(i+1); exit}}' "$logfile")

echo "Output dir: $out_root"
echo "Slurm job name: $job_name"

# Optional: Ctrl-C cancels all jobs with that name
# trap 'echo "Interrupted. Cancelling Slurm jobs..."; scancel -n "$job_name"; exit 130' INT

# Wait until at least one job appears
echo "Waiting for Slurm jobs to appear..."
while ! squeue -h -n "$job_name" >/dev/null 2>&1; do
  sleep 2
done

# Wait until none remain
echo "Waiting for all $job_name jobs to finish..."
while squeue -h -n "$job_name" >/dev/null 2>&1; do
  sleep 15
done

echo "All jobs finished. Continuing."

cd scatter1

merge_slurm="/mnt/ext1/fcasaccio/1_mha_data/ES/gate_merge.slurm"
echo "submitted merge slurm"
submit_out=$(sbatch "$merge_slurm" 2>&1)

rc=$?

if [ $rc -ne 0 ]; then
  echo "sbatch failed: $submit_out" >&2
  exit $rc
fi

job_id=$(echo "$submit_out" | awk '/Submitted batch job/{print $NF}')
if [ -z "$job_id" ]; then
  echo "Could not parse JobID from sbatch output: $submit_out" >&2
  exit 1
fi

echo "Merge job submitted with JobID $job_id"

# trap 'echo "Interrupted."; echo "Cancelling merge job $job_id..."; scancel "$job_id"; exit 130' INT

echo "Waiting for merge job $job_id..."
while squeue -h -j "$job_id" >/dev/null 2>&1; do
  sleep 2
done

echo "Merge job finished."

cd results

folders=("secondary_resampled" "secondary_rescaled" "sec_squared_uncertainty")
for folder in "${folders[@]}"; do
    if [ ! -d "$folder" ]; then
        echo "Creating folder: $folder"
        mkdir "$folder"
    else
        echo "Folder already exists: $folder"
    fi
done

# Move all mha files ending with squared or uncertainty in a separate folder
for FILE in *[a-z].mha
    do
        mv "$FILE" ./sec_squared_uncertainty/
    done

echo "Rescale, resample and interpolate secondary volumes"
# Rescale and resample secondary files
for FILE in *.mha
    do
        i=${FILE%.*};
        i=${i##*y};

        # resample secondary to match primary dimensions 
        /home/cartlab/miniconda3/envs/tf_15/bin/gt_affine_transform -i ./secondary${i}.mha -l ../../primary1/primary0000.mha -fr -o ./secondary_resampled/secondary${i}-resampled.mha -v
        # rescale secondary - divide by 800000 to get HU 
        /home/cartlab/miniconda3/envs/tf_15/bin/gt_image_arithm -O divide -s 800000 -o ./secondary_rescaled/secondary${i}-rescaled.mha ./secondary_resampled/secondary${i}-resampled.mha -v
    done

# rescaled and resampled secondary volumes are interpolated to obtain the same number of volumes as for primary
# results will be in the folder "secondary_interpolated" 
python3 ../../../interpolate_secondary1.py ../../data/gGeometry_H1.xml ../../data/gGeometry_H1sub10.xml 
echo "Done processing secondary volumes"

cd ..
cd ..

# FINAL ATTENUATED PROJECTIONS WITH NOISE ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
# Create 'attenuation' folder if it doesn't exist
if [ ! -d "attenuation1" ]; then
    echo "Creating folder: attenuation1"
    mkdir attenuation1
else
    echo "Folder already exists: attenuation1"
fi

cd attenuation1
# The function 'attenuation1.py' computes the final projection with noise as primary + secondary (normalized w.r.t. the flatfield)
python3 ../../attenuation1.py primary1 scatter1

echo "Final attenuation volumes done - geom 1"
cd ..
~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
# GEOM 2
# PRIMARY PROJECTIONS ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
echo "run noscatterHF_2.mac for primaries 2"
gate_split_and_run.py mac/noscatterHF_2.mac -j 1

# Find the run dir and job name from the latest run.*/run.log
run_dir=$(ls -dt "$main_dir"/run.* 2>/dev/null | head -n 1)
job_name=$(awk '/^sbatch /{for(i=1;i<=NF;i++) if($i=="-J"){print $(i+1); exit}}' "$run_dir/run.log")

echo "Run dir: $run_dir"
echo "Slurm job name: $job_name"

# Get the job id (may take a moment to appear)
job_id=""
while [ -z "$job_id" ]; do
  job_id=$(squeue -h -n "$job_name" -o "%i" 2>/dev/null | head -n 1)
  sleep 2
done

echo "Job id: $job_id. Waiting for completion..."

# Wait until the job is gone from the queue
while squeue -h -j "$job_id" >/dev/null 2>&1; do
  sleep 30
done

echo "Slurm job finished. Continuing."

found=0
for run_dir in "$main_dir"/run.*; do
    if [ ! -d "$run_dir" ]; then
    continue
    fi
    echo "Checking: $run_dir"
    output_dir="$(find "$run_dir" -type d -name 'output.*' -print -quit)"
    # search inside "$run_dir", -type d to look only at directories
    # matches directory names starting with "output."
    # the full path of the found folder is stored in 'output_dir'
    if [ -n "$output_dir" ]; then
        echo "FOUND output dir: $output_dir"
        echo "Renaming to: $run_dir/primary2"
        mv "$output_dir" "$run_dir/primary2"
        echo "Moving to: $main_dir/primary2"
        mv "$run_dir/primary2" "$main_dir/primary2"
        found=1
        break
    fi
done
for run_dir in "$main_dir"/run.*; do
    if [ ! -d "$run_dir" ]; then
    continue
    fi
    echo "Delete: $run_dir"
    rm -r "$run_dir"
done

# SECONDARY PROJECTIONS ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
echo "run scatterHF_2.mac for secondaries 2"
gate_split_and_run.py mac/scatterHF_2.mac -j 10 -o scatter2

# NB: gate_split_and_run.py returns immediately after submission, not after simulation! Must add something to wait. 
out_root="$main_dir/scatter2"
logfile="$out_root/run.log"

# Extract job name from the sbatch line (-J ...)
job_name=$(awk '/^sbatch /{for(i=1;i<=NF;i++) if($i=="-J"){print $(i+1); exit}}' "$logfile")

echo "Output dir: $out_root"
echo "Slurm job name: $job_name"

# Optional: Ctrl-C cancels all jobs with that name
# trap 'echo "Interrupted. Cancelling Slurm jobs..."; scancel -n "$job_name"; exit 130' INT

# Wait until at least one job appears
echo "Waiting for Slurm jobs to appear..."
while ! squeue -h -n "$job_name" >/dev/null 2>&1; do
  sleep 2
done

# Wait until none remain
echo "Waiting for all $job_name jobs to finish..."
while squeue -h -n "$job_name" >/dev/null 2>&1; do
  sleep 15
done

# echo "All jobs finished. Continuing."
cd scatter2

merge_slurm="/mnt/ext1/fcasaccio/1_mha_data/ES/gate_merge.slurm"
echo "submitted merge slurm"
submit_out=$(sbatch "$merge_slurm" 2>&1)

rc=$?

if [ $rc -ne 0 ]; then
  echo "sbatch failed: $submit_out" >&2
  exit $rc
fi

job_id=$(echo "$submit_out" | awk '/Submitted batch job/{print $NF}')
if [ -z "$job_id" ]; then
  echo "Could not parse JobID from sbatch output: $submit_out" >&2
  exit 1
fi

echo "Merge job submitted with JobID $job_id"

# trap 'echo "Interrupted."; echo "Cancelling merge job $job_id..."; scancel "$job_id"; exit 130' INT

echo "Waiting for merge job $job_id..."
while squeue -h -j "$job_id" >/dev/null 2>&1; do
  sleep 2
done

echo "Merge job finished."

cd results

folders=("secondary_resampled" "secondary_rescaled" "sec_squared_uncertainty")
for folder in "${folders[@]}"; do
    if [ ! -d "$folder" ]; then
        echo "Creating folder: $folder"
        mkdir "$folder"
    else
        echo "Folder already exists: $folder"
    fi
done

# Move all mha files ending with squared or uncertainty in a separate folder
for FILE in *[a-z].mha
    do
        mv "$FILE" ./sec_squared_uncertainty/
    done

echo "Rescale, resample and interpolate secondary volumes"
# Rescale and resample secondary files
for FILE in *.mha
    do
        i=${FILE%.*};
        i=${i##*y};

        # resample secondary to match primary dimensions 
        /home/cartlab/miniconda3/envs/tf_15/bin/gt_affine_transform -i ./secondary${i}.mha -l ../../primary2/primary0000.mha -fr -o ./secondary_resampled/secondary${i}-resampled.mha -v
        # rescale secondary - divide by 800000 to get HU 
        /home/cartlab/miniconda3/envs/tf_15/bin/gt_image_arithm -O divide -s 800000 -o ./secondary_rescaled/secondary${i}-rescaled.mha ./secondary_resampled/secondary${i}-resampled.mha -v
    done

# rescaled and resampled secondary volumes are interpolated to obtain the same number of volumes as for primary
# results will be in the folder "secondary_interpolated" 
python3 ../../../interpolate_secondary1.py ../../data/gGeometry_H2.xml ../../data/gGeometry_H2sub10.xml 
echo "Done processing secondary volumes"

cd ..
cd ..
# FINAL ATTENUATED PROJECTIONS WITH NOISE ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
# Create 'attenuation' folder if it doesn't exist
if [ ! -d "attenuation2" ]; then
    echo "Creating folder: attenuation2"
    mkdir attenuation2
else
    echo "Folder already exists: attenuation2"
fi

cd attenuation2
# The function 'attenuation1.py' computes the final projection with noise as primary + secondary (normalized w.r.t. the flatfield)
python3 ../../attenuation1.py primary2 scatter2
cd ..
echo "Final attenuation volumes done - geom 2"

# FINAL RECONSTRUCTION - run reconHF.sh 
