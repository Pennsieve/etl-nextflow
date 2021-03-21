#!/usr/bin/env nextflow

// VERSION: 0.2.7

env = "${params.ENVIRONMENT}"

s3_keys = Channel.from(params.files)

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 2. Parse Tabular file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process parse_tabular {
    errorStrategy 'retry'
    maxRetries 3
    container = "${params.tabular_container}"

    input:
    file input_files from s3_keys.collect { file(it) }

    output:
    file 'schema.json'   into schema

    script:
    file_list = []
    input_files.each { file_list.push('--file="'+it.toString()+'"')}
    file_list = file_list.join(' ')
    package_id = '--package_id="' + params.packageNodeId.toString() + '"'
    cmd = "python /app/run.py ${file_list} ${package_id}"
    """
    #!/bin/bashlog
    ${cmd}
    """
}

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 3. Create table schema
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

process create_schema {
    errorStrategy 'retry'
    maxRetries 3
    container = "${params.cli_container}"

    input:
    file 'schema_info.json' from schema

    script:
	"""
	#!/bin/bashlog
	/app/etl-data create-tabular-schema \
		--schema-info=schema_info.json \
		--package-id=${params.packageId} \
		--organization-id=${params.organizationId}
	"""
}
