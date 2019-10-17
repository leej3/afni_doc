#!/bin/tcsh


# **Ex. 2**: Combine (stats) images from many subj


# AFNI tutorial: auto-image-making example "2" using imcat (and
#                @chauffeur_afni)
#
# + last update: July 10, 2019
#
##########################################################################
#
# This example shows one way to look at individual statistical results
# across a group.  
#
# This tcsh script is meant to be run in the following directory of
# the AFNI Bootcamp demo data:
#     AFNI_data6/group_results
# using the REML* volumes there.
#
# By changing the the list of files given to "${ilist}", this can be
# directly adapted to other cases.  Depending on how you unpacked your
# Bootcamp data, you might need to adjust the "${idir}" variable, too.
#
# =====================================================================

set here  = $PWD                          # for path; trivial, could be changed

set istr   = "REML"                       # string for choosing vol dsets
set idir   = "~/AFNI_data6/group_results" # location of files (at least for me)
set ilist  = `\ls ${idir}/${istr}*HEAD`   # get list of dsets to imagize
set imask  = "${idir}/mask+tlrc.HEAD"     # WB mask for this 'group'
set ianat  = "${idir}/FT_anat+tlrc.HEAD"  # anat vol, use as ulay

set lcol  = ( 192 192 192 )               # RGB line color bt image panels
set odir  = ${here}/QC_imcat_02           # output dir for images

\mkdir -p ${odir}


# ------------ Use @chauffeur_afni to make individual images -------------


set allbase = ()

foreach ff ( ${ilist} )
    # base name of vol, and make a list of all prefixes for later
    set ibase   = `3dinfo -prefix_noext "${ff}"`
    set allbase = ( ${allbase} ${ibase} )

    ### Make a montage of the zeroth brick of each image.
    # Some fun-ness here: part of each file's name is added to the
    # label string shown in each panel.
    # Note: these olay datasets are unclustered and unmasked.
    @chauffeur_afni                                                   \
        -ulay       ${ianat}                                          \
        -ulay_range "2%" "130%"                                       \
        -olay       ${ff}                                             \
        -set_subbricks -1 0 1                                         \
        -func_range 3                                                 \
        -thr_olay_p2stat 0.001                                        \
        -thr_olay_pside  bisided                                      \
        -cbar    Reds_and_Blues_Inv                                   \
        -olay_alpha  Yes                                              \
        -olay_boxed  Yes                                              \
        -opacity 7                                                    \
        -prefix     ${odir}/img0_alpha_${ibase}                       \
        -montx 1 -monty 1                                             \
        -set_dicom_xyz  5 18 18                                       \
        -set_xhairs     OFF                                           \
        -label_string "::${ibase}"                                    \
        -label_mode 1 -label_size 3                                   \
        -do_clean

    # same images as above, but with hard thresholding
    @chauffeur_afni                                                   \
        -ulay       ${ianat}                                          \
        -ulay_range "2%" "130%"                                       \
        -olay       ${ff}                                             \
        -set_subbricks -1 0 1                                         \
        -func_range 3                                                 \
        -thr_olay_p2stat 0.001                                        \
        -thr_olay_pside  bisided                                      \
        -cbar    Reds_and_Blues_Inv                                   \
        -opacity 7                                                    \
        -prefix     ${odir}/img0_hthr_${ibase}                        \
        -montx 1 -monty 1                                             \
        -set_dicom_xyz  5 18 18                                       \
        -set_xhairs     OFF                                           \
        -label_string "::${ibase}"                                    \
        -label_mode 1 -label_size 3                                   \
        -do_clean

end


# ------------------- Use imcat to concatenate images --------------------


foreach ss ( "sag" "cor" "axi" )
    # Combine alpha-thresholded images
    imcat                                                             \
        -echo_edu                                                     \
        -gap 5                                                        \
        -gap_col ${lcol}                                              \
        -nx 5                                                         \
        -ny 2                                                         \
        -prefix ${odir}/ALL_alpha_${istr}_sview_${ss}.jpg             \
        ${odir}/img0_alpha*${ss}*

    # Combine hard-thresholded images
    imcat                                                             \
        -echo_edu                                                     \
        -gap 5                                                        \
        -gap_col ${lcol}                                              \
        -nx 5                                                         \
        -ny 2                                                         \
        -prefix ${odir}/ALL_hthr_${istr}_sview_${ss}.jpg              \
        ${odir}/img0_hthr_*${ss}*

end

# ---------------------------------------------------------------------

echo "++ DONE!"

# All fine
exit 0
