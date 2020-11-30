# main.tf - GFS SUP Project 

data "aws_kms_key" "kms_key" {
    count = var.server_side_encryption_enabled ? 1 : 0
    key_id = var.kms_master_key_id
}

module "kinesis_data_stream" {

    source                          = "../../../../../../modules/analytics/kinesis/streams"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy
        
    # Kinesis Data Stream 
    stream_name                     = "${var.application_prefix}-kinesis-stream-${var.environment}"
    shard_count                     = var.shard_count
    stream_retention_period_in_hrs  = var.stream_retention_period_in_hrs
    stream_encryption_type          = var.stream_encryption_type
    stream_encryption_kms_key_id    = data.aws_kms_key.kms_key[0].id

# Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag
}

# Rest API & Components
# Refer to rest_api.tf


# Firehose
module "kinesis_firehose_stream" {

    source                          = "../../../../../../modules/analytics/kinesis/firehose"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy
    
    # Kinesis firehose
    kinesis_firehose_stream_name    = "${var.application_prefix}-kinesis-firehose-${var.environment}"
    stream_as_source_to_firehose    = var.stream_as_source_to_firehose
    kinesis_stream_arn              = module.kinesis_data_stream.kinesis_stream_arn
    server_side_encryption          = var.server_side_encryption
    s3_bucket_name                  = var.s3_bucket_name
    s3_bucket_prefix                = "${var.application_prefix}-kinesis-firehose-logs-${var.environment}"
    buffer_size_mb                  = var.buffer_size_mb
    buffer_interval                 = var.buffer_interval
    compression_format              = var.compression_format
    kms_key_arn                     = data.aws_kms_key.kms_key[0].arn
    error_output_prefix             = "${var.application_prefix}-kinesis-firehose-errors-${var.environment}"
    s3_backup_mode                  = var.s3_backup_mode
    s3_backup_prefix                = "${var.application_prefix}-kinesis-firehose-archive-${var.environment}"

    # Firehose CW Logs
    log_group_path                  = "/aws/kinesisfirehose"
    # Should be same as Firehose stream name
    log_group_name                  = "${var.application_prefix}-kinesis-firehose-s3-${var.environment}"
    log_stream_name                 = "S3Delivery"
    log_rentention_in_days          = var.log_rentention_in_days

    
    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			= var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}


module "lambda_function_stream" {

    source                          = "../../../../../../modules/compute/lambda"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy

    # Lambda Function for Kinesis Data Stream
    stream_as_source_to_lambda      = var.stream_as_source_to_lambda
    kinesis_stream_arn              = module.kinesis_data_stream.kinesis_stream_arn
    kinesis_stream_name             = module.kinesis_data_stream.kinesis_stream_name

    # Encryption for Stream  
    server_side_encryption_enabled  = var.server_side_encryption_enabled
    stream_kms_key_arn              = data.aws_kms_key.kms_key[0].arn


    lambda_s3_bucket_name           = var.lambda_s3_bucket_name
    lambda_s3_bucket_key            = var.lambda_s3_bucket_key
    lambda_function_file_name       = var.lambda_function_file_name
    lambda_function_handler_name    = var.lambda_function_handler_name
    lambda_function_source_name     = var.lambda_function_source_name
    lambda_function_name            = "${var.application_prefix}-${var.lambda_function_source_name}-processor-${var.environment}"
    lambda_function_description     = var.lambda_function_description

    # Secrets
    lambda_secrets_access           = "true"
    secret_arn                      = module.dynamodb_pii_data_secrets.secret_arn

    # Environment Variables for Lambda
    lambda_environment = {
        variables = merge(
                        {
                           
                           DDB_STREAM_TRANSACTION_TBL_NAME      = module.dynamodb_table_stream.dynamodb_table_name
                           DDB_BATCH_TRANSCATION_TBL_NAME       = module.dynamodb_table_batch.dynamodb_table_name
                           SECRET_MANAGER_SECRET_ID             = module.dynamodb_pii_data_secrets.secret_name
                           KINESIS_STREAM_NAME                  = module.kinesis_data_stream.kinesis_stream_name
                        },
                        var.lambda_env_variables
                    ) 
    }  
  
