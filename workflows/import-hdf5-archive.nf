#!/usr/bin/env nextflow

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 1. Run parsing script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process extract_metadata_from_hdf5 {
    file_type = params.fileType.toLowerCase()
    container = params.import_processor_template.replace('<TYPE>',"hdf5")

    input:
    file input_file from s3_keys.map{ file(it) }

    output:
    file 'asset_info.json' into hdf5_schema

    script:
    cmd = "python /app/run.py --file=" + "${input_file}"
    """
    #!/bin/bashlog
    ${cmd}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Create hdf5 view asset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process create_view_asset {
    container = "${params.cli_container}"

    input:
    file 'asset_info.json' from hdf5_schema

    script:
	  """
	  #!/bin/bashlog
	  /app/etl-data create-asset \
	  	--asset-info=asset_info.json \
	  	--package-id=${params.packageId} \
	  	--organization-id=${params.organizationId}
    """
}

