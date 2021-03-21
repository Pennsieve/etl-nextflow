import os
import sys
import json
import time
import boto3
import logging
import logging.config
import requests
import subprocess
from botocore.client import Config
from registry import registry as official_registry
from registry import overrides

REQUIRED_ENV_VARS = ['ENVIRONMENT', 'MANIFEST_KEY', 'WORKING_DIR', 'IMPORT_ID']

# Only these types of jobs will be supported:
SUPPORTED_JOB_TYPES = ['append', 'export', 'workflow']

# Specific job type workflows are indexed by a specific key that occurs in a
# payload:
JOB_TYPE_KEY = {
    'append': 'fileType',
    'export': 'sourcePackageType',
    'workflow': 'fileType'
}

for v in REQUIRED_ENV_VARS:
    if v not in os.environ:
        raise Exception("Environment variable '{}' required, not found.".format(v))

# settings from env vars
ENV                            = os.environ.get('ENVIRONMENT')
IMPORT_ID                      = os.environ.get('IMPORT_ID')
MANIFEST_KEY                   = os.environ.get('MANIFEST_KEY')
WORKING_DIR                    = os.environ.get('WORKING_DIR')
NXF_OPTS                       = os.environ.get('NXF_OPTS', '-Xms256m -Xmx512m')
LOG_LEVEL                      = os.environ.get('LOG_LEVEL', 'INFO')
LOG_FORMAT                     = os.environ.get('LOG_FORMAT', 'json').lower()
NEXTFLOW_IAM_ACCESS_KEY_ID     = os.environ.get('NEXTFLOW_IAM_ACCESS_KEY_ID', 'test')
NEXTFLOW_IAM_ACCESS_KEY_SECRET = os.environ.get('NEXTFLOW_IAM_ACCESS_KEY_SECRET', 'test')

# other settings
ETL_BUCKET          = "pennsieve-{env}-etl-bucket-use1".format(env=ENV)
STORAGE_BUCKET      = "pennsieve-{env}-storage-use1".format(env=ENV)

# logging ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


class UTCFormatter(logging.Formatter):
    '''Convert logging timestamp to UTC'''
    converter = time.gmtime


def get_logger(job_type=None,
               user_id=None,
               organization_id=None,
               log_format=LOG_FORMAT):
    if log_format == 'json':
        log_msg_format = dict(
            date='%(asctime)s.%(msecs)03dZ',
            message='[%(levelname)s] [%(module)s] %(message)s',
            pennsieve=dict(
                import_id=IMPORT_ID,
                service_name="etl",
                environment_name=ENV,
                job_type=job_type,
                user_id=user_id,
                organization_id=organization_id
            )
        )
        log_msg_format = json.dumps(log_msg_format).replace('\n', '')

    elif log_format == 'prefix':
        log_msg_format = '[%(levelname)s] [%(module)s] [{}] - %(message)s'.format(IMPORT_ID)

    elif log_format == 'raw':
        log_msg_format = '%(message)s'
    else:
        raise Exception("Invalid log format: {}".format(log_format))

    LOGGING_CONFIG = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'utc': {
                '()': UTCFormatter,
                'format': log_msg_format,
                'datefmt': '%Y-%m-%dT%H:%M:%OS'
            }
        },
        'handlers': {
            'pennsieve': {
                'class': 'logging.StreamHandler',
                'formatter': 'utc',
            }
        },
        'root': {
            'handlers': ['pennsieve'],
            'level': LOG_LEVEL,
        }
    }

    logging.config.dictConfig(LOGGING_CONFIG)
    logger = logging.getLogger(__name__)

    def exception_handler(exc_type, exc_value, exc_traceback):
        logger.error("Exception: {0}".format(str(exc_value)),
            exc_info=(exc_type, exc_value, exc_traceback)
        )
    sys.excepthook = exception_handler
    return logger


class OuputLogger(object):
    def __init__(self, job_type, organization_id, user_id):
        self.logger = get_logger(
            job_type=job_type,
            organization_id=organization_id,
            user_id=user_id)
        self.raw_logger = get_logger(
            job_type=job_type,
            organization_id=organization_id,
            user_id=user_id,
            log_format='raw')

    def info(self, msg):
        self._log_msg(msg, 'info')

    def error(self, msg):
        self._log_msg(msg, 'error')

    def _log_msg(self, msg, level):
        logger = self.logger
        if LOG_FORMAT == 'json' and msg.startswith('{') and 'message' in msg:
            try:
                _ = json.loads(msg)
                logger = self.raw_logger
            except:
                pass
        log_func = getattr(logger, level)
        log_func(msg)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


