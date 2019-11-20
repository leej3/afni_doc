#!/bin/tcsh

#:TITLE: How to use FS recon-all with AFNI

cat << TEXTINTRO

.. comment on creation of this script
   This script was generated from running:
     afni_doc/helper_tutorial_rst_scripts/tut_fs_fsprep_MARK.tcsh
   as described in the _README.txt in that same directory.

FreeSurfer (FS) provides a number of useful tools for brain imaging.
In particular, the parcellation/segmentations and anatomical surfaces
generated by ``recon-all`` can be used in lots of applications.

Here we describe a few considerations for preparing to use FS (in
particular, ``recon-all``) and bringing the results into AFNI- and
SUMA-land with ``@SUMA_Make_Spec_FS``.  Some of these items might even
inform your acquisition paradigms for anatomical volumes.

These considerations are borne out of experience in processing the
datasets and into integrating them into the AFNI/SUMA flow.  This is
not a FS help page---all queries about using those tools should go to
their authors.  Here, we have been using FS ver 6.0.0.

TEXTINTRO

#:SECTION: How to check+fix T1w dataset for running FS

cat << TEXTBLOCK

There are a number of properties that the T1w volume input to FS's
``recon-all`` should have to ensure that the output datasets and
surfaces align well with the input volume.  To date, these include:

* having a FOV matrix with even numbers of voxels in each direction
  (e.g., 256x256x174 matrix, not a 256x256x173 one).

* having isotropic voxels (voxel edge lengths are the same)

* voxels are between 0.5-1.0 mm along an edge (note that for voxels
  <0.75 mm along an edge, one might have to use special ``-hires``
  option in ``recon-all``; please consult FS help pages for more
  detail).

This list of properties might change over time, as either the software
changes or more properties are determined.

There is now a program in AFNI to check these things, called
``check_dset_for_fs.py``.  Its help also provides suggestions for
trying to fix any of those issues in your anatomical datasets,
primarily through zero-padding slices and resampling the data.

.. note:: If your input T1w volumes properties are very far from being
          FreeSurfer-able (e.g., voxel sizes are 1x1x5 mm), then the
          suggested fix might not work.  These programs cannot perform
          miracles!

By default, ``check_dset_for_fs.py`` outputs only a simple text output
to the screen, stating whether input T1w passes all tests (``1``) or
fails any single test (``0``).  This is useful for scripting
(capturing the output in a variable for evaluating in a conditional),
but not very informative.  One can also add the ``-verb`` option to
see a complete breakdown of the input properties, test thresholds
(which can be controlled through additional options) and results of
individual tests.

Below we provide a basic example (first compactly, then in gruesome
detail) for first testing a T1w dset for FS-ability, then "fixing" it
(if need be), and finally processing it.  The dataset referred to here
is part of the AFNI Bootcamp data:
``AFNI_data6/FT_analysis/FT/FT_anat+orig.*`` ("FT" is a random,
two-letter ID for the subject: old school encoding.)

TEXTBLOCK

#:SECTION: Ex. A: start-to-finish

cat << TEXTBLOCK

This a compact example of going through the dataset check and running
FS.

