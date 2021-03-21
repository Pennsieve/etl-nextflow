#!/usr/bin/env nextflow

// VERSION: 0.0.2

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Get thumbnail from video
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process get_thumbnail {
    container = "${params.video_container}"

    input:
    file input_file from s3_keys.map{ file(it) }

    output:
    file 'asset.json' into video_view
    file 'thumbnail_asset.json' into thumbnail

    script:
    cmd = "python /app/run.py --file=" + "${input_file}" + " --convert=false"
    """
    #!/bin/bashlog
    ${cmd}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Create video view and thumbnail assets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process create_view_asset {
    container = "${params.cli_container}"

    input:
    file 'asset_info.json' from video_view
    file 'view_asset_info.json' from thumbnail

    script:
	"""
	#!/bin/bashlog
	/app/etl-data create-asset \
		--asset-info=asset_info.json \
		--package-id=${params.packageId} \
		--organization-id=${params.organizationId}
	 /app/etl-data create-asset \
		--asset-info=view_asset_info.json \
		--package-id=${params.packageId} \
		--organization-id=${params.organizationId}
	"""
}
