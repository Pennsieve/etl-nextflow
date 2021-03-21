#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"
file_type = params.fileType.toLowerCase()

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Determine parallelization
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process init_standard_image_processor {
    container = "${params.cli_container}"

    input:
    file input_files from s3_keys.collect { file(it) }

    output:
    file 'small_file.txt' optional true into untiled_standard_image_descriptor
    file 'large_file.txt' optional true into tiled_standard_image_descriptor
    file input_files into untiled_standard_image, tiled_standard_image

    script:
    input_file = input_files.join(' ')
    """
    #!/bin/bashlog
    file_size=`du -Lk ${input_file} | cut -f1`
    if (( \$file_size > 50000 ))
    then
        echo \$file_size > large_file.txt;
    else
        echo \$file_size > small_file.txt;
    fi;
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2a. Generate different sub-regions to parallelize over
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
     Process standard image file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process tiled_standard_image_processor {
    container = "${params.standard_image_container}"

    memory_req = "${params.memory}"
    memory memory_req

    maxForks params.max_forks

    input:
    file 'large_file.txt' from tiled_standard_image_descriptor
    file input_files from tiled_standard_image
    file(sub_region) from sub_regions

    output:
    file 'view_asset_info.json' optional true into tiled_view_asset_mutation
    file 'update-package-to-slide*.txt' optional true into update_package_to_slide
    file 'metadata.json' optional true into standard_tiled_image_metadata

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
            --sse AES256 \
            --recursive
        echo 'slide' > update-package-to-slide.txt
    fi
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
2b. Process standard image file - PNG or JPEG or JPEG2000
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process untiled_standard_image_processor {
    container = "${params.standard_image_container}"

    memory_req = "${params.memory}"
    memory memory_req

    maxForks params.max_forks

    input:
    file 'small_file.txt' from untiled_standard_image_descriptor
    file input_files from untiled_standard_image

    output:
    file 'view_asset_info.json' optional true into untiled_view_asset_mutation
    file 'metadata.json' into standard_untiled_image_metadata

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist = arglist.join(' ')

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')

    aws_view_key = "${params.assetDirectory}view"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key

    cmd  = "python /app/run.py ${arglist}"

    """
    echo ${input_files}
    echo ${cmd}
    echo 'Decoding input file(s) and created exploded view assets if necessary'
    echo 'Creating create-asset mutation for views files'
    ${cmd}
    echo 'Uploading output view to S3 to view/output.png'
    if [ -f output.png ]; then
        aws \$AWS_CLI_FLAGS s3 cp \
            output.png \
            ${aws_view_storage_dest}/output.png \
            --sse AES256
    fi
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3. Create asset and apply View
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process upload_file_and_view {
    container = "${params.cli_container}"

    input:
    file('view_asset_info.json') from untiled_view_asset_mutation.concat(tiled_view_asset_mutation)
    file 'metadata.json' from standard_tiled_image_metadata.concat(standard_untiled_image_metadata)

    output:
    file 'metadata.json' into standard_image_metadata

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Change package type to Slide if necessary
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

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

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    - Update properties of package
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process update_properties {
    container = "${params.cli_container}"

    input:
    file 'metadata.json' from standard_image_metadata

    output:

    script:
    """
    #!/bin/bashlog
    /app/etl-data set-package-properties \
        --property-info=metadata.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}