In this case, it turns out that the T1w volume has both non-isotropic
voxels *and* non-even matrix dimensions.  We then fix both of these
problems (``3dAllineate`` to resample, and ``3dZeropad`` to finalize
the grid dimensions).  Finally, FS works its magic with ``recon-all`,
and the results are brought back to AFNI/SUMA-land with
``@SUMA_Make_Spec_FS``:

#:INCLUDE: ex_a.tcsh
    :language: tcsh

And that is all.  Note that ``recon-all`` will take a long time to run
(many hours).

A bit more description of the outputs is provided below.

TEXTBLOCK

#:SECTION: Ex. B, 1: check dset

cat << TEXTBLOCK

We go through essentially the same steps as the "compact" Ex. A above,
but describe more features/options/notes.  We also provide a
scriptified (encryptified?) form of running these steps, which might
be more generalizable.

TEXTBLOCK

# Input T1w anatomical volume
set anat_orig = FT_anat+orig.HEAD

# "Verbose" mode of checking all properties: for detailed output.
# Dump output to a file...
check_dset_for_fs.py -input ${anat_orig} -verb > check_fs.txt
# ... and display it
\cat check_fs.txt


cat << TEXTBLOCK

We can quickly take a look at the text file output:

#:INCLUDE: check_fs.txt
    :language: none

The top part shows some of the dataset info and the parameters of
testing, as well as the test-by-test results.  Note that by default,
all tests are run and put into the final evaluation (but one can
specify sub-tests).

.. note:: Checking voxel size depends on comparing floating point
          numbers, so there is necessarily a "tolerance" value
          involved.  That is, we can't ask, "Are the voxel dimensions
          *exactly* the same?" but instead ask, "Are the differences
          in voxel dimensions smaller than *epsilon*?"  The program
          has default values of epsilon for each voxelsize comparison
          (set fairly arbitrarily), but the users can adjust these as
          they see fit.


TEXTBLOCK


# "Scripty" mode of checking all properties: single-number output
# stored in variable
set fs_check = `check_dset_for_fs.py -input ${anat_orig}`

# Check the output
if ( $fs_check ) then

    # Dset passes check
    echo "++ Good to go with FreeSurfer"
    set anat_for_fs = ${anat_orig}

else

    # Dset fails check
    echo "** Shouldn't do FreeSurfer on this dset"
    echo "   Will check among properties for what has gone wrong and"
    echo "   fix each badness appropriately (hopefully)"

    # get the prefix for naming
    set pref = `3dinfo -prefix_noext ${anat_orig}`

    # Sub-check of voxelsize properties: do we need to resample?
    set input_dset   = ${anat_orig} 
    set fs_check_vox = `check_dset_for_fs.py -input ${input_dset} \
                            -is_vox_05mm_min -is_vox_1mm_max -is_vox_iso`

    # use results of voxelsize check to resample, if necessary; using
    # the keyword "IDENTITY" as the matrix means that the data stays
    # in place, and using "wsinc5" means that the interpolation should
    # preserve edges/details well.
    if ( $fs_check_vox ) then

        3dAllineate                             \
            -1Dmatrix_apply  IDENTITY           \
            -mast_dxyz       1                  \
            -final           wsinc5             \
            -source          ${input_dset}      \
            -prefix          ${pref}_00_ISO.nii

        # pass along this dset as the new "input" dset for next step
        set input_dset = ${pref}_00_ISO.nii
    endif

    # use results of matrix check zeropad, if necessary
    set fs_check_mat = `check_dset_for_fs.py -input ${input_dset} \
                            -is_mat_even`

    # use results of matrix check zeropad, if necessary
    if ( $fs_check_mat ) then

        3dZeropad                               \
            -pad2evens                          \
            -prefix          ${pref}_01_ZP.nii  \
            ${input_dset}

        # pass along this dset as the new "input" dset for next step
        set input_dset = ${pref}_01_ZP.nii
    endif

    set anat_for_fs = ${input_dset}
endif

cat << TEXTBLOCK

After this check, we should now have an appropriate dset for FS's
recon-all stored in the variable ``${anat_for_fs}.`` We could re-run
``check_dset_for_fs.py`` on it to be sure!

Note also that we don't know how badly the initial dset failed its
tests for FS-ability.  The output could still be inappropriate for
running ``recon-all`` due to having weird voxel sizes, partial
coverage, noise/artifact, etc.  As we always seem to do in AFNI, I
would **strongly encourage you to look at your data**.  

One way to look at the data could be with ``@chauffeur_afni``:

TEXTBLOCK

@chauffeur_afni                                                       \
    -ulay    ${anat_for_fs}                                           \
    -olay_off                                                         \
    -prefix  ${pref}_image                                            \
    -montx 7 -monty 1                                                 \
    -blowup 4                                                         \
    -set_xhairs OFF                                                   \
    -label_mode 1 -label_size 3                                       \
    -do_clean

cat << TEXTBLOCK

There, that wasn't so bad, was it?  Here are your images:

#:IMAGE:  Axial, sagittal and coronal montages of the T1w dset
    FT_anat_image.axi.png
    FT_anat_image.sag.png
    FT_anat_image.cor.png

|

TEXTBLOCK


#:SECTION: Ex. B, 2: Run FS's recon-all

cat << TEXTBLOCK

Now that the dataset has been checked and fixed with
``check_dset_for_fs.py`` (and then checked again with images output by
``@chauffeur_afni``), we can proceed to run FS's ``recon-all``
command.  This command will estimate cortical
parcellation/segmentation maps, as well as surface messages.  

The FS outputs can then be translated into standardized meshes and
NIFTI volume output for use in AFNI+SUMA with ``@SUMA_Make_Spec_FS``,
which will also make some other convenient dsets derived from the FS
output.  These will be described below.

TEXTBLOCK

echo "++ Ready to start FS"

# NB: this command will take a long time-- typically somewhere between
# 10-20 hours for a standard anatomical brain.
recon-all                                     \
    -all                                      \
    -sd       ./                              \
    -subjid   FT                              \
    -i        ${anat_for_fs}

cat << TEXTBLOCK

The main thing to note is the directory structure of outputs: in the
present case, ``recon-all`` will make a new directory called ``./FT/``
and populate it with lots of subdirectories of data ("label", "mri",
"scripts", etc.).  More generally, if ``recon-all`` is called with
options ``-sd SD_ARG`` and ``-subjid SUBJID_ARG``, then the path to
the top of the output directory will be ``SD_ARG/SUBJID_ARG/``.

The above command will run for a long while.

TEXTBLOCK


#:SECTION: Ex. B, 3: Run AFNI's @SUMA_Make_Spec_FS

cat << TEXTBLOCK

When ``recon-all`` has finished, we can take that FS output and bring
it into formats usable by AFNI and SUMA, such as NIFTI and GIFTI
files.  This is all done with a single AFNI command
``@SUMA_Make_Spec_FS``.

Basically, one just has to provide the program with: a subject ID
(sid) and the path to the top of the FS output; we also generally
recommend using the ``-NIFTI`` option, for nicer format dsets of the
surfaces.  Putting this all together, we have the following command:

TEXTBLOCK

# Convert FS recon-all output to AFNI/SUMA formats
@SUMA_Make_Spec_FS                           \
    -NIFTI                                   \
    -sid     FT                              \
    -fspath  ./FT

cat << TEXTBLOCK

The main output of running this command is directory that will here be
called ``./FT/SUMA``.  Note that "FT" happens to appear twice in
different roles here: we are first specifying it as the subject ID (so
that will determine some output file names), and then it just happens
to be part of the path to the FS output directory.  This is *not*
always the case.  In general, the new subdirectory ``SUMA`` that will
be wherever the ``-fspath ..`` directory is; using the example names
of arguments to ``recon-all`` from the previous section, it would be
in ``SD_ARG/SUBJID_ARG/SUMA``.

The ``SUMA/`` directory contains volumetric outputs of segmentations
and parcellations, surfaces of various sizes and geometry, and more.
Several of these data sets are direct copies of FS output, but in
NIFTI and other formats usable by AFNI.  Others are derived datasets
that we have found to be useful, such as groupings of parcellated ROIs
by tissue types.  Some of the content of the directory is:

* **aparc+aseg_REN_\*.nii.gz**
    A family of volumetric datasets from the "2000" atlas parcellation
    used by FS.  These have been renumbered from the original FS
    lookup-table values for colorbar convenience in AFNI; the
    enumeration will still be consistent across subjects, and the same
    string labels are attached in a labletable (i.e., the same number
    and label goes with a given ROI, across all subjects).  For
    convenience, subsets of ROIs grouped by tissue or type have also
    been created (see the output of ``@SUMA_renumber_FS`` for more
    details on these).

    Recently, the ``*_REN_gmrois.nii.gz`` dset has been added, as a
    subset of the GM ROIs defined by FS.  This dataset contains the
    ROI-like regions of GM from the parcellation, and might be
    particularly useful for tractography or network correlation.

* **aparc.a2009s+aseg_REN_\*.nii.gz**
    A family of volumetric datasets from the "2009" atlas parcellation
    used by FS.  The same renumbering and grouping, as described in
    for the "2000" atlas above, applies.

* **fs_ap_wm.nii.gz**, **fs_ap_latvent.nii.gz**
    Two volumetric datasets of masks that have been found useful for
    ``afni_proc.py`` scripting, namely when applying tissue-based
    regressors.  The first is comprised of the main WM regions defined
    by FS, and the second is comprised of the lateral ventricles (see
    the output of ``@SUMA_renumber_FS`` for more details on these).




TEXTBLOCK