    # Dead Letter Config - SQS
    dlq_target_sqs                  = "true"
    target_sqs_arn                  = [module.lamdba_sqs_dl_queue.sqs_queue_arn] # For IAM Role
    
    
    # SNS integration
    dlq_target_sns                  = "true"
    target_sns_arn                  = [module.sns_topic.sns_topic_arn] # For IAM Role

    # Dynamo DB Integration
    ddb_as_destination              = "true"
    dynamo_db_arn                   =  [
                                        module.dynamodb_table_stream.dynamodb_table_arn ,
                                        module.dynamodb_table_batch.dynamodb_table_arn ,
                                        module.dynamodb_table_metadata.dynamodb_table_arn 
                                    ]
    
    # Runtime Configuration
    lambda_memory_size_mb           = var.lambda_memory_size_mb
    lambda_runtime_engine           = var.lambda_runtime_engine
    lambda_timeout_secs             = var.lambda_timeout_secs
    lambda_reserved_conc_execs      = var.lambda_reserved_conc_execs
    
    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			= var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}

module "lambda_function_sqs_processor" {

    source                          = "../../../../../../modules/compute/lambda"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy

    # Lambda Function for Kinesis Data Stream
    stream_as_source_to_lambda      = var.stream_as_source_to_lambda_sqs
    kinesis_stream_arn              = module.kinesis_data_stream.kinesis_stream_arn
    kinesis_stream_name             = module.kinesis_data_stream.kinesis_stream_name

    # Encryption for Stream  
    server_side_encryption_enabled  = var.server_side_encryption_enabled
    stream_kms_key_arn              = data.aws_kms_key.kms_key[0].arn


    lambda_s3_bucket_name           = var.lambda_s3_bucket_name_sqs
    lambda_s3_bucket_key            = var.lambda_s3_bucket_key_sqs
    lambda_function_file_name       = var.lambda_function_file_name_sqs
    lambda_function_handler_name    = var.lambda_function_handler_name_sqs
    lambda_function_source_name     = var.lambda_function_source_name_sqs
    lambda_function_name            = "${var.application_prefix}-${var.lambda_function_source_name_sqs}-processor-${var.environment}"
    lambda_function_description     = var.lambda_function_description_sqs

    # Secrets
    lambda_secrets_access           = "true"
    secret_arn                      = module.dynamodb_pii_data_secrets.secret_arn

    # Environment Variables for Lambda
    lambda_environment = {
        variables = merge(
                        {
                           
                           DDB_STREAM_TRANSACTION_TBL_NAME      = module.dynamodb_table_stream.dynamodb_table_name
                           DDB_BATCH_TRANSCATION_TBL_NAME       = module.dynamodb_table_batch.dynamodb_table_name
                           SECRET_MANAGER_SECRET_ID             = module.dynamodb_pii_data_secrets.secret_name
                           KINESIS_STREAM_NAME                  = module.kinesis_data_stream.kinesis_stream_name
                        },
                        var.lambda_env_variables_sqs
                    ) 
    }  
  
    # Dead Letter Config - SQS
    dlq_target_sqs                  = "true"
    target_sqs_arn                  = [module.lamdba_sqs_dl_queue.sqs_queue_arn] # For IAM Role
    

    # # DO NOT need another DLQ as this Lambda is processing Kinesis Lambda DLQ
    # dl_target                       = {
    #     target_arn                  = module.lamdba_sqs_dl_queue.sqs_queue_arn
    # }

    # SNS integration
    dlq_target_sns                  = "true"
    target_sns_arn                  = [module.sns_topic.sns_topic_arn] # For IAM Role

    # Dynamo DB Integration
    ddb_as_destination              = "true"
    dynamo_db_arn                   =  [
                                        module.dynamodb_table_stream.dynamodb_table_arn ,
                                        module.dynamodb_table_batch.dynamodb_table_arn ,
                                        module.dynamodb_table_metadata.dynamodb_table_arn 
                                    ]
    