class NextflowParams(object):
    @classmethod
    def from_manifest(cls, manifest, registry=official_registry, overrides=overrides):
        """
        Generates a model of `params.json` used by Nextflow from a manifest.
        """
        job_type = manifest['type']
        payload = manifest['content']
        organization_id = manifest['organizationId']
        payload['organizationId'] = organization_id
        user_id = payload.get('userId', '')

        if 'files' not in payload:
            keys = payload.get('storageFiles', [])
            payload['files'] = ["s3://{bucket}/{key}".format(bucket=STORAGE_BUCKET, key=key) for key in keys]

        if 'assetDirectory' not in payload:
            payload['assetDirectory'] = payload.get('storageDirectory', '')

        # Check the job type:
        if job_type not in SUPPORTED_JOB_TYPES:
            raise Exception("Job type '{}' not supported.".format(job_type))

        # Get the workflows associated with a job type:
        workflows = registry[job_type]

        # Specific job types are indexed by keys:
        job_type_key = JOB_TYPE_KEY[job_type]

        # Get workflow based on file/package type:
        format_type = payload[job_type_key]

        workflow = workflows.get(format_type, None)
        if workflow is None:
            raise Exception("Workflow of job type '{}' for {} '{}' not found."
                            .format(job_type, job_type_key, format_type))

        # if fileType and processor names are not equal:
        if overrides and format_type in overrides:
            payload[job_type_key] = overrides[format_type]

        return cls(job_type, workflow, organization_id, user_id, payload)

    def __init__(self, job_type, workflow, organization_id, user_id, payload):
        self.job_type = job_type
        self.workflow = workflow
        self.organization_id = organization_id
        self.user_id = user_id
        self.payload = payload

    def is_import(self):
        return self.job_type == 'workflow'

    def is_append(self):
        return self.job_type == 'append'

    def is_export(self):
        return self.job_type == 'export'

    @property
    def workflow_name(self):
        return '{}-{}'.format(ENV, os.path.basename(self.workflow)),

    def as_dict(self):
        return {
            'job_type': self.job_type,
            'workflow': self.workflow,
            'organization_id': self.organization_id,
            'user_id': self.user_id,
            'payload': self.payload
        }

    def write(self):
        """
        Write the manifest payload as json to use as Nextflow params.
        """
        json.dump(self.payload, open('params.json', 'w'))


def run(command=None, registry=None):
    """
    Main function
    """
    logger = get_logger()
    registry = official_registry if registry is None else registry

    logger.info('ENVIRONMENT    : {}'.format(ENV))
    logger.info('IMPORT_ID      : {}'.format(IMPORT_ID))
    logger.info('ETL_BUCKET     : {}'.format(ETL_BUCKET))
    logger.info('STORAGE_BUCKET : {}'.format(STORAGE_BUCKET))
    logger.info('MANIFEST_KEY   : {}'.format(MANIFEST_KEY))
    logger.info('WORKING_DIR    : {}'.format(WORKING_DIR))
    logger.info('NXF_OPTS       : {}'.format(NXF_OPTS))

    # download manifest
    s3 = boto3.client('s3')
    s3.download_file(ETL_BUCKET, MANIFEST_KEY,  'manifest.json')

    # get manifest
    manifest = json.load(open('manifest.json', 'r'))

    params = NextflowParams.from_manifest(manifest, registry=registry)

    output_logger = OuputLogger(job_type=params.job_type,
                                organization_id=params.organization_id,
                                user_id=params.user_id)

    # store manifest payload as json, to use as nextflow params
    params.write()

    # set process env vars (copy current)
    env_vars = os.environ
    env_vars.update({
        'NXF_OPTS':              NXF_OPTS,
        'ASSET_DIRECTORY':       params.payload['assetDirectory'],
        'USER_ID':               str(params.user_id),
        'ORGANIZATION_ID':       str(params.organization_id),
        'JOB_TYPE':              params.job_type,
        'AWS_ACCESS_KEY_ID':     NEXTFLOW_IAM_ACCESS_KEY_ID,
        'AWS_SECRET_ACCESS_KEY': NEXTFLOW_IAM_ACCESS_KEY_SECRET
    })

    # execute workflow
    if command is None:
        command = "nextflow run workflows/{workflow}.nf -name '{workflow_name}' -w {working_dir} -params-file params.json -profile {profile}".format(
            workflow=params.workflow,
            workflow_name=params.workflow_name,
            working_dir=WORKING_DIR,
            profile=ENV)

    output_logger.info('Executing: {}'.format(command))

    process = subprocess.Popen(command,
                               shell=True,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               env=env_vars)

    # stream command results/errors
    for line in iter(process.stdout.readline, ''):
        line = line.replace('\n', '').strip()
        output_logger.info(line)

    (_, stderr) = process.communicate()
    retcode = process.returncode
    logger.info("Return code: {}".format(retcode))

    report_filename = "report.html"
    report_key = "jobs/{import_id}/{report_filename}".format(
        import_id=IMPORT_ID,
        report_filename=report_filename)

    if os.path.isfile(report_filename):
        s3.upload_file(report_filename, ETL_BUCKET, report_key)

    # raise same return code as nextflow
    if retcode != 0:
        logger.error("Error running workflow")
        for line in stderr.splitlines():
            line = line.strip()
            output_logger.error(line)
        sys.exit(retcode)


if __name__ == '__main__':
    cmd = os.environ.get('COMMAND', None)
    run(cmd)
