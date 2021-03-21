#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"
file_type = params.fileType.toLowerCase()

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1a. Generate different sub-regions to parallelize over
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*
 * Pipeline input params=
 */
params.sub_region_rows = 2
params.sub_region_cols = 2

/*
 * Generate sub_region_files for parallel computation
 */
for (i = 0; i <params.sub_region_cols; i++) {
    for (j = 0; j <params.sub_region_rows; j++) {
        file1 = new File(i + '_' + j + '.txt')
        file1.write params.sub_region_cols + ',' + params.sub_region_rows
    }
}
sub_regions = Channel.fromPath('*.txt').flatten()

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1b. Process standard TIFF image file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process tiled_standard_image_processor {
    container = "${params.standard_image_container}"

    memory_req = "${params.memory}"
    memory memory_req

    maxForks params.max_forks

    input:
    file input_files from s3_keys.collect { file(it) }
    file(sub_region) from sub_regions

    output:
    file 'view_asset_info.json' optional true into tiled_view_asset_mutation
    file 'update-package-to-slide*.txt' optional true into update_package_to_slide

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist.push('--sub-region-file="' + sub_region.toString() + '"')
    arglist = arglist.join(' ')

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')

    aws_view_key = "${params.assetDirectory}view"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key

    cmd  = "python /app/run.py ${arglist}"

    """
    #!/bin/bashlog
    echo ${input_files}
    echo ${cmd}
    echo 'Decoding input file(s) and created exploded view assets if necessary'
    echo 'Creating create-asset mutation for views files'
    ${cmd}
    echo 'Uploading output view to S3'
    if [ -f view/slide.dzi ]; then
        aws \$AWS_CLI_FLAGS s3 cp \
            view \
            ${aws_view_storage_dest} \
            --sse AES256
            --recursive
        echo 'slide' > update-package-to-slide.txt
    fi
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
    file('view_asset_info.json') from tiled_view_asset_mutation

    output:

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}

process update_package_type {
    container = "${params.cli_container}"

    input:
    file('update-package-to-slide*.txt') from update_package_to_slide.collect()

    output:

    script:
    """
    #!/bin/bashlog
    if [ -f update-package-to-slide1.txt ]; then
        /app/etl-data update-package-type \
            --package-type='Slide' \
            --package-id=${params.packageId} \
            --organization-id=${params.organizationId}
    fi
    """
}