    # Runtime Configuration
    lambda_memory_size_mb           = var.lambda_memory_size_mb_sqs
    lambda_runtime_engine           = var.lambda_runtime_engine_sqs
    lambda_timeout_secs             = var.lambda_timeout_secs_sqs
    lambda_reserved_conc_execs      = var.lambda_reserved_conc_execs_sqs
    
    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			= var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}


module "dynamodb_table_stream" {

    source                      = "../../../../../../modules/database/dynamoDB"
    
    application_prefix          = var.application_prefix
    environment                 = var.environment
    iam_boundary_policy         = var.iam_boundary_policy
    
    # Dynamo DB Table
    dynamo_db_table_map         = var.dynamo_db_table_stream
    dynamo_table_name           = "${var.application_prefix}-${lookup(var.dynamo_db_table_stream, "dynamo_table_name", null)}-${var.environment}"
    hash_key                    = lookup(var.dynamo_db_table_stream, "hash_key", null)
    range_key                   = lookup(var.dynamo_db_table_stream, "range_key", null)
    stream_enabled              = lookup(var.dynamo_db_table_stream, "stream_enabled", false)
    stream_view_type            = lookup(var.dynamo_db_table_stream, "stream_view_type", null)
    attributes                  = lookup(var.dynamo_db_table_stream, "attributes", null)
    billing_mode                = var.billing_mode

    # Capacity
    write_capacity              = lookup(var.dynamo_db_table_stream, "write_capacity", null)
    read_capacity               = lookup(var.dynamo_db_table_stream, "read_capacity", null)
    point_in_time_recovery_enabled  =  lookup(var.dynamo_db_table_stream, "point_in_time_recovery_enabled", null)

    # Global Secondary Indexes
    global_secondary_indexes    = lookup(var.dynamo_db_table_stream, "global_secondary_indexes", null) 
    
    # Auto Scaling
    autoscaling_read            = lookup(var.dynamo_db_table_stream, "autoscaling_read", null)
    autoscaling_write           = lookup(var.dynamo_db_table_stream, "autoscaling_write", null)
    autoscaling_indexes         = lookup(var.dynamo_db_table_stream, "autoscaling_indexes", null)
    
    # Server Side Encryption
    server_side_encryption_enabled      = lookup(var.dynamo_db_table_stream, "server_side_encryption_enabled", null)
    server_side_encryption_kms_key_arn  = "${var.server_side_encryption_enabled ? data.aws_kms_key.kms_key[0].arn : ""}"

    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}

module "dynamodb_table_batch" {

    source                          = "../../../../../../modules/database/dynamoDB"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy

    # Dynamo DB Table
    dynamo_db_table_map         = var.dynamo_db_table_batch
    dynamo_table_name           = "${var.application_prefix}-${lookup(var.dynamo_db_table_batch, "dynamo_table_name", null)}-${var.environment}"
    hash_key                    = lookup(var.dynamo_db_table_batch, "hash_key", null)
    range_key                   = lookup(var.dynamo_db_table_batch, "range_key", null)
    stream_enabled              = lookup(var.dynamo_db_table_batch, "stream_enabled", false)
    stream_view_type            = lookup(var.dynamo_db_table_batch, "stream_view_type", null)
    attributes                  = lookup(var.dynamo_db_table_batch, "attributes", null)
    billing_mode                = var.billing_mode

    # Capacity
    write_capacity              = lookup(var.dynamo_db_table_batch, "write_capacity", null)
    read_capacity               = lookup(var.dynamo_db_table_batch, "read_capacity", null)
    point_in_time_recovery_enabled  =  lookup(var.dynamo_db_table_batch, "point_in_time_recovery_enabled", null)

    # Global Secondary Indexes
    global_secondary_indexes    = lookup(var.dynamo_db_table_batch, "global_secondary_indexes", null) 

    # Auto Scaling
    autoscaling_read            = lookup(var.dynamo_db_table_batch, "autoscaling_read", null)
    autoscaling_write           = lookup(var.dynamo_db_table_batch, "autoscaling_write", null)
    autoscaling_indexes         = lookup(var.dynamo_db_table_batch, "autoscaling_indexes", null)
    
