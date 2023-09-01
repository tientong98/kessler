#!/bin/bash

################################################################################
# running preproc for ITKSNAP lesion segmentation
################################################################################


study_dir=/mnt/LABS/neuro/stem_tbi
rawdata=${study_dir}/rawdata
lesion_dev=${study_dir}/derivatives/lesion_seg
itksnap=/usr/local/itksnap-3.6.0/bin/itksnap


function usage {
	cat <<EOM
Usage: $(basename "$0") [OPTION]...

  -s sub-XXX       long version of subject id
  
  -v ses-X         long version of session id

  -l yes or no     indicate whether you will run lesion segmentation and therefore needs preproc

  -h               display help
  
EOM

	exit 2
}
    
while getopts s:v:l:h flag
do
    case "${flag}" in
        s) sublong=${OPTARG};;
        v) seslong=${OPTARG};;
        l) lesion=${OPTARG};;
        h|*) usage ;;

    esac
done



if [ $# -eq 0 ]; then
    >&2 usage
    exit 1
fi



################################################################################
# get dicom information
################################################################################

#libreoffice --calc ${rawdata}/${sublong}/${seslong}/*.tsv

################################################################################
# copy data
################################################################################

[[ ! -d ${lesion_dev}/${sublong} ]] && mkdir -p ${lesion_dev}/${sublong}

t1w=${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_T1w.nii.gz
flair=${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_FLAIR.nii.gz


[[ ! -f ${t1w} ]] && cp ${rawdata}/${sublong}/${seslong}/anat/*T1*.nii.gz ${lesion_dev}/${sublong}
[[ ! -f ${flair} ]] && cp ${rawdata}/${sublong}/${seslong}/anat/*FLAIR*.nii.gz ${lesion_dev}/${sublong}

################################################################################
# if lesion flag == yes, brain extraction and registration FLAIR to T1w
################################################################################

if [ ${lesion} == 'yes' ] ; then

    ants_tempate=/mnt/LABS/tbi/STAFF/tientong/MICCAI2012-Multi-Atlas-Challenge-Data

    for file in ${t1w} ${flair} ; do
        
#        bash /mnt/LABS/tbi/STAFF/tientong/optiBET.sh -i $file
        
        if [ ! -f ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_T1wBrainExtractionBrain.nii.gz ] ; then
            echo Doing brain extraction for ${sublong}
            bet_outfile=`echo $file | awk -F "/" '{print $NF}' | sed -e 's|.nii.gz||g'`                
            /usr/local/ants/bin/antsBrainExtraction.sh \
                -d 3 -a $file \
	        -e ${ants_tempate}/T_template0.nii.gz \
	        -m ${ants_tempate}/T_template0_BrainCerebellumProbabilityMask.nii.gz \
	        -f ${ants_tempate}/T_template0_BrainCerebellumRegistrationMask.nii.gz \
	        -o ${lesion_dev}/${sublong}/${seslong}/$bet_outfile
        fi    
	    		
    done
    
	echo Registering FLAIR to T1w for ${sublong}
	
	/usr/local/fsl/bin/flirt \
	    -in ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_FLAIRBrainExtractionBrain.nii.gz \
	    -ref ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_T1wBrainExtractionBrain.nii.gz \
	    -out ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_bet_FLAIR_in_T1w.nii.gz \
	    -omat ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_bet_FLAIR_in_T1w.mat \
	    -bins 256 -cost corratio \
	    -searchrx -90 90 -searchry -90 90 -searchrz -90 90 \
	    -dof 12  -interp trilinear
	    
	$itksnap \
	    -g ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_T1wBrainExtractionBrain.nii.gz \
	    -o ${lesion_dev}/${sublong}/${seslong}/${sublong}_${seslong}_bet_FLAIR_in_T1w.nii.gz

else

    # if -l not y -- not doing lesion segmenation, so only open raw T1w and FLAIR
    $itksnap -g $t1w -o $flair
    
fi

