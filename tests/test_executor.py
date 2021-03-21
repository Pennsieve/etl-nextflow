import os
import moto
import json
import boto3
import pytest

# inputs -----------------------------------------------

REGISTRY = {
    'workflow': {
        'test-format': 'workflow',
        'test-complex': 'workflow'
    },
    'append': {
        'test-format': 'simple'
    },
    'export': {
        'test-format': 'workflow',
        'test-complex': 'workflow',
        'HDF5': 'export-hdf5',
        'TimeSeries': 'export-timeseries'
    }
}

WORKFLOW_MANIFEST = {
    'type': 'workflow',
    'organizationId': 21,
    'content': {
        'userId': 101,
        'fileType': 'test-format',
        'storageDirectory': 'test-storage-directory/',
    }
}

APPEND_MANIFEST = {
    'type':  'append',
    'organizationId': 21,
    'content': {
        'fileType': 'test-format',
        'storageDirectory': 'test-storage-directory/',
    }
}

EXPORT_MANIFEST = {
    'type': 'export',
    'organizationId': 21,
    'content': {
        'packageId': 1,
        'datasetId': 1,
        'userId': 101,
        'fileType': 'NeuroDataWithoutBorders',
        'packageType': 'HDF5',
        'sourcePackageId': 2,
        'sourcePackageType': 'TimeSeries'
    }
}

FILE_OVERRIDE_MANIFEST = {
    'type': 'workflow',
    'organizationId': 21,
    'content': {
        'userId': 101,
        'fileType': 'test-format',
        'storageDirectory': 'test-storage-directory/',
    }
}

PACKAGE_OVERRIDE_MANIFEST = {
    'type': 'export',
    'organizationId': 21,
    'content': {
        'packageId': 1,
        'datasetId': 1,
        'userId': 101,
        'fileType': 'NeuroDataWithoutBorders',
        'packageType': 'HDF5',
        'sourcePackageId': 2,
        'sourcePackageType': 'test-format'
    }
}

MANIFESTS = [
    APPEND_MANIFEST,
    EXPORT_MANIFEST,
    WORKFLOW_MANIFEST
]

OVERRIDE_MANIFESTS = [
    FILE_OVERRIDE_MANIFEST,
    PACKAGE_OVERRIDE_MANIFEST
]


# helpers ---------------------------------------------


def setup_s3(s3_client, bucket, manifest):
    """
    Prepare S3
    """
    s3_client.create_bucket(Bucket=bucket)
    s3_client.put_object(Bucket=bucket,
                         Key='some/manifest.json', Body=json.dumps(manifest))
    s3_client.put_object(Bucket=bucket,
                         Key='test-format-workflow-workflow', Body=b'{}')
    s3_client.put_object(Bucket=bucket,
                         Key='test-format-append-workflow', Body=b'{}')
    s3_client.put_object(Bucket=bucket,
                         Key='test-format-export-workflow', Body=b'{}')


# tests -----------------------------------------------

@pytest.mark.parametrize("manifest", MANIFESTS)
@moto.mock_s3
def test_executor_nextflow(manifest):
    """
    Test: executor
    """
    os.environ.update({
        'ENVIRONMENT': 'test',
        'IMPORT_ID':   'test-import-id',
        'MANIFEST_KEY': 'some/manifest.json',
        'WORKING_DIR': 'some/scratch/dir'
    })

    import run_nextflow
    s3_client = boto3.client('s3')
    setup_s3(s3_client, run_nextflow.ETL_BUCKET, manifest)

    # run
    run_nextflow.run(command='nextflow run workflows/simple.nf',
                     registry=REGISTRY)


@pytest.mark.parametrize("manifest", MANIFESTS)
@moto.mock_s3
def test_executor(manifest):
    """
    Test: executor
    """
    os.environ.update({
        'ENVIRONMENT': 'test',
        'IMPORT_ID':   'test-import-id',
        'MANIFEST_KEY': 'some/manifest.json',
        'WORKING_DIR': 'some/scratch/dir'
    })

    import run_nextflow
    s3_client = boto3.client('s3')
    setup_s3(s3_client, run_nextflow.ETL_BUCKET, manifest)

    # run
    run_nextflow.run(command='echo test', registry=REGISTRY)


@pytest.mark.parametrize("manifest", MANIFESTS)
@moto.mock_s3
def test_failing_nextflow(manifest):
    """
    Test: failing executor
    """
    os.environ.update({
        'ENVIRONMENT': 'test',
        'IMPORT_ID':   'test-import-id',
        'MANIFEST_KEY': 'some/manifest.json',
        'WORKING_DIR': 'some/scratch/dir'
    })

    import run_nextflow
    s3_client = boto3.client('s3')
    setup_s3(s3_client, run_nextflow.ETL_BUCKET, manifest)

    with pytest.raises(SystemExit):
        run_nextflow.run(command='echo terrible things; alsdkfjads',
                         registry=REGISTRY)


@pytest.mark.parametrize("manifest", [EXPORT_MANIFEST])
@moto.mock_s3
def test_export_mapping(manifest):
    """
    Test: Make sure the export workflow source package type maps to the
    desired target package type:
    """
    os.environ.update({
        'ENVIRONMENT': 'test',
        'IMPORT_ID':   'test-import-id',
        'MANIFEST_KEY': 'some/manifest.json',
        'WORKING_DIR': 'some/scratch/dir'
    })

    import run_nextflow
    # Map the workflow 'test-format' -> 'test-complex'
    params = run_nextflow.NextflowParams.from_manifest(manifest,
                                                       registry=REGISTRY)

    assert params.job_type == 'export'
    assert params.workflow == 'export-timeseries'


@pytest.mark.parametrize("manifest", OVERRIDE_MANIFESTS)
@moto.mock_s3
def test_registry_overrides(manifest):
    """
    Test: Registry overrides work as expected for both
    fileType (import, append) and packageType (export) dispatch workflows.
    """
    os.environ.update({
        'ENVIRONMENT': 'test',
        'IMPORT_ID':   'test-import-id',
        'MANIFEST_KEY': 'some/manifest.json',
        'WORKING_DIR': 'some/scratch/dir'
    })

    import run_nextflow
    # Map the workflow 'test-format' -> 'test-complex'
    overrides = {'test-format': 'test-complex'}
    params = run_nextflow.NextflowParams.from_manifest(manifest,
                                                       registry=REGISTRY,
                                                       overrides=overrides)

    if params.is_export():
        # Preserve `fileType` for workflows dispatched by `packageType`:
        assert params.payload['fileType'] == 'NeuroDataWithoutBorders'
        assert params.payload['sourcePackageType'] == 'test-complex'
    else:
        assert params.payload['fileType'] == 'test-complex'