    # Server Side Encryption
    server_side_encryption_enabled      = lookup(var.dynamo_db_table_batch, "server_side_encryption_enabled", null)
    server_side_encryption_kms_key_arn  = "${var.server_side_encryption_enabled ? data.aws_kms_key.kms_key[0].arn : ""}"

    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}

module "dynamodb_table_metadata" {

    source                          = "../../../../../../modules/database/dynamoDB"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy

    # Dynamo DB Table
    dynamo_db_table_map         = var.dynamo_db_table_meta
    dynamo_table_name           = "${var.application_prefix}-${lookup(var.dynamo_db_table_meta, "dynamo_table_name", null)}-${var.environment}"
    hash_key                    = lookup(var.dynamo_db_table_meta, "hash_key", null)
    range_key                   = lookup(var.dynamo_db_table_meta, "range_key", null)
    stream_enabled              = lookup(var.dynamo_db_table_meta, "stream_enabled", false)
    stream_view_type            = lookup(var.dynamo_db_table_meta, "stream_view_type", null)
    attributes                  = lookup(var.dynamo_db_table_meta, "attributes", null)
    billing_mode                = var.billing_mode


    # Capacity
    write_capacity              = lookup(var.dynamo_db_table_meta, "write_capacity", null)
    read_capacity               = lookup(var.dynamo_db_table_meta, "read_capacity", null)
    point_in_time_recovery_enabled  =  lookup(var.dynamo_db_table_meta, "point_in_time_recovery_enabled", null)

    # Global Secondary Indexes - Not given in the requirements for this table
    # Autoscaling - Not given in the requirements for this table
    
    # Server Side Encryption
    server_side_encryption_enabled      = lookup(var.dynamo_db_table_meta, "server_side_encryption_enabled", null)
    server_side_encryption_kms_key_arn  = "${var.server_side_encryption_enabled ? data.aws_kms_key.kms_key[0].arn : ""}"


    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag

}

# SQS Queue
module "lamdba_sqs_dl_queue" {
    source = "../../../../../../modules/app_integration/sqs"

    
    enable_queue                = var.enable_queue
    enable_dlq                  = var.enable_dlq
    

    queue_name                  = "${var.application_prefix}-${var.queue_name}-${var.environment}${var.fifo_queue ? ".fifo" : ""}"
    dl_queue_name               = "${var.application_prefix}-${var.queue_name}-dlq-${var.environment}${var.fifo_queue ? ".fifo" : ""}"

    visibility_timeout_seconds  = var.visibility_timeout_seconds
    message_retention_seconds   = var.message_retention_seconds
    max_message_size            = var.max_message_size
    delay_seconds               = var.delay_seconds
    receive_wait_time_seconds   = var.receive_wait_time_seconds
    policy                      = var.policy
    max_receive_count           = var.max_receive_count 
    fifo_queue                  = var.fifo_queue
    content_based_deduplication = var.content_based_deduplication

    kms_master_key_id                 = var.kms_master_key_id
    kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag
}

# SNS topic
module "sns_topic" {
    source = "../../../../../../modules/app_integration/sns"
    
        create_sns_topic                        = var.create_sns_topic
        sns_topic_name                          = var.sns_topic_name
        display_name                            = var.sns_topic_display_name
        policy                                  = var.policy1
        delivery_policy                         = var.delivery_policy
        #application_success_feedback_role_arn   = var.application_success_feedback_role_arn
        #application_success_feedback_sample_rate= var.application_success_feedback_sample_rate
        #application_failure_feedback_role_arn   = var.application_failure_feedback_role_arn
        #http_success_feedback_role_arn          = var.http_success_feedback_role_arn
        #http_success_feedback_sample_rate       = var.http_success_feedback_sample_rate
        #http_failure_feedback_role_arn          = var.http_failure_feedback_role_arn
        #lambda_success_feedback_role_arn        = var.lambda_success_feedback_role_arn
        #lambda_success_feedback_sample_rate     = var.lambda_success_feedback_sample_rate
        #lambda_failure_feedback_role_arn        = var.lambda_failure_feedback_role_arn
        #sqs_success_feedback_role_arn           = var.sqs_success_feedback_role_arn
        #sqs_success_feedback_sample_rate        = var.sqs_success_feedback_sample_rate
        #sqs_failure_feedback_role_arn           = var.sqs_failure_feedback_role_arn
        kms_master_key_id                       = var.kms_master_key_id

   

    # Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag
}

module "glue_crawler" {

    source                          = "../../../../../../modules/analytics/glue/glue_crawler"
    
    application_prefix              = var.application_prefix
    environment                     = var.environment
    iam_boundary_policy             = var.iam_boundary_policy
        
    # Glue Crawler 
   
    glue_crawler_name                   = var.glue_crawler_name 
    glue_crawler_database_name           = var.glue_crawler_database_name
    glue_crawler_role                    = var.glue_crawler_role

    glue_crawler_description             = var.glue_crawler_description
    #glue_crawler_classifiersclassifiers  = var.glue_crawler_classifiers
    glue_crawler_configuration           = var.glue_crawler_configuration
    glue_crawler_schedule                = var.glue_crawler_schedule
    #glue_crawler_security_configuration  = var.glue_crawler_security_configuration 
    glue_crawler_table_prefix            = var.glue_crawler_table_prefix





 dynamic "catalog_target" {
        iterator = catalog_target
        for_each = length(var.glue_crawler_catalog_target) >0 ? [var.glue_crawler_catalog_target] : []
        content {
            database_name = lookup(catalog_target.value, "database_name", element(concat(aws_glue_catalog_database.glue_catalog_database.*.id, [""]), 0))
            tables        = lookup(catalog_target.value, "tables", element(concat(aws_glue_catalog_table.glue_catalog_table.*.id, [""]), 0))
        }
    }

    dynamic "schema_change_policy" {
        iterator = schema_change_policy
        for_each = var.glue_crawler_schema_change_policy
        content {
            delete_behavior = lookup(schema_change_policy.value, "delete_behavior", "DEPRECATE_IN_DATABASE")
            update_behavior = lookup(schema_change_policy.value, "update_behavior", "UPDATE_IN_DATABASE")
        }
    }

# Tags (ALL Lowercase!)
        # Specific to EC2 Resource
        name_tag                = var.name_tag
        costcenter_tag          = var.costcenter_tag
        projectname_tag         = var.projectname_tag
        application_group_tag   = var.application_group_tag
        application_tag         = var.application_tag
        component_type_tag      = var.component_type_tag
	    iac_tag			        = var.iac_tag
        tier_tag                = var.tier_tag
        environment_tag         = var.environment_tag
        sdlc_env_tag            = var.sdlc_env_tag
}

# Secrets for DynamoDB PII data encryption/decryption
module "dynamodb_pii_data_secrets" {

    source                          = "../../../../../../modules/iam/secrets"
    
    # application_prefix              = var.application_prefix
    # environment                     = var.environment
    # sdlc_env_tag                    = var.sdlc_env_tag

    # Secret 
    secret_name                     = "${var.application_prefix}/microservice/${var.sdlc_env_tag}/${var.environment}/dynamodb"
    secret_description              = "Secrets for GFS SUP Project - Microservice - ${var.sdlc_env_tag} Environment - ${var.environment}"
    secret_kms_key_arn              = data.aws_kms_key.kms_key[0].arn

    # Secrets Values - Will be passed via TF_VAR_key1_secret_value and TF_VAR_key2_secret_value
    secret_value = {
        ddb2Metadata        = var.key1_secret_value
        ddb2EncodedKey      = var.key2_secret_value
}

    # Tags (ALL Lowercase!)
    # Specific to EC2 Resource
    name_tag                = "${var.application_prefix}/microservice/${var.sdlc_env_tag}/${var.environment}/dynamodb"
    costcenter_tag          = var.costcenter_tag
    projectname_tag         = var.projectname_tag
    application_group_tag   = var.application_group_tag
    application_tag         = var.application_tag
    component_type_tag      = var.component_type_tag
    iac_tag			        = var.iac_tag
    tier_tag                = var.tier_tag
    environment_tag         = var.environment_tag
    sdlc_env_tag            = var.sdlc_env_tag
}