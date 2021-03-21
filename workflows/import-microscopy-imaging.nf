#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"
file_type = params.fileType.toLowerCase()

s3_keys = Channel.from(params.files)
s3_keys.into { svs_keys; czi_keys; brukertiff_keys; ometiff_keys }

/*
 * Parameters to generate parallel sub region files for SVS files
 */
params.sub_region_n_x = 4
params.sub_region_n_y = 4
params.sub_region_n_z = 1
params.sub_region_n_c = 1
params.sub_region_n_t = 1

/*
 * Generate sub_region_files for parallel computation
 */
for (x = 0; x <params.sub_region_n_x; x++) {
    for (y = 0; y <params.sub_region_n_y; y++) {
        for (z = 0; z <params.sub_region_n_z; z++) {
            for (c = 0; c <params.sub_region_n_c; c++) {
                for (t = 0; t <params.sub_region_n_t; t++) {
                    file1 = new File('sub_'+'x_'+x+'_'+params.sub_region_n_x+'_'+'y_'+y+'_'+params.sub_region_n_y+'_'+'z_'+z+'_'+params.sub_region_n_z+'_'+'c_'+c+'_'+params.sub_region_n_c+'_'+'t_'+t+'_'+params.sub_region_n_t+'.txt')
                    file1.write ''
                }
            }
        }
    }
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


 1. Branch into appropriate microscopy imaging processors


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                            SVS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

sub_regions_svs = Channel.fromPath('sub*.txt').flatten()

process svs_processor {
    queue = "${env}-etl-default-low-priority-queue-use1"
    container = "${params.svs_container}"
    file_type = params.fileType.toLowerCase()

    maxForks params.max_forks

    when:
    file_type == 'aperio'

    input:
    file input_files from svs_keys.collect { file(it) }
    file(sub_region_svs) from sub_regions_svs

    output:
    file 'view_asset_info.json' into svs_view_asset_mutation
    file 'metadata.json' optional true into svs_metadata

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist.push('--sub-region-file="' + sub_region_svs.toString() + '"')
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py ${arglist}"

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')

    aws_view_key = "${params.assetDirectory}${input_filename}-zoomed"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key

    """
    #!/bin/bashlog
    echo 'Decoding SVS input file(s) and created exploded view assets (might take some time ...)'
    echo ${cmd}
    ${cmd}
    echo 'Uploading output view to S3'
    aws \$AWS_CLI_FLAGS s3 cp \
        ${input_filename}-zoomed \
        ${aws_view_storage_dest} \
        --sse AES256 \
        --recursive
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                             CZI
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

sub_regions_czi = Channel.fromPath('sub*.txt').flatten()

process czi_processor {
    container = "${params.czi_container}"
    queue = "${env}-etl-default-low-priority-queue-use1"

    when:
    file_type == 'czi' || file_type == 'jpeg'

    input:
    file input_files from czi_keys.collect { file(it) }
    file sub_region_czi from sub_regions_czi

    output:
    file 'view_asset_info.json' into czi_view_asset_mutation
    file 'metadata.json' optional true into czi_metadata

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist.push('--sub-region-file="' + sub_region_czi.toString() + '"')
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py ${arglist}"

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')
    aws_view_key = "${params.assetDirectory}${input_filename}-zoomed"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key
    """
    #!/bin/bashlog
    ${cmd}
    aws \$AWS_CLI_FLAGS s3 cp \
        ${input_filename}-zoomed \
        ${aws_view_storage_dest} \
        --sse AES256 \
        --recursive \
        --quiet

    # for backwards compatibility with viewer: proxy "slide.dzi" if first slice
    if [ -e "${input_filename}-zoomed/dim_Z_slice_0_dim_T_slice_0_files" ]; then
        aws \$AWS_CLI_FLAGS s3 cp \
            ${aws_view_storage_dest}/dim_Z_slice_0_dim_T_slice_0_files \
            ${aws_view_storage_dest}/slide_files \
            --sse AES256 \
            --recursive \
            --quiet
        aws \$AWS_CLI_FLAGS s3 cp \
            ${aws_view_storage_dest}/dim_Z_slice_0_dim_T_slice_0.dzi \
            ${aws_view_storage_dest}/slide.dzi \
            --sse AES256 \
            --quiet
    fi
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                       BRUKER-TIFF
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

sub_regions_brukertiff = Channel.fromPath('sub*.txt').flatten()

process brukertiff_processor {
    container = "${params.brukertiff_container}"

    when:
    file_type == 'brukertiff'

    input:
    file input_files from brukertiff_keys.collect { file(it) }
    file sub_region_brukertiff from sub_regions_brukertiff

    output:
    file 'view_asset_info.json' into brukertiff_view_asset_mutation
    file 'metadata.json' optional true into brukertiff_metadata

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist.push('--sub-region-file="' + sub_region_brukertiff.toString() + '"')
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py ${arglist}"

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')
    aws_view_key = "${params.assetDirectory}"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key
    """
    #!/bin/bashlog
    echo '1. Decoding Bruker TIFF input file(s) and creating exploded view assets'
    echo '2. Uploading all output file and view assets to S3'
    ${cmd}
    zoom_dir=\$(ls -d1 *-zoomed |  head -n 1)
    aws \$AWS_CLI_FLAGS s3 cp \
        \$zoom_dir \
        ${aws_view_storage_dest}\$zoom_dir \
        --sse AES256 \
        --recursive
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                          OME-TIFF
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

sub_regions_ometiff = Channel.fromPath('sub*.txt').flatten()

process ometiff_processor {
    queue = "${env}-etl-default-low-priority-queue-use1"
    container = "${params.ometiff_container}"

    when:
    file_type == 'ometiff' || file_type == 'tiff'

    input:
    file input_files from ometiff_keys.collect { file(it) }
    file sub_region_ometiff from sub_regions_ometiff

    output:
    file 'view_asset_info.json' into ometiff_view_asset_mutation
    file 'metadata.json' optional true into ometiff_metadata

    script:
    arglist = []
    input_files.each { arglist.push('--file="'+it.toString()+'"')}
    arglist.push('--sub-region-file="' + sub_region_ometiff.toString() + '"')
    arglist = arglist.join(' ')
    cmd  = "python /app/run.py ${arglist}"

    input_filename = []
    input_files.each { input_filename.push(it.toString().tokenize('/')[-1])}
    input_filename = input_filename.join(' ')
    aws_view_key = "${params.assetDirectory}${input_filename}-zoomed"
    aws_view_storage_dest = "s3://${params.storage_bucket}/" + aws_view_key
    """
    #!/bin/bashlog
    echo '1. Decoding OMETIFF input file(s) and creating exploded view assets'
    echo '2. Uploading all output file and view assets to S3'
    ${cmd}
    aws \$AWS_CLI_FLAGS s3 cp \
        ${input_filename}-zoomed \
        ${aws_view_storage_dest} \
        --sse AES256 \
        --recursive
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


 2. - Copy from processor outputs -> storage bucket
    - Assess file sizes for all files and view assets
    - Upload all files and view to storage bucket
    - Create file asset
    - Create view asset


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process upload_file_and_view_brukertiff {
    container = "${params.cli_container}"

    when:
    file_type == 'brukertiff'

    input:
    file 'view_asset_info*.json' from brukertiff_view_asset_mutation.collect()

    output:
    file 'view_asset_info1.json' into upload_file_and_view_brukertiff_complete

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info1.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}

process upload_file_and_view_svs {
    container = "${params.cli_container}"

    when:
    file_type == 'aperio'

    input:
    file 'view_asset_info*.json' from svs_view_asset_mutation.collect()

    output:
    file 'view_asset_info1.json' into upload_file_and_view_svs_complete

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info1.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}

process upload_file_and_view_czi {
    container = "${params.cli_container}"

    when:
    file_type == 'czi' || file_type == 'jpeg'

    input:
    file 'view_asset_info*.json' from czi_view_asset_mutation.collect()

    output:
    file 'view_asset_info1.json' into upload_file_and_view_czi_complete

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info1.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    /app/etl-data update-package-type \
            --package-type='Slide' \
            --package-id=${params.packageId} \
            --organization-id=${params.organizationId}
    """
}

process upload_file_and_view_ometiff {
    container = "${params.cli_container}"

    when:
    file_type == 'ometiff'

    input:
    file 'view_asset_info*.json' from ometiff_view_asset_mutation.collect()

    output:
    file 'view_asset_info1.json' into upload_file_and_view_ometiff_complete

    script:
    """
    #!/bin/bashlog
    /app/etl-data create-asset \
        --asset-info=view_asset_info1.json \
        --package-id=${params.packageId} \
        --organization-id=${params.organizationId}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    - Update properties of package using deep zoom slide metadata
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
process update_properties {
    container = "${params.cli_container}"

    input:
    file 'metadata.json' from svs_metadata.concat(ometiff_metadata, czi_metadata, brukertiff_metadata)
    file 'view_asset_info.json' from upload_file_and_view_svs_complete.concat(upload_file_and_view_brukertiff_complete, upload_file_and_view_czi_complete, upload_file_and_view_ometiff_complete)

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
