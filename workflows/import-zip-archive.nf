#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Run parsing script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process extract_metadata_from_zip {
    file_type = params.fileType.toLowerCase()
    container = params.import_processor_template.replace('<TYPE>',"zip")

    input:
    file input_file from s3_keys.map{ file(it) }

    output:
    file 'asset_info.json' into zip_schema

    script:
    cmd = "python /app/run.py --file=" + "${input_file}"
    """
    #!/bin/bashlog
    ${cmd}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Create zip view asset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process create_view_asset {
    container = "${params.cli_container}"

    input:
    file 'asset_info.json' from zip_schema

    script:
	  """
	  #!/bin/bashlog
	  /app/etl-data create-asset \
	  	--asset-info=asset_info.json \
	  	--package-id=${params.packageId} \
	  	--organization-id=${params.organizationId}
    """
}

