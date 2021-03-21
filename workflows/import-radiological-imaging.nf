#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"
file_type = params.fileType.toLowerCase()

s3_keys = Channel.from(params.files)
s3_keys.into { non_dicom_keys; dicom_keys }

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1a. Branch into appropriate radiological imaging processors
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process dicom_processor {
    container = "${params.dicom_container}"
    file_type = params.fileType.toLowerCase()

    when:
    file_type == 'dicom'

    input:
    file input_files from dicom_keys.collect { file(it) }

    output:
    file '*.nii.gz' into dicom_nifti_file

    script:
    cmd  = "/usr/local/bin/dcm2niix -z y -m y ."

    """
    #!/bin/bashlog
    echo 'Decoding DICOM input file(s) and created NIfTI files'
    ${cmd}
    python /app/sanitize.py
    """
}

process non_dicom_processor {
    container = "${params.freesurfer_container}"

    when:
    file_type != 'dicom'

    input:
    file input_files from non_dicom_keys.collect { file(it) }

    output:
    file 'view_asset_info.json' into view_asset_mutation

    script:
    cmd  = ""
    input_args = []

    /* Isolate only img file in case of ANALYZE and avoid including hdr coupled file */
    input_files.each { if (it.toString().endsWith('.img')) {
            input_args.push(it.toString())
        }
    }
    if (input_args.size() == 0) {
        input_args = input_files
    }
    input_args = input_args.join(' ')

    // note: assetDirectory should end in '/'
    s3_view_key = "${params.assetDirectory}view_asset/view.nii.gz"

    """
    mri_convert -ot nii ${input_args} output.nii.gz
    aws \$AWS_CLI_FLAGS s3 cp \
        output.nii.gz \
        "s3://${params.storage_bucket}/${s3_view_key}" \
        --sse AES256

    file_size=`aws \$AWS_CLI_FLAGS s3api list-objects --bucket=${params.storage_bucket} --prefix="${s3_view_key}" --query 'Contents[0].Size'`

    cat > view_asset_info.json <<- EOF
    {
      \"bucket\": \"${params.storage_bucket}\",
      \"key\": \"${s3_view_key}\",
      \"type\": \"View\",
      \"fileType\": \"NIFTI\",
      \"size\": \${file_size}
    }
    EOF
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. - Copy from processor outputs -> storage bucket
    - Assess file sizes for all files and view assets
    - Upload all files and view to storage bucket
    - Create file asset
    - Create view asset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process upload_file_and_view {
    container = "${params.cli_container}"

    input:
    file('view_asset_info.json') from view_asset_mutation

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}
